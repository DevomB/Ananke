(** Path to a field inside a sexp value. *)

type t = string list [@@deriving sexp, compare, equal]

val to_string : t -> string
val root : t
