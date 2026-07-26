(** Monotonic logical clock for deterministic ordering. *)

type t [@@deriving compare, equal, sexp]

val zero : t
val of_int64 : int64 -> t
val to_int64 : t -> int64
val succ : t -> t
val add : t -> int64 -> t
