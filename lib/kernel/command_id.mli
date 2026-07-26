(** Stable identifier for a submitted command. *)

type t [@@deriving compare, equal, sexp]

val of_string : string -> t
val to_string : t -> string
val fresh : int -> t
