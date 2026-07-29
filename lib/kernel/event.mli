open Base

(** Events recorded in the ananke trace. *)

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

val command_payload : t -> Sexp.t option
val is_system : t -> bool

(** Flatten all invariant outcomes recorded in an event list. *)
val invariant_outcomes : t list -> invariant_outcome list

(** Violations embedded in an event list (inspectable without re-running). *)
val invariant_violations : t list -> invariant_outcome list
