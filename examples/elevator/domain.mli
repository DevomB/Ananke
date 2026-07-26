(** Elevator finite-state machine domain. *)

type direction =
  | Up
  | Down
  | Idle
[@@deriving sexp, compare]

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

include Domain.S
  with type state := state
   and type command := command
   and type event := event

val min_floor : int
val max_floor : int
val command_of_sexp : Sexp.t -> command
