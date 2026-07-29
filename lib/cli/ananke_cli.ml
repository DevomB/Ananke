open Base
open Cmdliner

let printf = Stdlib.Printf.printf
let sprintf = Stdlib.Printf.sprintf
let fail_error error = failwith (Ananke_error.to_string error)

module Elevator = Ananke_elevator.Domain
module Ledger = Ananke_ledger.Domain

let config ?(seed = 0) () =
  { Config.rng_seed = seed
  ; invariant_mode = Stop
  ; trace_enabled = true
  ; snapshot_each_command = false
  }
;;

let output_path scenario_path =
  let base = Stdlib.Filename.chop_extension scenario_path in
  base ^ ".trace.sexp"
;;

let read_trace path =
  match Io.read_trace path with
  | Ok trace -> trace
  | Error error -> fail_error error
;;

let run_domain (module D : Ananke_runtime.Domain.S) scenario_path scenario seed output =
  let config = config ?seed () in
  let module R = Runtime.Make (D) in
  let module Rep = Replay.Make (D) in
  match Rep.commands_of_sexps (Scenario.command_sexps scenario) with
  | Error error -> fail_error error
  | Ok commands ->
    (match R.create config |> fun rt -> R.run rt commands with
     | Error error -> fail_error error
     | Ok result ->
       let out = Option.value output ~default:(output_path scenario_path) in
       (match Io.write_trace out result.trace with
        | Error error -> fail_error error
        | Ok () ->
          printf "ran %s scenario %s\n" D.name scenario.name;
          printf "events: %d\n" (Trace.event_count result.trace);
          printf "metrics: %s\n" (Metrics.summary result.metrics);
          printf "trace written to %s\n" out;
          (match Rep.replay result.trace config with
           | Error error -> fail_error error
           | Ok replayed ->
             (match Rep.verify result.trace replayed with
              | Ok () -> printf "replay verified\n"
              | Error div -> failwith (Divergence.to_string div)))))
;;

let run domain scenario_path seed output =
  match Scenario.load_file scenario_path with
  | Error error -> fail_error error
  | Ok scenario ->
    let seed = Option.value seed ~default:scenario.rng_seed in
    Domain_registry.with_domain domain ~f:(fun (module D : Ananke_runtime.Domain.S) ->
      run_domain (module D) scenario_path scenario (Some seed) output)
;;

let replay_and_verify (module D : Ananke_runtime.Domain.S) (trace : Trace.t) config =
  let module Rep = Replay.Make (D) in
  match Rep.replay trace config with
  | Error error -> fail_error error
  | Ok replayed ->
    (match Rep.verify trace replayed with
     | Ok () -> ()
     | Error divergence -> failwith (Divergence.to_string divergence))
;;

let replay trace_path =
  let trace = read_trace trace_path in
  let config = config ~seed:trace.metadata.rng_seed () in
  Domain_registry.with_domain trace.metadata.domain ~f:(fun packed ->
    replay_and_verify packed trace config);
  printf "replay ok for %s\n" trace_path
;;

let diff left right =
  let read_snapshot_or_trace path =
    match Io.read_snapshot path with
    | Ok snap -> snap.state
    | Error _ ->
      (match Io.read_trace path with
       | Ok trace ->
         (match trace.final_state with
          | Some state -> state
          | None -> failwith (sprintf "no final state in trace %s" path))
       | Error error -> fail_error error)
  in
  let left_state = read_snapshot_or_trace left in
  let right_state = read_snapshot_or_trace right in
  let changes = Diff.diff left_state right_state in
  if Diff.is_empty changes
  then printf "no differences\n"
  else printf "%s\n" (Diff.to_string changes)
;;

let verify trace_path =
  let trace = read_trace trace_path in
  let config = config ~seed:trace.metadata.rng_seed () in
  Domain_registry.with_domain trace.metadata.domain ~f:(fun packed ->
    replay_and_verify packed trace config);
  printf "determinism verified\n"
