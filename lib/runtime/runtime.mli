(** Ananke runtime built from a domain module. *)

module Make (D : Domain.S) : sig
  type t

  val create : Config.t -> t
  val state : t -> D.state
  val trace : t -> Trace.t
  val metrics : t -> Metrics.t
  val clock : t -> Logical_time.t
  val event_index : t -> Event_index.t

  val step
    :  t
    -> D.command
    -> (D.state Transition_result.t, Ananke_error.t) Result.t

  val run
    :  t
    -> D.command list
    -> (D.state Transition_result.t, Ananke_error.t) Result.t
end
