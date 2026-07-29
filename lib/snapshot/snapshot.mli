open Base

(** Point-in-time capture of domain state and RNG. *)

type t =
  { version : Snapshot_version.t
  ; at : Logical_time.t
  ; at_index : Event_index.t
  ; state : Sexp.t
  ; rng : Sexp.t
  ; digest : string
  }
[@@deriving compare, equal, sexp]

val create
  :  Snapshot_version.t
  -> Logical_time.t
  -> Event_index.t
  -> state:Sexp.t
  -> rng:Sexp.t
  -> t

val digest_of_capture : state:Sexp.t -> rng:Sexp.t -> string
