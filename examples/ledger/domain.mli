open Base

(** Simple bank account domain. *)

type state =
  { balance : int
  ; account : string
  }
[@@deriving sexp, compare]

type command =
  | Deposit of int
  | Withdraw of int
  | Transfer of string * int
[@@deriving sexp]

type event =
  | Deposited of int
  | Withdrawn of int
  | Transferred_out of string * int
[@@deriving sexp]

include
  Ananke_runtime.Domain.S
  with type state := state
   and type command := command
   and type event := event

val command_of_sexp : Sexp.t -> command
val state_of_sexp : Sexp.t -> state
