(** Domain signature for Ananke runtimes. *)

open Base

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

  val invariants : (string * (state -> (unit, Violation.t) Result.t)) list
end
