(** Where replay diverged from the original trace. *)

open Base

type t =
  { index : Event_index.t
  ; expected : Event.t
  ; actual : Event.t
  ; message : string
  ; event_diff : Diff.t
  ; state_diff : Diff.t option
  }
[@@deriving sexp, compare, equal]

(** Build a divergence, computing the structural event diff and optional state diff. *)
val create
  :  index:Event_index.t
  -> expected:Event.t
  -> actual:Event.t
  -> message:string
  -> ?expected_state:Sexp.t
  -> ?actual_state:Sexp.t
  -> unit
  -> t

val to_string : t -> string
