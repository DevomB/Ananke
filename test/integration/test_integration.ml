open Base

module E = Ananke_elevator.Domain
module M = Ananke_matching_engine.Domain

let scenario_path = "examples/elevator/scenarios/up_down.sexp"
let matching_engine_scenario_path =
  "examples/matching_engine/scenarios/basic.sexp"
;;

let run_save_replay_verify (type state command event)
    (module D : Domain.S
      with type state = state
       and type command = command
       and type event = event)
    scenario_path =
  let module R = Runtime.Make (D) in
  let module Rep = Replay.Make (D) in
  let scenario =
    match Scenario.load_file scenario_path with
    | Ok s -> s
    | Error err -> failwith (Ananke_error.to_string err)
  in
  let commands = List.map scenario.commands ~f:D.command_of_sexp in
  let config = { Config.default with rng_seed = scenario.rng_seed } in
  match R.create config |> fun rt -> R.run rt commands with
  | Error _ -> false
  | Ok result -> (
      let path = Filename.temp_file "ananke" ".trace.sexp" in
      Fun.protect ~finally:(fun () -> Sys.remove path) ~f:(fun () ->
          match Io.write_trace path result.trace with
          | Error _ -> false
          | Ok () -> (
              match Io.read_trace path with
              | Error _ -> false
              | Ok loaded -> (
                  match Rep.replay loaded config with
                  | Error _ -> false
                  | Ok replayed -> (
                      match Rep.verify loaded replayed with
                      | Ok () -> true
                      | Error _ -> false)))))
;;

let%test "run save replay verify" =
  run_save_replay_verify (module E) scenario_path
;;

let%test "matching_engine run save replay verify" =
  run_save_replay_verify (module M) matching_engine_scenario_path
;;
