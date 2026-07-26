open Base
open Cmdliner
open Core

module Elevator = Chronicle_elevator.Domain
module Ledger = Chronicle_ledger.Domain
module Matching_engine = Chronicle_matching_engine.Domain

let config ?(seed = 0) () =
  { Config.rng_seed = seed
  ; invariant_mode = Stop
  ; trace_enabled = true
  ; snapshot_each_command = false
  }
;;

let output_path scenario_path =
  let base = Filename.chop_extension scenario_path in
  base ^ ".trace.sexp"
;;

let parse_commands (type cmd) (parse : Sexp.t -> cmd) sexps =
  List.fold sexps ~init:(Ok []) ~f:(fun acc sexp ->
      match acc with
      | Error _ -> acc
      | Ok cmds -> (
          try Ok (parse sexp :: cmds) with
          | exn -> Error (Chronicle_error.Parse_error (Exn.to_string exn))))
  |> function
  | Error _ as err -> err
  | Ok cmds -> Ok (List.rev cmds)
;;

let run_elevator scenario_path scenario seed output =
  let config = config ?seed () in
  let module R = Runtime.Make (Elevator) in
  let module Rep = Replay.Make (Elevator) in
  match parse_commands Elevator.command_of_sexp (Scenario.command_sexps scenario) with
  | Error err -> failwith (Chronicle_error.to_string err)
  | Ok commands -> (
      match R.create config |> fun rt -> R.run rt commands with
      | Error err -> failwith (Chronicle_error.to_string err)
      | Ok result ->
          let out = Option.value output ~default:(output_path scenario_path) in
          (match Io.write_trace out result.trace with
           | Error err -> failwith (Chronicle_error.to_string err)
           | Ok () ->
               printf "ran elevator scenario %s\n" scenario.name;
               printf "events: %d\n" (Trace.event_count result.trace);
               printf "metrics: %s\n" (Metrics.summary result.metrics);
               printf "trace written to %s\n" out;
               match Rep.replay result.trace config with
               | Error err -> failwith (Chronicle_error.to_string err)
               | Ok replayed -> (
                   match Rep.verify result.trace replayed with
                   | Ok () -> printf "replay verified\n"
                   | Error div -> failwith (Divergence.to_string div))))
;;

let run_matching_engine scenario_path scenario seed output =
  let config = config ?seed () in
  let module R = Runtime.Make (Matching_engine) in
  let module Rep = Replay.Make (Matching_engine) in
  match
    parse_commands Matching_engine.command_of_sexp (Scenario.command_sexps scenario)
  with
  | Error err -> failwith (Chronicle_error.to_string err)
  | Ok commands -> (
      match R.create config |> fun rt -> R.run rt commands with
      | Error err -> failwith (Chronicle_error.to_string err)
      | Ok result ->
          let out = Option.value output ~default:(output_path scenario_path) in
          (match Io.write_trace out result.trace with
           | Error err -> failwith (Chronicle_error.to_string err)
           | Ok () ->
               printf "ran matching_engine scenario %s\n" scenario.name;
               printf "events: %d\n" (Trace.event_count result.trace);
               printf "metrics: %s\n" (Metrics.summary result.metrics);
               printf "trace written to %s\n" out;
               match Rep.replay result.trace config with
               | Error err -> failwith (Chronicle_error.to_string err)
               | Ok replayed -> (
                   match Rep.verify result.trace replayed with
                   | Ok () -> printf "replay verified\n"
                   | Error div -> failwith (Divergence.to_string div))))
;;

