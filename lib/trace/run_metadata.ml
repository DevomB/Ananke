open Base

type t =
  { domain : string
  ; domain_version : int
  ; rng_seed : int
  ; started_at : Logical_time.t
  ; command_count : int
  ; event_count : int
  }
[@@deriving sexp, compare, equal]

let create ~domain ~domain_version ~rng_seed ~started_at ~command_count ~event_count =
  { domain; domain_version; rng_seed; started_at; command_count; event_count }
;;
