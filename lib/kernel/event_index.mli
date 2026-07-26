(** Zero-based index into a recorded event stream. *)

type t [@@deriving compare, equal, sexp]

val zero : t
val of_int : int -> t
val to_int : t -> int
val succ : t -> t
