open Base

type invariant_outcome =
  | Passed of { name : string }
  | Violated of
      { name : string
      ; message : string
      }
[@@deriving compare, equal, sexp]

type system =
  | Invariant_checked of invariant_outcome list
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

let invariant_outcomes events =
  List.concat_map events ~f:(function
    | System (Invariant_checked outcomes) -> outcomes
    | Command _ | Emitted _ | System _ -> [])
;;

let invariant_violations events =
  List.filter (invariant_outcomes events) ~f:(function
    | Violated _ -> true
    | Passed _ -> false)
;;
