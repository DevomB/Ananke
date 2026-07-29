open Base

(** Domain interface — implement this to plug into Ananke.

    [transition] receives an explicit [Rng.t]. Domains that need randomness
    must draw from that value and return the advanced RNG. Domains that do
    not need randomness must thread the RNG through unchanged. Never call
    ambient generators ([Stdlib.Random], [Base.Random], …). *)

module type S = sig
  type state [@@deriving sexp, compare]

  val state_of_sexp : Sexp.t -> state

  type command [@@deriving sexp]

  val command_of_sexp : Sexp.t -> command

  type event [@@deriving sexp]

  val name : string
  val version : int
  val initial_state : state

  val transition
    :  state
    -> Rng.t
    -> command
    -> (state * event list * Rng.t, Ananke_error.t) Result.t

  (** Named checkers. Names appear on [Event.Passed] / as fallbacks for
      [Event.Violated] when [Violation.name] is empty. *)
  val invariants : (string * (state -> (unit, Violation.t) Result.t)) list
end
