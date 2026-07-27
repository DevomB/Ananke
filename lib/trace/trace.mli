open Base

(** A complete recorded run. *)

type t =
  { metadata : Run_metadata.t
  ; events : Event.t list
  ; final_state : Sexp.t option
  ; snapshots : Snapshot.t list
  }
[@@deriving sexp, compare, equal]

val empty : Run_metadata.t -> t
val add_event : Event.t -> t -> t
val add_snapshot : Snapshot.t -> t -> t
val set_final_state : Sexp.t -> t -> t
val timeline : t -> Timeline.t
val event_count : t -> int