;;

let trace_cmd trace_path =
  let trace = read_trace trace_path in
  List.iteri trace.events ~f:(fun i event ->
    printf "%04d %s\n" i (Sexp.to_string_hum ([%sexp_of: Event.t] event)))
;;

let violations_from_trace (trace : Trace.t) =
  List.filter_map (Trace.invariant_violations trace) ~f:(function
    | Event.Violated { name; message } -> Some { Violation.name; message }
    | Event.Passed _ -> None)
;;

let inspect trace_path =
  let trace = read_trace trace_path in
  let meta = trace.metadata in
  let violations = violations_from_trace trace in
  let outcomes = Trace.invariant_outcomes trace in
  printf "domain: %s v%d\n" meta.domain meta.domain_version;
  printf "rng_seed: %d\n" meta.rng_seed;
  printf "commands: %d\n" meta.command_count;
  printf "events: %d\n" meta.event_count;
  printf "snapshots: %d\n" (List.length trace.snapshots);
  printf "invariant_outcomes: %d\n" (List.length outcomes);
  List.iteri outcomes ~f:(fun i outcome ->
    match outcome with
    | Event.Passed { name } -> printf "  %d. PASS %s\n" (i + 1) name
    | Event.Violated { name; message } ->
      printf "  %d. FAIL %s: %s\n" (i + 1) name message);
  printf "invariant_violations: %d\n" (List.length violations);
  List.iteri violations ~f:(fun i v ->
    printf "  %d. %s\n" (i + 1) (Violation.to_string v));
  match trace.final_state with
  | None -> printf "final_state: <none>\n"
  | Some state -> printf "final_state: %s\n" (Sexp.to_string_hum state)
;;

let doctor () =
  let check_domain (module D : Ananke_runtime.Domain.S) =
    let module R = Runtime.Make (D) in
    let module Rep = Replay.Make (D) in
    match R.create Config.default |> fun runtime -> R.run runtime [] with
    | Error _ -> false
    | Ok result ->
      (match Rep.replay result.trace Config.default with
       | Error _ -> false
       | Ok replayed -> Result.is_ok (Rep.verify result.trace replayed))
  in
  let checks =
    List.map Domain_registry.all ~f:(fun ((module D) as domain) ->
      D.name ^ " empty-run replay", check_domain domain)
  in
  List.iter checks ~f:(fun (name, ok) ->
    printf "[%s] %s\n" (if ok then "ok" else "FAIL") name);
  if List.for_all checks ~f:snd
  then printf "ananke doctor: all checks passed\n"
  else failwith "ananke doctor: one or more checks failed"
;;

let validate_event_index (trace : Trace.t) at_index =
  let count = Trace.event_count trace in
  if at_index < 0 || at_index >= count
  then failwith (sprintf "event index %d out of range [0,%d)" at_index count)
;;

let stored_snapshot (trace : Trace.t) at_index =
  List.find trace.snapshots ~f:(fun snap -> Event_index.to_int snap.at_index = at_index)
;;

let command_sexps_through_index (trace : Trace.t) at_index =
  let rec collect sexps evt_idx = function
    | _ when evt_idx > at_index -> List.rev sexps
    | [] -> List.rev sexps
    | Event.Command cmd :: rest -> collect (cmd.payload :: sexps) (evt_idx + 1) rest
    | _ :: rest -> collect sexps (evt_idx + 1) rest
  in
  collect [] 0 trace.events
;;

(** Last original-trace event index covered by the first [command_count] commands
    (Clock_advanced, or the following Snapshot_taken when present). *)
