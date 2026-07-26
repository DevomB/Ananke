(** A single structural change between two sexp values. *)

type t =
  | Added of Field_path.t * Sexp.t
  | Removed of Field_path.t * Sexp.t
  | Changed of Field_path.t * Sexp.t * Sexp.t
[@@deriving sexp, compare, equal]

val describe : t -> string
