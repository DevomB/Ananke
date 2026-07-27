(** Replay traces and verify determinism. *)

module Make (D : Domain.S) : sig
  val replay
    :  Trace.t
    -> Config.t
    -> (Trace.t, Ananke_error.t) Result.t

  val verify
    :  Trace.t
    -> Trace.t
    -> (unit, Divergence.t) Result.t

  val commands_of_trace : Trace.t -> (D.command list, Ananke_error.t) Result.t
end