let at_index_after_commands (trace : Trace.t) command_count =
  if command_count <= 0
  then Event_index.zero
  else (
    let rec go done_cmds idx = function
      | [] -> Event_index.of_int (Int.max 0 (idx - 1))
      | Event.System Clock_advanced :: rest ->
        let done_cmds = done_cmds + 1 in
        if done_cmds >= command_count
        then (
          match rest with
          | Event.System Snapshot_taken :: _ -> Event_index.of_int (idx + 1)
          | _ -> Event_index.of_int idx)
        else go done_cmds (idx + 1) rest
      | _ :: rest -> go done_cmds (idx + 1) rest
    in
    go 0 0 trace.events)
;;

let snapshot_for_domain
      (module D : Ananke_runtime.Domain.S)
      (trace : Trace.t)
      config
      at_index
  =
  let module R = Runtime.Make (D) in
  let module Rep = Replay.Make (D) in
  match stored_snapshot trace at_index with
  | Some snap -> Ok snap
  | None ->
    let sexps = command_sexps_through_index trace at_index in
    (match Rep.commands_of_sexps sexps with
     | Error err -> Error err
     | Ok commands ->
       (match R.create config |> fun rt -> R.run rt commands with
        | Error err -> Error err
        | Ok result ->
          let clock =
            List.fold commands ~init:Logical_time.zero ~f:(fun clock _ ->
              Logical_time.succ clock)
          in
          let snap_index = at_index_after_commands trace (List.length commands) in
          Ok
            (Snapshot.create
               Snapshot_version.current
               clock
               snap_index
               ~state:(D.sexp_of_state result.state)
               ~rng:([%sexp_of: Rng.t] result.rng))))
;;

let snapshot trace_path at_index out =
  let trace = read_trace trace_path in
  validate_event_index trace at_index;
  let config = config ~seed:trace.metadata.rng_seed () in
  let snap_result =
    Domain_registry.with_domain
      trace.metadata.domain
      ~f:(fun (module D : Ananke_runtime.Domain.S) ->
        snapshot_for_domain (module D) trace config at_index)
  in
  match snap_result with
  | Error error -> fail_error error
  | Ok snap ->
    (match Io.write_snapshot out snap with
     | Error error -> fail_error error
     | Ok () -> printf "snapshot written to %s\n" out)
;;

let count_events (trace : Trace.t) =
  let commands = ref 0 in
  let emitted = ref 0 in
  let invariant_checked = ref 0 in
  let snapshots_taken = ref 0 in
  let clock_advanced = ref 0 in
  List.iter trace.events ~f:(function
    | Event.Command _ -> Int.incr commands
    | Event.Emitted _ -> Int.incr emitted
    | Event.System (Invariant_checked _) -> Int.incr invariant_checked
    | Event.System Snapshot_taken -> Int.incr snapshots_taken
    | Event.System Clock_advanced -> Int.incr clock_advanced);
  !commands, !emitted, !invariant_checked, !snapshots_taken, !clock_advanced
;;

let report_config seed =
  { (config ~seed ()) with invariant_mode = Record; trace_enabled = false }
;;

let report_run (module D : Ananke_runtime.Domain.S) (trace : Trace.t) =
  let module R = Runtime.Make (D) in
  let module Rep = Replay.Make (D) in
  let config = report_config trace.metadata.rng_seed in
  match Rep.commands_of_trace trace with
  | Error err -> Error err
  | Ok commands ->
    (match R.create config |> fun rt -> R.run rt commands with
     | Error err -> Error err
     | Ok result -> Ok (result.metrics, result.violations))
;;

let report_text (trace : Trace.t) metrics violations =
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

