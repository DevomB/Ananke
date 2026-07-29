open Base

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

let name = "ledger"
let version = 1
let initial_state = { balance = 0; account = "primary" }

let transition state rng = function
  | Deposit amount ->
    if amount <= 0
    then Error (Ananke_error.Invalid_command "deposit amount must be positive")
    else Ok ({ state with balance = state.balance + amount }, [ Deposited amount ], rng)
  | Withdraw amount ->
    if amount <= 0
    then Error (Ananke_error.Invalid_command "withdraw amount must be positive")
    else if state.balance < amount
    then Error (Ananke_error.Invalid_command "insufficient funds")
    else Ok ({ state with balance = state.balance - amount }, [ Withdrawn amount ], rng)
  | Transfer (dest, amount) ->
    if amount <= 0
    then Error (Ananke_error.Invalid_command "transfer amount must be positive")
    else if state.balance < amount
    then Error (Ananke_error.Invalid_command "insufficient funds for transfer")
    else
      Ok
        ( { state with balance = state.balance - amount }
        , [ Transferred_out (dest, amount) ]
        , rng )
;;

let non_negative_balance state =
  if state.balance >= 0
  then Ok ()
  else
    Error
      { Violation.name = "non_negative_balance"
      ; message = Printf.sprintf "balance is negative: %d" state.balance
      }
;;

let invariants = [ "non_negative_balance", non_negative_balance ]
let command_of_sexp = command_of_sexp
let state_of_sexp = state_of_sexp