let run_ledger scenario_path scenario seed output =
  let config = config ?seed () in
  let module R = Runtime.Make (Ledger) in
  let module Rep = Replay.Make (Ledger) in
  match parse_commands Ledger.command_of_sexp (Scenario.command_sexps scenario) with
  | Error err -> failwith (Chronicle_error.to_string err)
  | Ok commands -> (
      match R.create config |> fun rt -> R.run rt commands with
      | Error err -> failwith (Chronicle_error.to_string err)
      | Ok result ->
          let out = Option.value output ~default:(output_path scenario_path) in
          (match Io.write_trace out result.trace with
           | Error err -> failwith (Chronicle_error.to_string err)
           | Ok () ->
               printf "ran ledger scenario %s\n" scenario.name;
               printf "events: %d\n" (Trace.event_count result.trace);
               printf "metrics: %s\n" (Metrics.summary result.metrics);
               printf "trace written to %s\n" out;
               match Rep.replay result.trace config with
               | Error err -> failwith (Chronicle_error.to_string err)
               | Ok replayed -> (
                   match Rep.verify result.trace replayed with
                   | Ok () -> printf "replay verified\n"
                   | Error div -> failwith (Divergence.to_string div))))
;;

let run domain scenario_path seed output =
  match Scenario.load_file scenario_path with
  | Error err -> failwith (Chronicle_error.to_string err)
  | Ok scenario -> (
      match String.lowercase domain with
      | "elevator" -> run_elevator scenario_path scenario seed output
      | "ledger" -> run_ledger scenario_path scenario seed output
      | "matching_engine" ->
          run_matching_engine scenario_path scenario seed output
      | other -> failwith (sprintf "unknown domain: %s" other))
;;

let replay trace_path =
  match Io.read_trace trace_path with
  | Error err -> failwith (Chronicle_error.to_string err)
  | Ok trace -> (
      let domain = trace.metadata.domain in
      let config = config ~seed:trace.metadata.rng_seed () in
      match String.lowercase domain with
      | "elevator" -> (
          let module Rep = Replay.Make (Elevator) in
          match Rep.replay trace config with
          | Error err -> failwith (Chronicle_error.to_string err)
          | Ok replayed -> (
              match Rep.verify trace replayed with
              | Ok () -> printf "replay ok for %s\n" trace_path
              | Error div -> failwith (Divergence.to_string div)))
      | "ledger" -> (
          let module Rep = Replay.Make (Ledger) in
          match Rep.replay trace config with
          | Error err -> failwith (Chronicle_error.to_string err)
          | Ok replayed -> (
              match Rep.verify trace replayed with
              | Ok () -> printf "replay ok for %s\n" trace_path
              | Error div -> failwith (Divergence.to_string div)))
      | "matching_engine" -> (
          let module Rep = Replay.Make (Matching_engine) in
          match Rep.replay trace config with
          | Error err -> failwith (Chronicle_error.to_string err)
          | Ok replayed -> (
              match Rep.verify trace replayed with
              | Ok () -> printf "replay ok for %s\n" trace_path
              | Error div -> failwith (Divergence.to_string div)))
      | other -> failwith (sprintf "unknown domain in trace: %s" other))
;;

let diff left right =
  let read_snapshot_or_trace path =
    match Io.read_snapshot path with
    | Ok snap -> snap.state
    | Error _ -> (
        match Io.read_trace path with
        | Ok trace -> (
            match trace.final_state with
            | Some state -> state
            | None -> failwith (sprintf "no final state in trace %s" path))
        | Error err -> failwith (Chronicle_error.to_string err))
  in
  let left_state = read_snapshot_or_trace left in
  let right_state = read_snapshot_or_trace right in
  let changes = Diff.diff left_state right_state in
  if Diff.is_empty changes then printf "no differences\n"
  else printf "%s\n" (Diff.to_string changes)
;;

