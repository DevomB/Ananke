open Base

type t =
  | Invalid_command of string
  | Invariant_violation of string
  | Replay_divergence of string
  | Io_error of string
  | Parse_error of string
  | Domain_error of string
  | Incompatible_version of string
[@@deriving sexp, compare, equal]

let to_string = function
  | Invalid_command msg -> "Invalid_command: " ^ msg
  | Invariant_violation msg -> "Invariant_violation: " ^ msg
  | Replay_divergence msg -> "Replay_divergence: " ^ msg
  | Io_error msg -> "Io_error: " ^ msg
  | Parse_error msg -> "Parse_error: " ^ msg
  | Domain_error msg -> "Domain_error: " ^ msg
  | Incompatible_version msg -> "Incompatible_version: " ^ msg
;;
