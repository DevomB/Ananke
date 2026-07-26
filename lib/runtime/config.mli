(** Runtime configuration. *)

type invariant_mode =
  | Stop
  | Record
  | Warn
[@@deriving sexp, compare, equal]

type t =
  { rng_seed : int
  ; invariant_mode : invariant_mode
  ; trace_enabled : bool
  ; snapshot_each_command : bool
  }
[@@deriving sexp, compare, equal]

val default : t