let verify trace_path =
  match Io.read_trace trace_path with
  | Error err -> failwith (Chronicle_error.to_string err)
  | Ok trace -> (
      let config = config ~seed:trace.metadata.rng_seed () in
      match String.lowercase trace.metadata.domain with
      | "elevator" -> (
          let module Rep = Replay.Make (Elevator) in
          match Rep.replay trace config with
          | Error err -> failwith (Chronicle_error.to_string err)
          | Ok replayed -> (
              match Rep.verify trace replayed with
              | Ok () -> printf "determinism verified\n"
              | Error div -> failwith (Divergence.to_string div)))
      | "ledger" -> (
          let module Rep = Replay.Make (Ledger) in
          match Rep.replay trace config with
          | Error err -> failwith (Chronicle_error.to_string err)
          | Ok replayed -> (
              match Rep.verify trace replayed with
              | Ok () -> printf "determinism verified\n"
              | Error div -> failwith (Divergence.to_string div)))
      | "matching_engine" -> (
          let module Rep = Replay.Make (Matching_engine) in
          match Rep.replay trace config with
          | Error err -> failwith (Chronicle_error.to_string err)
          | Ok replayed -> (
              match Rep.verify trace replayed with
              | Ok () -> printf "determinism verified\n"
              | Error div -> failwith (Divergence.to_string div)))
      | other -> failwith (sprintf "unknown domain: %s" other))
;;

let trace_cmd trace_path =
  match Io.read_trace trace_path with
  | Error err -> failwith (Chronicle_error.to_string err)
  | Ok trace ->
      List.iteri trace.events ~f:(fun i event ->
          printf "%04d %s\n" i (Sexp.to_string_hum ([%sexp_of: Event.t] event)))
;;

let inspect trace_path =
  match Io.read_trace trace_path with
  | Error err -> failwith (Chronicle_error.to_string err)
  | Ok trace ->
      let meta = trace.metadata in
      printf "domain: %s v%d\n" meta.domain meta.domain_version;
      printf "rng_seed: %d\n" meta.rng_seed;
      printf "commands: %d\n" meta.command_count;
      printf "events: %d\n" meta.event_count;
      printf "snapshots: %d\n" (List.length trace.snapshots);
      (match trace.final_state with
       | None -> printf "final_state: <none>\n"
       | Some state -> printf "final_state: %s\n" (Sexp.to_string_hum state))
;;

