(** Metadata describing a recorded run. *)

type t =
  { domain : string
  ; domain_version : int
  ; rng_seed : int
  ; started_at : Logical_time.t
  ; command_count : int
  ; event_count : int
  }
[@@deriving sexp, compare, equal]

val create
  :  domain:string
  -> domain_version:int
  -> rng_seed:int
  -> started_at:Logical_time.t
  -> command_count:int
  -> event_count:int
  -> t
