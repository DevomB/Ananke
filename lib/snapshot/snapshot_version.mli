(** Version tag for snapshot schema evolution. *)

type t = int [@@deriving compare, equal, sexp]

val current : t