let report_sexp (trace : Trace.t) metrics violations =
  let commands, emitted, invariant_checked, snapshots_taken, clock_advanced =
    count_events trace
  in
  let summary =
    Sexp.List
      [ Sexp.List [ Sexp.Atom "domain"; Sexp.Atom trace.metadata.domain ]
      ; Sexp.List
          [ Sexp.Atom "domain_version"
          ; Sexp.Atom (Int.to_string trace.metadata.domain_version)
          ]
      ; Sexp.List
          [ Sexp.Atom "rng_seed"; Sexp.Atom (Int.to_string trace.metadata.rng_seed) ]
      ; Sexp.List [ Sexp.Atom "commands"; Sexp.Atom (Int.to_string commands) ]
      ; Sexp.List
          [ Sexp.Atom "events"; Sexp.Atom (Int.to_string (Trace.event_count trace)) ]
      ; Sexp.List [ Sexp.Atom "emitted"; Sexp.Atom (Int.to_string emitted) ]
      ; Sexp.List
          [ Sexp.Atom "invariant_checked"; Sexp.Atom (Int.to_string invariant_checked) ]
      ; Sexp.List
          [ Sexp.Atom "snapshots_taken"; Sexp.Atom (Int.to_string snapshots_taken) ]
      ; Sexp.List [ Sexp.Atom "clock_advanced"; Sexp.Atom (Int.to_string clock_advanced) ]
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
  let trace = read_trace trace_path in
  let violations = violations_from_trace trace in
  let metrics =
    Domain_registry.with_domain
      trace.metadata.domain
      ~f:(fun (module D : Ananke_runtime.Domain.S) ->
        match report_run (module D) trace with
        | Error error -> fail_error error
        | Ok (metrics, _) -> metrics)
  in
  match String.lowercase format with
  | "text" -> report_text trace metrics violations
  | "sexp" -> report_sexp trace metrics violations
  | other -> failwith (sprintf "unknown format: %s (use text or sexp)" other)
;;

let time_benchmark iterations run =
  let start = Unix.gettimeofday () in
  match run () with
  | Error error -> fail_error error
  | Ok _ ->
    let elapsed = Unix.gettimeofday () -. start in
    if Float.(elapsed <= 0.)
    then printf "0 commands/sec\n"
    else printf "%.0f commands/sec\n" Float.(of_int iterations / elapsed)
;;

let bench_elevator iterations =
  let module R = Runtime.Make (Elevator) in
  let commands =
    List.init iterations ~f:(fun i ->
      if Int.rem i 2 = 0 then Elevator.Request_floor (Int.rem i 8) else Elevator.Step)
  in
  time_benchmark iterations (fun () -> R.run (R.create Config.default) commands)
;;

let bench_ledger iterations =
  let module R = Runtime.Make (Ledger) in
  let commands =
    List.init iterations ~f:(fun i ->
      if Int.rem i 2 = 0 then Ledger.Deposit 10 else Ledger.Withdraw 5)
  in
  time_benchmark iterations (fun () -> R.run (R.create Config.default) commands)
;;

let benchmark iterations domain =
  Domain_registry.with_domain domain ~f:(fun (module D : Ananke_runtime.Domain.S) ->
    match String.lowercase D.name with
    | "elevator" -> bench_elevator iterations
    | "ledger" -> bench_ledger iterations
    | _ ->
      failwith
        (sprintf
           "benchmark sequences not defined for %s (supported: elevator, ledger)"
           D.name))
;;

let rec mkdir_p path =
  if String.is_empty path || String.equal path (Stdlib.Filename.dirname path)
  then ()
  else if Stdlib.Sys.file_exists path
  then (
    if not (Stdlib.Sys.is_directory path)
    then failwith (sprintf "%s exists and is not a directory" path))
  else (
    mkdir_p (Stdlib.Filename.dirname path);
    Unix.mkdir path 0o755)
;;

let init_domain name output_dir =
  let domain_dir = Stdlib.Filename.concat output_dir name in
  let scenarios_dir = Stdlib.Filename.concat domain_dir "scenarios" in
  (try mkdir_p domain_dir with
   | Sys_error msg -> failwith msg);
  (try mkdir_p scenarios_dir with
   | Sys_error msg -> failwith msg);
  let domain_mli =
    {|(** %s domain. *)

open Base

type state = { count : int } [@@deriving sexp, compare]

type command =
  | Increment
  | Decrement
[@@deriving sexp]

type event = Changed of int [@@deriving sexp]

include Ananke_runtime.Domain.S
  with type state := state
   and type command := command
   and type event := event

val command_of_sexp : Sexp.t -> command
val state_of_sexp : Sexp.t -> state
|}
    |> fun template -> sprintf template name
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

let transition state rng = function
  | Increment -> Ok ({ count = state.count + 1 }, [ Changed (state.count + 1) ], rng)
  | Decrement ->
      if state.count <= 0 then
        Error (Ananke_error.Invalid_command "count cannot go negative")
      else Ok ({ count = state.count - 1 }, [ Changed (state.count - 1) ], rng)
;;

let non_negative state =
  if state.count >= 0 then Ok ()
  else
    Error { Violation.name = "non_negative"; message = "count is negative" }
;;

let invariants = [ ("non_negative", non_negative) ]
let command_of_sexp = command_of_sexp
let state_of_sexp = state_of_sexp
|}
    |> fun template -> sprintf template name
  in
  let dune =
    {|(library
 (name ananke_%s)
 (libraries ananke.runtime ananke.invariant base)
 (preprocess
  (pps ppx_jane)))
|}
    |> fun template -> sprintf template name
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
    |> fun template -> sprintf template name
  in
  let files =
    [ Stdlib.Filename.concat domain_dir "domain.mli", domain_mli
    ; Stdlib.Filename.concat domain_dir "domain.ml", domain_ml
    ; Stdlib.Filename.concat domain_dir "dune", dune
    ; Stdlib.Filename.concat scenarios_dir "sample.sexp", scenario
    ]
  in
  List.iter files ~f:(fun (path, content) ->
    match Io.write_text path content with
    | Error error -> fail_error error
    | Ok () -> printf "wrote %s\n" path);
  printf "domain scaffold created at %s\n" domain_dir
