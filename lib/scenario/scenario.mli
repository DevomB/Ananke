open Base

(** Scenario loaded from a sexp file. *)

type t =
  { name : string
  ; domain : string
  ; rng_seed : int
  ; commands : Sexp.t list
  }
[@@deriving sexp, compare, equal]

val load : Sexp.t -> (t, Ananke_error.t) Result.t
val load_file : string -> (t, Ananke_error.t) Result.t
val command_sexps : t -> Sexp.t list
