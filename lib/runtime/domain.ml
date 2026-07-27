(** Domain signature for Ananke runtimes. *)

module type S = sig
  type state [@@deriving sexp, compare]

  type command [@@deriving sexp]

  val command_of_sexp : Sexp.t -> command

  type event [@@deriving sexp]

  val name : string
  val version : int
  val initial_state : state

  val transition
    :  state
    -> command
    -> (state * event list, Ananke_error.t) Result.t

  val invariants : (state -> (unit, Violation.t) Result.t) list
end