;;

let load_scenario_commands path =
  Result.map (Scenario.load_file path) ~f:Scenario.command_sexps
;;

let checkpoint_domain
      (module D : Ananke_runtime.Domain.S)
      (trace : Trace.t)
      config
      at_index
  =
  let module Rep = Replay.Make (D) in
  match snapshot_for_domain (module D) trace config at_index with
  | Error _ as err -> err
  | Ok snap ->
    (match Rep.check_from_checkpoint trace snap config with
     | Ok () -> Ok snap
     | Error _ as err -> err)
;;

let checkpoint trace_path at_index =
  let trace = read_trace trace_path in
  validate_event_index trace at_index;
  let config = config ~seed:trace.metadata.rng_seed () in
  Domain_registry.with_domain trace.metadata.domain ~f:(fun packed ->
    match checkpoint_domain packed trace config at_index with
    | Error error -> fail_error error
    | Ok snap ->
      printf
        "checkpoint ok at index %d (clock %Ld)\n"
        at_index
        (Logical_time.to_int64 snap.at))
;;

let minimize_domain (module D : Ananke_runtime.Domain.S) scenario_path seed =
  let module M = Minimize.Make (D) in
  match Scenario.load_file scenario_path with
  | Error error -> fail_error error
  | Ok scenario ->
    let seed = Option.value seed ~default:scenario.rng_seed in
    let config = config ~seed () in
    (match M.minimize_command_sexps config (Scenario.command_sexps scenario) with
     | Error error -> fail_error error
     | Ok result ->
       printf
         "minimized %d -> %d commands (%d attempts)\n"
         (List.length result.original)
         (List.length result.minimized)
         result.attempts;
       List.iter result.minimized ~f:(fun cmd ->
         printf "  %s\n" (Sexp.to_string_hum ([%sexp_of: D.command] cmd))))
;;

let minimize domain scenario_path seed =
  Domain_registry.with_domain domain ~f:(fun packed ->
    minimize_domain packed scenario_path seed)
