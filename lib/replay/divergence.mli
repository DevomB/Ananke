(** Where replay diverged from the original trace. *)

type t =
  { index : Event_index.t
  ; expected : Event.t
  ; actual : Event.t
  ; message : string
  }
[@@deriving sexp, compare, equal]

val to_string : t -> string
