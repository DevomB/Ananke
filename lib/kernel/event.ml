open Base

type system =
  | Invariant_checked
  | Snapshot_taken
  | Clock_advanced
[@@deriving compare, equal, sexp]

type t =
  | Command of Command.t
  | Emitted of Sexp.t
  | System of system
[@@deriving compare, equal, sexp]

let command_payload = function
  | Command cmd -> Some cmd.payload
  | Emitted _ | System _ -> None
;;

let is_system = function
  | System _ -> true
  | Command _ | Emitted _ -> false
;;