;;

let branch_domain
      (module D : Ananke_runtime.Domain.S)
      seed
      prefix_path
      baseline_path
      alternate_path
  =
  let module Br = Branch.Make (D) in
  let module Rep = Replay.Make (D) in
  let load_cmds path =
    match load_scenario_commands path with
    | Error error -> fail_error error
    | Ok sexps ->
      (match Rep.commands_of_sexps sexps with
       | Error error -> fail_error error
       | Ok cmds -> cmds)
  in
  let prefix = load_cmds prefix_path in
  let baseline_suffix = load_cmds baseline_path in
  let alternate_suffix = load_cmds alternate_path in
  let config = config ?seed () in
  match Br.fork config ~prefix ~baseline_suffix ~alternate_suffix with
  | Error error -> fail_error error
  | Ok branch ->
    if Branch.diverged branch
    then (
      printf "branch diverged\n";
      printf "%s\n" (Diff.to_string branch.state_diff))
    else printf "branch identical (no state diff)\n"
;;

let branch domain seed prefix_path baseline_path alternate_path =
  Domain_registry.with_domain domain ~f:(fun packed ->
    branch_domain packed seed prefix_path baseline_path alternate_path)
;;

let domain_arg =
  Arg.(
    required
    & opt (some string) None
    & info
        [ "d"; "domain" ]
        ~docv:"NAME"
        ~doc:("domain name (" ^ Domain_registry.names_doc ^ ")"))
;;

let seed_arg =
  Arg.(value & opt (some int) None & info [ "seed" ] ~docv:"INT" ~doc:"rng seed")
;;

let positional_trace =
  Arg.(required & pos 0 (some string) None & info [] ~docv:"TRACE" ~doc:"trace sexp file")
;;

let trace_option =
  Arg.(
    required
    & opt (some string) None
    & info [ "t"; "trace" ] ~docv:"PATH" ~doc:"trace sexp file")
;;

let run_term =
  let scenario =
    Arg.(
      required
      & pos 0 (some string) None
      & info [] ~docv:"SCENARIO" ~doc:"scenario sexp file")
  in
  let output =
    Arg.(
      value
      & opt (some string) None
      & info [ "o"; "output" ] ~docv:"PATH" ~doc:"trace output path")
  in
  Term.(const run $ domain_arg $ scenario $ seed_arg $ output)
;;

let replay_term = Term.(const replay $ positional_trace)

let diff_term =
  let left = Arg.(required & pos 0 (some string) None & info [] ~docv:"LEFT") in
  let right = Arg.(required & pos 1 (some string) None & info [] ~docv:"RIGHT") in
  Term.(const diff $ left $ right)
;;

let verify_term = Term.(const verify $ positional_trace)
let trace_display_term = Term.(const trace_cmd $ positional_trace)
let inspect_term = Term.(const inspect $ positional_trace)
let doctor_term = Term.(const doctor $ const ())

let snapshot_term =
  let at_index =
    Arg.(
      required
      & opt (some int) None
      & info [ "at-index" ] ~docv:"INT" ~doc:"event index to extract")
  in
  let out =
    Arg.(
      required
      & opt (some string) None
      & info [ "o"; "out" ] ~docv:"PATH" ~doc:"snapshot output path")
  in
  Term.(const snapshot $ trace_option $ at_index $ out)
;;

let report_term =
  let format =
    Arg.(
      value
      & opt string "text"
      & info [ "format" ] ~docv:"FMT" ~doc:"output format: text or sexp")
  in
  Term.(const report $ trace_option $ format)
;;

let benchmark_term =
  let iterations =
    Arg.(
      value
      & opt int 1000
      & info [ "iterations" ] ~docv:"INT" ~doc:"number of benchmark iterations")
  in
  let domain =
    Arg.(
      value
      & opt string "elevator"
      & info [ "domain" ] ~docv:"NAME" ~doc:"domain to benchmark: elevator or ledger")
  in
  Term.(const benchmark $ iterations $ domain)
