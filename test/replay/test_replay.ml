open Base
module E = Ananke_elevator.Domain
module R = Runtime.Make (E)
module Rep = Replay.Make (E)

module Failure_domain = struct
  type state = bool [@@deriving sexp, compare]

  type command =
    | Arm
    | Stateful_failure
    | Other_failure
  [@@deriving sexp, equal]

  type event = Armed [@@deriving sexp]

  let name = "failure_identity"
  let version = 1
  let initial_state = false

  let transition state rng = function
    | Arm -> Ok (true, [ Armed ], rng)
    | Stateful_failure when state ->
      Error (Ananke_error.Invalid_command "stateful failure")
    | Stateful_failure -> Ok (state, [], rng)
    | Other_failure -> Error (Ananke_error.Invalid_command "other failure")
  ;;

  let invariants = []
end

let%test "replay reproduces trace" =
  let commands = [ E.Request_floor 2; E.Step; E.Step ] in
  let config = Config.default in
  match R.create config |> fun rt -> R.run rt commands with
  | Error _ -> false
  | Ok result ->
    (match Rep.replay result.trace config with
     | Error _ -> false
     | Ok replayed ->
       (match Rep.verify result.trace replayed with
        | Ok () -> true
        | Error _ -> false))
;;

let%test "verify reports a truncated replay at the missing index" =
  let commands = [ E.Request_floor 2; E.Step ] in
  match R.create Config.default |> fun runtime -> R.run runtime commands with
  | Error _ -> false
  | Ok result ->
    let events =
      match List.rev result.trace.events with
      | [] -> []
      | _ :: rest -> List.rev rest
    in
    let replayed = { result.trace with events } in
    (match Rep.verify result.trace replayed with
     | Ok () -> false
     | Error divergence ->
       Event_index.to_int divergence.index = List.length events
       && String.equal divergence.message "replay ended before the expected event"
       && not (Diff.is_empty divergence.event_diff))
;;

let%test "verify reports structural event diff on mismatch" =
  let commands = [ E.Request_floor 2; E.Step ] in
  match R.create Config.default |> fun runtime -> R.run runtime commands with
  | Error _ -> false
  | Ok result ->
    let events =
      match result.trace.events with
      | first :: _ :: rest -> first :: Event.Emitted (Sexp.Atom "tampered") :: rest
      | _ -> []
    in
    let replayed = { result.trace with events } in
    (match Rep.verify result.trace replayed with
     | Ok () -> false
     | Error divergence ->
       String.equal divergence.message "event mismatch at replay"
       && (not (Diff.is_empty divergence.event_diff))
       && String.is_substring (Divergence.to_string divergence) ~substring:"event diff:")
;;

let%test "verify reports structural state diff when finals disagree" =
  let commands = [ E.Request_floor 2; E.Step ] in
  match R.create Config.default |> fun runtime -> R.run runtime commands with
  | Error _ -> false
  | Ok result ->
    let tampered_state = Sexp.List [ Sexp.Atom "floor"; Sexp.Atom "99" ] in
    let replayed = { result.trace with final_state = Some tampered_state } in
    (match Rep.verify result.trace replayed with
     | Ok () -> false
     | Error divergence ->
       String.equal divergence.message "final state mismatch"
       && Option.is_some divergence.state_diff
       && String.is_substring (Divergence.to_string divergence) ~substring:"state diff:")
;;

let%test "replay from checkpoint matches full-run suffix" =
  let commands = [ E.Request_floor 2; E.Step; E.Step; E.Request_floor 1; E.Step ] in
  let config = { Config.default with snapshot_each_command = true } in
  match R.create config |> fun runtime -> R.run runtime commands with
  | Error _ -> false
  | Ok result ->
    (match result.trace.snapshots with
     | [] -> false
     | checkpoint :: _ ->
       (match Rep.check_from_checkpoint result.trace checkpoint config with
        | Ok () -> true
        | Error _ -> false))
;;

