(** Point-in-time capture of domain state. *)

type t =
  { version : Snapshot_version.t
  ; at : Logical_time.t
  ; at_index : Event_index.t
  ; state : Sexp.t
  ; digest : string
  }
[@@deriving compare, equal, sexp]

val create
  :  Snapshot_version.t
  -> Logical_time.t
  -> Event_index.t
  -> Sexp.t
  -> t

val digest_of_state : Sexp.t -> string
