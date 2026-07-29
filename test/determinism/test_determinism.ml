module Domain_ = Domain
open Base

let run_twice
      (type state command event)
      (module D : Domain_.S
        with type state = state
         and type command = command
         and type event = event)
      commands
  =
  let module R = Runtime.Make (D) in
  let config = Config.default in
  let run () =
    match R.create config |> fun rt -> R.run rt commands with
    | Error _ -> None
    | Ok result -> Some result.trace
  in
  match run (), run () with
  | Some a, Some b -> Trace.equal a b
  | _ -> false
;;

let%test "elevator is deterministic" =
  let open Ananke_elevator.Domain in
  run_twice (module Ananke_elevator.Domain) [ Request_floor 4; Step; Step; Step; Step ]
;;

let%test "ledger is deterministic" =
  let open Ananke_ledger.Domain in
  run_twice (module Ananke_ledger.Domain) [ Deposit 100; Withdraw 25; Deposit 10 ]
;;
