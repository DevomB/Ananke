(** Runtime counters and timing samples. *)

type t =
  { commands_processed : int
  ; events_recorded : int
  ; invariant_checks : int
  ; snapshots_taken : int
  ; wall_time_ns : int64
  }
[@@deriving sexp, compare, equal]

val empty : t
val record_command : t -> t
val record_event : t -> t
val record_invariant_check : t -> t
val record_snapshot : t -> t
val set_wall_time_ns : int64 -> t -> t
val summary : t -> string
