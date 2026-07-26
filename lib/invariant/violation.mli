(** Invariant violation reported during a run. *)

type t =
  { name : string
  ; message : string
  }
[@@deriving sexp, compare, equal]

val to_string : t -> string
