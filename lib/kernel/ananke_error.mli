(** Errors surfaced by the runtime and tooling. *)

type t =
  | Invalid_command of string
  | Invariant_violation of string
  | Replay_divergence of string
  | Io_error of string
  | Parse_error of string
  | Domain_error of string
  | Incompatible_version of string
[@@deriving sexp, compare, equal]

val to_string : t -> string
