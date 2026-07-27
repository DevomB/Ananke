open Base

(** Events recorded in the ananke trace. *)

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

val command_payload : t -> Sexp.t option
val is_system : t -> bool
