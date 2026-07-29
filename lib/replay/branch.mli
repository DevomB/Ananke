(** Trace branching: fork from a snapshot, apply alternate suffixes, diff runs. *)

module Domain_ = Domain

type t =
  { snapshot : Snapshot.t
  ; baseline : Trace.t
  ; alternate : Trace.t
  ; state_diff : Diff.t
  }
[@@deriving sexp, compare, equal]

val diverged : t -> bool

module Make (D : Domain_.S) : sig
  (** Restore [snapshot], run both suffixes, return traces and structural state diff. *)
  val fork_from_snapshot
    :  Config.t
    -> Snapshot.t
    -> baseline_suffix:D.command list
    -> alternate_suffix:D.command list
    -> (t, Ananke_error.t) Result.t

  (** Run [prefix], capture a snapshot, then fork baseline vs alternate suffixes. *)
  val fork
    :  Config.t
    -> prefix:D.command list
    -> baseline_suffix:D.command list
    -> alternate_suffix:D.command list
    -> (t, Ananke_error.t) Result.t
end
