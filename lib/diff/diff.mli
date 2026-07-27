open Base

(** Structural diff over sexp values. *)

type t = Change.t list [@@deriving sexp, compare, equal]

val diff : Sexp.t -> Sexp.t -> t
val is_empty : t -> bool
val to_string : t -> string
