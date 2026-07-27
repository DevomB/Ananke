open Base

(** Simple limit order book domain (finance example). *)

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

include Ananke_runtime.Domain.S
  with type state := state
   and type command := command
   and type event := event

val command_of_sexp : Sexp.t -> command
