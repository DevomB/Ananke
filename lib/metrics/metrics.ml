open Base

type t =
  { commands_processed : int
  ; events_recorded : int
  ; invariant_checks : int
  ; snapshots_taken : int
  ; wall_time_ns : int64
  }
[@@deriving sexp, compare, equal]

let empty =
  { commands_processed = 0
  ; events_recorded = 0
  ; invariant_checks = 0
  ; snapshots_taken = 0
  ; wall_time_ns = 0L
  }
;;

let record_command t = { t with commands_processed = t.commands_processed + 1 }
let record_event t = { t with events_recorded = t.events_recorded + 1 }
let record_invariant_check t = { t with invariant_checks = t.invariant_checks + 1 }
let record_snapshot t = { t with snapshots_taken = t.snapshots_taken + 1 }
let set_wall_time_ns ns t = { t with wall_time_ns = ns }

let summary t =
  Printf.sprintf
    "commands=%d events=%d invariants=%d snapshots=%d wall_ns=%Ld"
    t.commands_processed
    t.events_recorded
    t.invariant_checks
    t.snapshots_taken
    t.wall_time_ns
;;
