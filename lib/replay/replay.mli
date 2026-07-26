(** Replay traces and verify determinism. *)

module Make (D : Domain.S) : sig
  val replay
    :  Trace.t
    -> Config.t
    -> (Trace.t, Chronicle_error.t) Result.t

  val verify
    :  Trace.t
    -> Trace.t
    -> (unit, Divergence.t) Result.t

  val commands_of_trace : Trace.t -> (D.command list, Chronicle_error.t) Result.t
end
