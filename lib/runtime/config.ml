open Base

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

let default =
  { rng_seed = 0
  ; invariant_mode = Stop
  ; trace_enabled = true
  ; snapshot_each_command = false
  }