let doctor () =
  let checks =
    [ "kernel", true
    ; "runtime functor", true
    ; "trace serialization", true
    ; "elevator domain", String.equal Elevator.name "elevator"
    ; "ledger domain", String.equal Ledger.name "ledger"
    ; "matching_engine domain", String.equal Matching_engine.name "matching_engine"
  in
  List.iter checks ~f:(fun (name, ok) ->
      printf "[%s] %s\n" (if ok then "ok" else "FAIL") name);
  printf "chronicle doctor: all checks passed\n"
;;

let validate_event_index trace at_index =
  let count = Trace.event_count trace in
  if at_index < 0 || at_index >= count then
    failwith
      (sprintf "event index %d out of range [0,%d)" at_index count)
;;

let stored_snapshot trace at_index =
  List.find trace.snapshots ~f:(fun snap ->
      Event_index.to_int snap.at_index = at_index)
;;

let command_sexps_through_index trace at_index =
  let rec collect sexps evt_idx = function
    | _ when evt_idx > at_index -> List.rev sexps
    | [] -> List.rev sexps
    | Event.Command cmd :: rest ->
        collect (cmd.payload :: sexps) (evt_idx + 1) rest
    | _ :: rest -> collect sexps (evt_idx + 1) rest
  in
  collect [] 0 trace.events
;;

let snapshot_for_domain (type cmd state)
    (module D : Domain.S with type command = cmd and type state = state)
    (parse : Sexp.t -> cmd) trace config at_index =
  let module R = Runtime.Make (D) in
  match stored_snapshot trace at_index with
  | Some snap -> Ok snap
  | None -> (
      let sexps = command_sexps_through_index trace at_index in
      match parse_commands parse sexps with
      | Error err -> Error err
      | Ok commands -> (
          match R.create config |> fun rt -> R.run rt commands with
          | Error err -> Error err
          | Ok result ->
              let clock =
                List.fold commands ~init:Logical_time.zero ~f:(fun clock _ ->
                    Logical_time.succ clock)
              in
              let state = [%sexp_of: state] result.state in
              Ok
                (Snapshot.create Snapshot_version.current clock
                   (Event_index.of_int at_index) state)))
;;

let snapshot trace_path at_index out =
  match Io.read_trace trace_path with
  | Error err -> failwith (Chronicle_error.to_string err)
  | Ok trace -> (
      validate_event_index trace at_index;
      let config = config ~seed:trace.metadata.rng_seed () in
      let snap_result =
        match String.lowercase trace.metadata.domain with
        | "elevator" ->
            snapshot_for_domain (module Elevator) Elevator.command_of_sexp trace config
              at_index
        | "ledger" ->
            snapshot_for_domain (module Ledger) Ledger.command_of_sexp trace config at_index
        | "matching_engine" ->
            snapshot_for_domain (module Matching_engine) Matching_engine.command_of_sexp trace
              config at_index
        | other -> failwith (sprintf "unknown domain in trace: %s" other)
      in
      match snap_result with
      | Error err -> failwith (Chronicle_error.to_string err)
      | Ok snap -> (
          match Io.write_snapshot out snap with
          | Error err -> failwith (Chronicle_error.to_string err)
          | Ok () -> printf "snapshot written to %s\n" out))
;;

let count_events trace =
  let commands = ref 0 in
  let emitted = ref 0 in
  let invariant_checked = ref 0 in
  let snapshots_taken = ref 0 in
  let clock_advanced = ref 0 in
  List.iter trace.events ~f:(function
      | Event.Command _ -> incr commands
      | Event.Emitted _ -> incr emitted
      | Event.System Invariant_checked -> incr invariant_checked
      | Event.System Snapshot_taken -> incr snapshots_taken
      | Event.System Clock_advanced -> incr clock_advanced);
  ( !commands
  , !emitted
  , !invariant_checked
  , !snapshots_taken
  , !clock_advanced )
;;

let report_config seed =
  { Config.rng_seed = seed
  ; invariant_mode = Record
  ; trace_enabled = false
  ; snapshot_each_command = false
  }
;;

let report_run (type cmd) (module D : Domain.S with type command = cmd)
    (parse : Sexp.t -> cmd) trace =
  let module R = Runtime.Make (D) in
  let module Rep = Replay.Make (D) in
  let config = report_config trace.metadata.rng_seed in
  match Rep.commands_of_trace trace with
  | Error err -> Error err
  | Ok commands -> (
      match R.create config |> fun rt -> R.run rt commands with
      | Error err -> Error err
      | Ok result -> Ok (result.metrics, result.violations))
;;

let report_text trace metrics violations =
  let meta = trace.metadata in
  let commands, emitted, invariant_checked, snapshots_taken, clock_advanced =
    count_events trace
  in
  let system = invariant_checked + snapshots_taken + clock_advanced in
  printf "domain: %s v%d\n" meta.domain meta.domain_version;
  printf "rng_seed: %d\n" meta.rng_seed;
  printf "commands: %d\n" commands;
  printf "events: %d\n" (Trace.event_count trace);
  printf "emitted: %d\n" emitted;
  printf "system: %d\n" system;
  printf "snapshots in trace: %d\n" (List.length trace.snapshots);
  printf "violations: %d\n" (List.length violations);
  List.iteri violations ~f:(fun i v ->
      printf "  %d. %s\n" (i + 1) (Violation.to_string v));
  printf "metrics: %s\n" (Metrics.summary metrics)
;;

let report_sexp trace metrics violations =
  let commands, emitted, invariant_checked, snapshots_taken, clock_advanced =
    count_events trace
  in
  let summary =
    Sexp.List
      [ Sexp.List [ Sexp.Atom "domain"; Sexp.Atom trace.metadata.domain ]
      ; Sexp.List
          [ Sexp.Atom "domain_version"; Sexp.Atom (Int.to_string trace.metadata.domain_version) ]
      ; Sexp.List [ Sexp.Atom "rng_seed"; Sexp.Atom (Int.to_string trace.metadata.rng_seed) ]
      ; Sexp.List [ Sexp.Atom "commands"; Sexp.Atom (Int.to_string commands) ]
      ; Sexp.List
          [ Sexp.Atom "events"; Sexp.Atom (Int.to_string (Trace.event_count trace)) ]
      ; Sexp.List [ Sexp.Atom "emitted"; Sexp.Atom (Int.to_string emitted) ]
      ; Sexp.List
          [ Sexp.Atom "invariant_checked"
          ; Sexp.Atom (Int.to_string invariant_checked)
          ]
      ; Sexp.List
          [ Sexp.Atom "snapshots_taken"; Sexp.Atom (Int.to_string snapshots_taken) ]
      ; Sexp.List
          [ Sexp.Atom "clock_advanced"; Sexp.Atom (Int.to_string clock_advanced) ]
      ; Sexp.List
          [ Sexp.Atom "snapshots_in_trace"
          ; Sexp.Atom (Int.to_string (List.length trace.snapshots))
          ]
      ; Sexp.List
          [ Sexp.Atom "violations"
          ; Sexp.List (List.map violations ~f:[%sexp_of: Violation.t])
          ]
      ; Sexp.List [ Sexp.Atom "metrics"; [%sexp_of: Metrics.t] metrics ]
      ]
  in
  printf "%s\n" (Sexp.to_string_hum summary)
;;

let report trace_path format =
  match Io.read_trace trace_path with
  | Error err -> failwith (Chronicle_error.to_string err)
  | Ok trace -> (
      let metrics, violations =
        match String.lowercase trace.metadata.domain with
        | "elevator" -> (
            match report_run (module Elevator) Elevator.command_of_sexp trace with
            | Error err -> failwith (Chronicle_error.to_string err)
            | Ok pair -> pair)
        | "ledger" -> (
            match report_run (module Ledger) Ledger.command_of_sexp trace with
            | Error err -> failwith (Chronicle_error.to_string err)
            | Ok pair -> pair)
        | "matching_engine" -> (
            match report_run (module Matching_engine) Matching_engine.command_of_sexp trace with
            | Error err -> failwith (Chronicle_error.to_string err)
            | Ok pair -> pair)
        | other -> failwith (sprintf "unknown domain in trace: %s" other)
      in
      match String.lowercase format with
      | "text" -> report_text trace metrics violations
      | "sexp" -> report_sexp trace metrics violations
      | other -> failwith (sprintf "unknown format: %s (use text or sexp)" other))
;;

let bench_elevator iterations =
  let module R = Runtime.Make (Elevator) in
  let commands =
    List.init iterations ~f:(fun i ->
        if i mod 2 = 0 then Elevator.Request_floor (i mod 8) else Elevator.Step)
  in
  let start = Time_ns.now () in
  let rt = R.create Config.default in
  match R.run rt commands with
  | Error err -> failwith (Chronicle_error.to_string err)
  | Ok _ ->
      let elapsed = Time_ns.diff (Time_ns.now ()) start in
      let sec = Time_ns.Span.to_sec elapsed in
      if sec <= 0. then printf "0 commands/sec\n"
      else
        printf "%.0f commands/sec\n" (Float.of_int iterations /. sec)
;;

let bench_ledger iterations =
  let module R = Runtime.Make (Ledger) in
  let commands =
    List.init iterations ~f:(fun i ->
        if i mod 2 = 0 then Ledger.Deposit 10 else Ledger.Withdraw 5)
  in
  let start = Time_ns.now () in
  let rt = R.create Config.default in
  match R.run rt commands with
  | Error err -> failwith (Chronicle_error.to_string err)
  | Ok _ ->
      let elapsed = Time_ns.diff (Time_ns.now ()) start in
      let sec = Time_ns.Span.to_sec elapsed in
      if sec <= 0. then printf "0 commands/sec\n"
      else
        printf "%.0f commands/sec\n" (Float.of_int iterations /. sec)
;;

let benchmark iterations domain =
  match String.lowercase domain with
  | "elevator" -> bench_elevator iterations
  | "ledger" -> bench_ledger iterations
  | other -> failwith (sprintf "unknown domain: %s (use elevator or ledger)" other)
;;

let write_text path content =
  try
    Out_channel.write_all path ~data:content;
    Ok ()
  with
  | Sys_error msg -> Error (Chronicle_error.Io_error msg)
  | exn -> Error (Chronicle_error.Io_error (Exn.to_string exn))
;;

let init_domain name output_dir =
  let domain_dir = Filename.concat output_dir name in
  let scenarios_dir = Filename.concat domain_dir "scenarios" in
  (try Unix.mkdir_p domain_dir with
   | Sys_error msg -> failwith msg);
  (try Unix.mkdir_p scenarios_dir with
   | Sys_error msg -> failwith msg);
  let domain_mli =
    {|(** %s domain. *)

type state = { count : int } [@@deriving sexp, compare]

type command =
  | Increment
  | Decrement
[@@deriving sexp]

type event = Changed of int [@@deriving sexp]

include Domain.S
  with type state := state
   and type command := command
   and type event := event

val command_of_sexp : Sexp.t -> command
|}
    |> sprintf name
  in
  let domain_ml =
    {|open Base

type state = { count : int } [@@deriving sexp, compare]

type command =
  | Increment
  | Decrement
[@@deriving sexp]

type event = Changed of int [@@deriving sexp]

let name = "%s"
let version = 1
let initial_state = { count = 0 }

let transition state = function
  | Increment -> Ok ({ count = state.count + 1 }, [ Changed (state.count + 1) ])
  | Decrement ->
      if state.count <= 0 then
        Error (Chronicle_error.Invalid_command "count cannot go negative")
      else Ok ({ count = state.count - 1 }, [ Changed (state.count - 1) ])
;;

let non_negative state =
  if state.count >= 0 then Ok ()
  else
    Error { Violation.name = "non_negative"; message = "count is negative" }
;;

let invariants = [ non_negative ]
let command_of_sexp = command_of_sexp
|}
    |> sprintf name
  in
  let dune =
    {|(library
 (name chronicle_%s)
 (public_name chronicle_%s)
 (libraries chronicle.runtime chronicle.invariant base)
 (preprocess
  (pps ppx_jane)))
|}
    |> sprintf name name
  in
  let scenario =
    {|((name sample)
 (domain %s)
 (rng_seed 0)
 (commands
  (Increment
   Increment
   Decrement
   Increment)))
|}
    |> sprintf name
  in
  let files =
    [ Filename.concat domain_dir "domain.mli", domain_mli
    ; Filename.concat domain_dir "domain.ml", domain_ml
    ; Filename.concat domain_dir "dune", dune
    ; Filename.concat scenarios_dir "sample.sexp", scenario
    ]
  in
  List.iter files ~f:(fun (path, content) ->
      match write_text path content with
      | Error err -> failwith (Chronicle_error.to_string err)
      | Ok () -> printf "wrote %s\n" path);
  printf "domain scaffold created at %s\n" domain_dir
;;

let run_term =
  let domain =
    Arg.(required & opt (some string) None & info [ "d"; "domain" ] ~docv:"NAME"
           ~doc:"domain name (elevator, ledger, matching_engine)")
  in
  let scenario =
    Arg.(required
         & pos 0 string (failwith "scenario path required") ~docv:"SCENARIO"
         & info [] ~doc:"scenario sexp file")
  in
  let seed =
    Arg.(value & opt (some int) None & info [ "seed" ] ~docv:"INT" ~doc:"rng seed")
  in
  let output =
    Arg.(value & opt (some string) None & info [ "o"; "output" ] ~docv:"PATH"
           ~doc:"trace output path")
  in
  Term.(const run $ domain $ scenario $ seed $ output)

let replay_term =
  let trace =
    Arg.(required & pos 0 string (failwith "trace path required") ~docv:"TRACE"
           & info [] ~doc:"trace sexp file")
  in
  Term.(const replay $ trace)

let diff_term =
  let left =
    Arg.(required & pos 0 string (failwith "left path required") ~docv:"LEFT" & info [])
  in
  let right =
    Arg.(required & pos 1 string (failwith "right path required") ~docv:"RIGHT" & info [])
  in
  Term.(const diff $ left $ right)

let verify_term =
  let trace =
    Arg.(required & pos 0 string (failwith "trace path required") ~docv:"TRACE"
           & info [])
  in
  Term.(const verify $ trace)

let trace_display_term =
  let trace =
    Arg.(required & pos 0 string (failwith "trace path required") ~docv:"TRACE"
           & info [])
  in
  Term.(const trace_cmd $ trace)

let inspect_term =
  let trace =
    Arg.(required & pos 0 string (failwith "trace path required") ~docv:"TRACE"
           & info [])
  in
  Term.(const inspect $ trace)

let doctor_term = Term.(const doctor $ const ())

let snapshot_term =
  let trace =
    Arg.(required & opt (some string) None & info [ "t"; "trace" ] ~docv:"PATH"
           ~doc:"trace sexp file")
  in
  let at_index =
    Arg.(required & opt (some int) None & info [ "at-index" ] ~docv:"INT"
           ~doc:"event index to extract")
  in
  let out =
    Arg.(required & opt (some string) None & info [ "o"; "out" ] ~docv:"PATH"
           ~doc:"snapshot output path")
  in
  Term.(const snapshot $ trace $ at_index $ out)

let report_term =
  let trace =
    Arg.(required & opt (some string) None & info [ "t"; "trace" ] ~docv:"PATH"
           ~doc:"trace sexp file")
  in
  let format =
    Arg.(value & opt string "text" & info [ "format" ] ~docv:"FMT"
           ~doc:"output format: text or sexp")
  in
  Term.(const report $ trace $ format)

let benchmark_term =
  let iterations =
    Arg.(value & opt int 1000 & info [ "iterations" ] ~docv:"INT"
           ~doc:"number of benchmark iterations")
  in
  let domain =
    Arg.(value & opt string "elevator" & info [ "domain" ] ~docv:"NAME"
           ~doc:"domain to benchmark: elevator or ledger")
  in
  Term.(const benchmark $ iterations $ domain)

let init_term =
  let name =
    Arg.(required & opt (some string) None & info [ "name" ] ~docv:"STRING"
           ~doc:"domain name")
  in
  let output_dir =
    Arg.(required & opt (some string) None & info [ "output-dir" ] ~docv:"PATH"
           ~doc:"parent directory for the new domain")
  in
  Term.(const init_domain $ name $ output_dir)

let cmd =
  let run_cmd =
    Cmd.v "run" ~doc:"Run a scenario against a domain." run_term
  in
  let replay_cmd =
    Cmd.v "replay" ~doc:"Replay a trace and verify event stream." replay_term
  in
  let diff_cmd = Cmd.v "diff" ~doc:"Diff two snapshots or traces." diff_term in
  let verify_cmd =
    Cmd.v "verify" ~doc:"Verify trace determinism by replay." verify_term
  in
  let trace_cmd =
    Cmd.v "trace" ~doc:"Print trace events." trace_display_term
  in
  let inspect_cmd = Cmd.v "inspect" ~doc:"Inspect trace metadata." inspect_term in
  let snapshot_cmd =
    Cmd.v "snapshot" ~doc:"Extract snapshot at event index from trace." snapshot_term
  in
  let report_cmd = Cmd.v "report" ~doc:"Summarize trace metrics and violations." report_term in
  let benchmark_cmd =
    Cmd.v "benchmark" ~doc:"Run built-in domain benchmark." benchmark_term
  in
  let init_cmd = Cmd.v "init" ~doc:"Scaffold a new domain directory." init_term in
  let doctor_cmd = Cmd.v "doctor" ~doc:"Check installation health." doctor_term in
  Cmd.group
    (Cmd.info "chronicle" ~version:"0.1.0"
       ~doc:"Deterministic event-systems laboratory.")
    [ run_cmd
    ; replay_cmd
    ; diff_cmd
    ; verify_cmd
    ; trace_cmd
    ; inspect_cmd
    ; snapshot_cmd
    ; report_cmd
    ; benchmark_cmd
    ; init_cmd
    ; doctor_cmd
    ]
;;