;;

let init_term =
  let name =
    Arg.(
      required
      & opt (some string) None
      & info [ "name" ] ~docv:"STRING" ~doc:"domain name")
  in
  let output_dir =
    Arg.(
      required
      & opt (some string) None
      & info [ "output-dir" ] ~docv:"PATH" ~doc:"parent directory for the new domain")
  in
  Term.(const init_domain $ name $ output_dir)
;;

let checkpoint_term =
  let at_index =
    Arg.(
      required
      & opt (some int) None
      & info [ "at-index" ] ~docv:"INT" ~doc:"event index of the checkpoint snapshot")
  in
  Term.(const checkpoint $ trace_option $ at_index)
;;

let minimize_term =
  let scenario =
    Arg.(
      required
      & pos 0 (some string) None
      & info [] ~docv:"SCENARIO" ~doc:"scenario sexp file to minimize")
  in
  Term.(const minimize $ domain_arg $ scenario $ seed_arg)
;;

let branch_term =
  let prefix =
    Arg.(
      required
      & opt (some string) None
      & info [ "prefix" ] ~docv:"SCENARIO" ~doc:"shared prefix scenario")
  in
  let baseline =
    Arg.(
      required
      & opt (some string) None
      & info [ "baseline" ] ~docv:"SCENARIO" ~doc:"baseline suffix scenario")
  in
  let alternate =
    Arg.(
      required
      & opt (some string) None
      & info [ "alternate" ] ~docv:"SCENARIO" ~doc:"alternate suffix scenario")
  in
  Term.(const branch $ domain_arg $ seed_arg $ prefix $ baseline $ alternate)
;;

let subcommand name doc term = Cmd.v (Cmd.info name ~doc) term

let cmd =
  let run_cmd = subcommand "run" "Run a scenario against a domain." run_term in
  let replay_cmd =
    subcommand "replay" "Replay a trace and verify event stream." replay_term
  in
  let diff_cmd = subcommand "diff" "Diff two snapshots or traces." diff_term in
  let verify_cmd =
    subcommand "verify" "Verify trace determinism by replay." verify_term
  in
  let trace_cmd = subcommand "trace" "Print trace events." trace_display_term in
  let inspect_cmd = subcommand "inspect" "Inspect trace metadata." inspect_term in
  let snapshot_cmd =
    subcommand "snapshot" "Extract snapshot at event index from trace." snapshot_term
  in
  let checkpoint_cmd =
    subcommand
      "checkpoint"
      "Restore a snapshot and verify the post-checkpoint suffix."
      checkpoint_term
  in
  let branch_cmd =
    subcommand
      "branch"
      "Fork from a prefix and diff baseline vs alternate suffixes."
      branch_term
  in
  let minimize_cmd =
    subcommand
      "minimize"
      "Shrink a failing scenario to a minimal command sequence."
      minimize_term
  in
  let report_cmd =
    subcommand "report" "Summarize trace metrics and violations." report_term
  in
  let benchmark_cmd =
    subcommand "benchmark" "Run built-in domain benchmark." benchmark_term
  in
  let init_cmd = subcommand "init" "Scaffold a new domain directory." init_term in
  let doctor_cmd = subcommand "doctor" "Check installation health." doctor_term in
  Cmd.group
    (Cmd.info "ananke" ~version:"0.1.0" ~doc:"Deterministic event-systems laboratory.")
    [ run_cmd
    ; replay_cmd
    ; diff_cmd
    ; verify_cmd
    ; trace_cmd
    ; inspect_cmd
    ; snapshot_cmd
    ; checkpoint_cmd
    ; branch_cmd
    ; minimize_cmd
    ; report_cmd
    ; benchmark_cmd
    ; init_cmd
    ; doctor_cmd
    ]
;;
