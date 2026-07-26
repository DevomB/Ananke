open Base

type side =
  | Bid
  | Ask
[@@deriving sexp, compare, equal]

type order =
  { side : side
  ; price : int
  ; qty : int
  }
[@@deriving sexp, compare]

type state =
  { orders : (int, order) Map.t
  ; next_order_id : int
  }
[@@deriving sexp, compare]

type command =
  | Place_order of side * int * int
  | Cancel_order of int
  | Match
[@@deriving sexp]

type event =
  | Order_placed of int * side * int * int
  | Order_matched of int * int
  | Order_cancelled of int
[@@deriving sexp]

let name = "matching_engine"
let version = 1
let initial_state = { orders = Map.empty (module Int); next_order_id = 1 }

let find_best_order orders side =
  let better_price price best =
    match side with
    | Bid -> price > best
    | Ask -> price < best
  in
  Map.fold orders ~init:None ~f:(fun ~key:id ~data:order acc ->
      if not (equal_side order.side side) then acc
      else
        match acc with
        | None -> Some (id, order)
        | Some (best_id, best_order) ->
            if better_price order.price best_order.price then Some (id, order)
            else if order.price = best_order.price && id < best_id then Some (id, order)
            else acc)
;;

let reduce_order orders id qty =
  match Map.find orders id with
  | None -> orders
  | Some order ->
      let remaining = order.qty - qty in
      if remaining <= 0 then Map.remove orders id
      else Map.set orders id { order with qty = remaining }
;;

let rec match_loop orders events =
  match find_best_order orders Bid, find_best_order orders Ask with
  | Some (bid_id, bid), Some (ask_id, ask) when bid.price >= ask.price ->
      let qty = min bid.qty ask.qty in
      let price = ask.price in
      let orders =
        orders |> reduce_order bid_id qty |> fun o -> reduce_order o ask_id qty
      in
      match_loop orders (Order_matched (price, qty) :: events)
  | _ -> orders, List.rev events
;;

let validate_positive_qty qty =
  if qty <= 0 then
    Error (Chronicle_error.Invalid_command "quantity must be positive")
  else Ok ()
;;

let validate_positive_price price =
  if price <= 0 then
    Error (Chronicle_error.Invalid_command "price must be positive")
  else Ok ()
;;

let transition state = function
  | Place_order (side, price, qty) -> (
      match validate_positive_price price with
      | Error _ as err -> err
      | Ok () -> (
          match validate_positive_qty qty with
          | Error _ as err -> err
          | Ok () ->
              let id = state.next_order_id in
              let order = { side; price; qty } in
              let orders = Map.set state.orders id order in
              let orders, match_events = match_loop orders [] in
              let events = Order_placed (id, side, price, qty) :: match_events in
              Ok ({ orders; next_order_id = id + 1 }, events)))
  | Cancel_order order_id -> (
      match Map.find state.orders order_id with
      | None ->
          Error (Chronicle_error.Invalid_command (sprintf "unknown order_id %d" order_id))
      | Some _ ->
          let orders = Map.remove state.orders order_id in
          Ok ({ state with orders }, [ Order_cancelled order_id ]))
  | Match ->
      let orders, events = match_loop state.orders [] in
      Ok ({ state with orders }, events)
;;

let no_negative_quantities state =
  Map.fold state.orders ~init:(Ok ()) ~f:(fun ~key:id ~data:order acc ->
      match acc with
      | Error _ -> acc
      | Ok () ->
          if order.qty <= 0 then
            Error
              { Violation.name = "no_negative_quantities"
              ; message = sprintf "order %d has non-positive qty %d" id order.qty
              }
          else if order.price <= 0 then
            Error
              { Violation.name = "no_negative_quantities"
              ; message = sprintf "order %d has non-positive price %d" id order.price
              }
          else Ok ())
;;

let no_crossed_book state =
  match find_best_order state.orders Bid, find_best_order state.orders Ask with
  | Some (_, bid), Some (_, ask) when bid.price >= ask.price ->
      Error
        { Violation.name = "no_crossed_book"
        ; message =
            sprintf "best bid %d >= best ask %d" bid.price ask.price
        }
  | _ -> Ok ()
;;

let order_id_unique state =
  let max_id =
    Map.fold state.orders ~init:0 ~f:(fun ~key:id ~data:_ acc -> max acc id)
  in
  if state.next_order_id > max_id then Ok ()
  else
    Error
      { Violation.name = "order_id_unique"
      ; message =
          sprintf "next_order_id %d must exceed max existing id %d"
            state.next_order_id max_id
      }
;;

let invariants = [ no_negative_quantities; no_crossed_book; order_id_unique ]
let command_of_sexp = command_of_sexp
