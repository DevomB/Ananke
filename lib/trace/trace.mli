open Base

(** A complete recorded run. *)

type t =
  { metadata : Run_metadata.t
  ; events : Event.t list
  ; final_state : Sexp.t option
  ; snapshots : Snapshot.t list
  ; sealed : bool [@compare.ignore] [@equal.ignore]
  }
[@@deriving sexp, compare, equal]

val empty : Run_metadata.t -> t
val add_event : Event.t -> t -> t
val add_snapshot : Snapshot.t -> t -> t
val set_final_state : Sexp.t -> t -> t
val seal : t -> t
val timeline : t -> Timeline.t
val event_count : t -> int

(** All invariant pass/fail outcomes recorded in this trace. *)
val invariant_outcomes : t -> Event.invariant_outcome list

(** Violation outcomes only — inspectable without re-running the domain. *)
val invariant_violations : t -> Event.invariant_outcome list
