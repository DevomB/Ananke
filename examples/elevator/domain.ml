open Base

type direction =
  | Up
  | Down
  | Idle
[@@deriving sexp, compare, equal]

type state =
  { floor : int
  ; direction : direction
  ; requests : int list
  }
[@@deriving sexp, compare]

type command =
  | Request_floor of int
  | Step
[@@deriving sexp]

type event =
  | Floor_requested of int
  | Arrived_at of int
  | Direction_changed of direction
[@@deriving sexp]

let min_floor = 0
let max_floor = 10
let name = "elevator"
let version = 1
let initial_state = { floor = 0; direction = Idle; requests = [] }

let floor_in_range floor =
  if floor < min_floor || floor > max_floor
  then
    Error
      (Ananke_error.Invalid_command
         (Printf.sprintf "floor %d out of range [%d,%d]" floor min_floor max_floor))
  else Ok ()
;;

let add_request requests floor =
  if List.mem requests floor ~equal:Int.equal then requests else requests @ [ floor ]
;;

let choose_direction floor requests =
  let above = List.exists requests ~f:(fun f -> f > floor) in
  let below = List.exists requests ~f:(fun f -> f < floor) in
  match above, below with
  | true, false -> Up
  | false, true -> Down
  | true, true ->
    let nearest =
      List.min_elt requests ~compare:Int.compare |> Option.value ~default:floor
    in
    if nearest >= floor then Up else Down
  | false, false -> Idle
;;

let transition state rng = function
  | Request_floor floor ->
    (match floor_in_range floor with
     | Error _ as err -> err
     | Ok () ->
       let requests = add_request state.requests floor in
       let direction =
         match state.direction with
         | Idle -> choose_direction state.floor requests
         | d -> d
       in
       let events =
         [ Floor_requested floor ]
         @
         if not (equal_direction direction state.direction)
         then [ Direction_changed direction ]
         else []
       in
       Ok ({ state with requests; direction }, events, rng))
  | Step ->
    (match state.direction with
     | Idle -> Ok (state, [], rng)
     | Up ->
       let floor = min (state.floor + 1) max_floor in
       let requests = List.filter state.requests ~f:(fun f -> f <> floor) in
       let direction =
         if List.exists requests ~f:(fun f -> f > floor) then Up else Idle
       in
       let events =
         [ Arrived_at floor ]
         @
         if not (equal_direction direction state.direction)
         then [ Direction_changed direction ]
         else []
       in
       Ok ({ floor; direction; requests }, events, rng)
     | Down ->
       let floor = max (state.floor - 1) min_floor in
       let requests = List.filter state.requests ~f:(fun f -> f <> floor) in
       let direction =
         if List.exists requests ~f:(fun f -> f < floor) then Down else Idle
       in
       let events =
         [ Arrived_at floor ]
         @
         if not (equal_direction direction state.direction)
         then [ Direction_changed direction ]
         else []
       in
       Ok ({ floor; direction; requests }, events, rng))
;;

let no_empty_travel state =
  match state.direction with
  | Idle -> Ok ()
  | Up ->
    if List.exists state.requests ~f:(fun f -> f > state.floor)
    then Ok ()
    else
      Error
        { Violation.name = "no_empty_travel"
        ; message = "moving up with no requests above current floor"
        }
  | Down ->
    if List.exists state.requests ~f:(fun f -> f < state.floor)
    then Ok ()
    else
      Error
        { Violation.name = "no_empty_travel"
        ; message = "moving down with no requests below current floor"
        }
;;

let floor_valid state =
  if state.floor >= min_floor && state.floor <= max_floor
  then Ok ()
  else
    Error
      { Violation.name = "floor_valid"
      ; message =
          Printf.sprintf "floor %d outside [%d,%d]" state.floor min_floor max_floor
      }
;;

let invariants = [ "no_empty_travel", no_empty_travel; "floor_valid", floor_valid ]
let command_of_sexp = command_of_sexp
let state_of_sexp = state_of_sexp
