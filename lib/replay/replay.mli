(** Replay traces and verify determinism. *)

module Make (D : Domain.S) : sig
  val commands_of_sexps : Sexplib.Sexp.t list -> (D.command list, Ananke_error.t) Result.t
  val replay : Trace.t -> Config.t -> (Trace.t, Ananke_error.t) Result.t
  val verify : Trace.t -> Trace.t -> (unit, Divergence.t) Result.t
  val commands_of_trace : Trace.t -> (D.command list, Ananke_error.t) Result.t

  (** Commands whose events fall strictly after [at_index] (post-checkpoint suffix). *)
  val commands_after
    :  Trace.t
    -> Event_index.t
    -> (D.command list, Ananke_error.t) Result.t

  (** Restore [snapshot], replay only the command suffix from [original], return the
      suffix trace. *)
  val replay_from_checkpoint
    :  Trace.t
    -> Snapshot.t
    -> Config.t
    -> (Trace.t, Ananke_error.t) Result.t

  (** Compare [original]'s post-checkpoint events to a suffix trace from
      [replay_from_checkpoint]. *)
  val verify_same_result
    :  Trace.t
    -> Trace.t
    -> Snapshot.t
    -> (unit, Divergence.t) Result.t

  (** Restore → replay suffix → verify same result. *)
  val check_from_checkpoint
    :  Trace.t
    -> Snapshot.t
    -> Config.t
    -> (unit, Ananke_error.t) Result.t
end