let%test "replay_from_checkpoint + verify_same_result on mid snapshot" =
  let commands = [ E.Request_floor 3; E.Step; E.Step; E.Step ] in
  let config = { Config.default with snapshot_each_command = true } in
  match R.create config |> fun runtime -> R.run runtime commands with
  | Error _ -> false
  | Ok result ->
    (match result.trace.snapshots with
     | [] | [ _ ] -> false
     | _ :: checkpoint :: _ ->
       (match Rep.replay_from_checkpoint result.trace checkpoint config with
        | Error _ -> false
        | Ok suffix ->
          (match Rep.verify_same_result result.trace suffix checkpoint with
           | Ok () -> true
           | Error _ -> false)))
;;

let%test "branch identical suffixes do not diverge" =
  let module Br = Branch.Make (E) in
  match
    Br.fork
      Config.default
      ~prefix:[ E.Request_floor 2; E.Step ]
      ~baseline_suffix:[ E.Step ]
      ~alternate_suffix:[ E.Step ]
  with
  | Error _ -> false
  | Ok branch -> not (Branch.diverged branch)
;;

let%test "branch alternate suffix diverges final state" =
  let module Br = Branch.Make (E) in
  match
    Br.fork
      Config.default
      ~prefix:[ E.Request_floor 2; E.Step ]
      ~baseline_suffix:[ E.Step ]
      ~alternate_suffix:[ E.Request_floor 5; E.Step; E.Step ]
  with
  | Error _ -> false
  | Ok branch -> Branch.diverged branch
;;

let%test "fork_from_snapshot applies alternate suffix" =
  let module Br = Branch.Make (E) in
  let config = Config.default in
  match R.create config |> fun rt -> R.run rt [ E.Request_floor 3; E.Step ] with
  | Error _ -> false
  | Ok prefix_result ->
    let snap =
      Snapshot.create
        Snapshot_version.current
        (Logical_time.of_int64 (Int64.of_int prefix_result.trace.metadata.command_count))
        (Event_index.of_int (Trace.event_count prefix_result.trace))
        ~state:([%sexp_of: E.state] prefix_result.state)
        ~rng:([%sexp_of: Rng.t] prefix_result.rng)
    in
    (match R.restore config snap with
     | Error _ -> false
     | Ok restored ->
       let snap = R.snapshot restored in
       (match
          Br.fork_from_snapshot
            config
            snap
            ~baseline_suffix:[ E.Step ]
            ~alternate_suffix:[ E.Request_floor 1; E.Step ]
        with
        | Error _ -> false
        | Ok branch -> Branch.diverged branch))
;;

let%test "shrink drops irrelevant commands" =
  let fails xs = List.mem xs 7 ~equal:Int.equal && List.mem xs 3 ~equal:Int.equal in
  let result = Minimize.shrink ~fails [ 1; 3; 2; 7; 4 ] in
  Minimize.length_reduced result
  && List.equal Int.equal result.minimized [ 3; 7 ]
  && result.attempts > 1
;;

let%test "shrink leaves a non-failing sequence alone" =
  let result = Minimize.shrink ~fails:(fun _ -> false) [ 1; 2; 3 ] in
  List.equal Int.equal result.minimized [ 1; 2; 3 ]
;;

let%test "minimize shrinks to the failing command" =
  let module M = Minimize.Make (E) in
  let commands =
    [ E.Request_floor 2; E.Step; E.Request_floor 99; E.Step; E.Request_floor 1 ]
  in
  let result = M.minimize Config.default commands in
  match result.minimized with
  | [ E.Request_floor 99 ] -> Minimize.length_reduced result
  | _ -> false
;;

let%test "minimize preserves the original failure" =
  let module M = Minimize.Make (Failure_domain) in
  let result =
    M.minimize
      Config.default
      [ Failure_domain.Arm
      ; Failure_domain.Stateful_failure
      ; Failure_domain.Other_failure
      ]
  in
  List.equal
    Failure_domain.equal_command
    result.minimized
    [ Failure_domain.Arm; Failure_domain.Stateful_failure ]
;;

let%test "minimize_command_sexps parses then shrinks" =
  let module M = Minimize.Make (E) in
  let sexps =
    [ [%sexp_of: E.command] (E.Request_floor 1)
    ; [%sexp_of: E.command] E.Step
    ; [%sexp_of: E.command] (E.Request_floor 99)
    ]
  in
  match M.minimize_command_sexps Config.default sexps with
  | Error _ -> false
  | Ok result ->
    (match result.minimized with
     | [ E.Request_floor 99 ] -> true
     | _ -> false)
;;
