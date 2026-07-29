(* Alias before [open Base] — Base.Domain (OCaml 5) would otherwise shadow. *)
module Domain_ = Domain
open Base

module Make (D : Domain_.S) = struct
  type t =
    { config : Config.t
    ; state : D.state
    ; rng : Rng.t
    ; trace : Trace.t
    ; metrics : Metrics.t
    ; clock : Logical_time.t
    ; event_index : Event_index.t
    ; command_counter : int
    ; violations : Violation.t list
    }

  let metadata (config : Config.t) =
    Run_metadata.create
      ~domain:D.name
      ~domain_version:D.version
      ~rng_seed:config.rng_seed
      ~started_at:Logical_time.zero
      ~command_count:0
      ~event_count:0
  ;;

  let create config =
    let trace = Trace.empty (metadata config) in
    { config
    ; state = D.initial_state
    ; rng = Rng.create config.rng_seed
    ; trace
    ; metrics = Metrics.empty
    ; clock = Logical_time.zero
    ; event_index = Event_index.zero
    ; command_counter = 0
    ; violations = []
    }
  ;;

  let state t = t.state
  let rng t = t.rng
  let trace t = t.trace
  let metrics t = t.metrics
  let clock t = t.clock
  let event_index t = t.event_index

  let snapshot t =
    Snapshot.create
      Snapshot_version.current
      t.clock
      t.event_index
      ~state:([%sexp_of: D.state] t.state)
      ~rng:([%sexp_of: Rng.t] t.rng)
  ;;

  let restore config (snap : Snapshot.t) =
    if not (Snapshot_version.equal snap.version Snapshot_version.current)
    then
      Error
        (Ananke_error.Parse_error
           (Printf.sprintf
              "unsupported snapshot version %d (want %d)"
              snap.version
              Snapshot_version.current))
    else if
      not
        (String.equal
           snap.digest
           (Snapshot.digest_of_capture ~state:snap.state ~rng:snap.rng))
    then Error (Ananke_error.Parse_error "snapshot digest mismatch")
    else (
      match
        try Ok (D.state_of_sexp snap.state) with
        | exn -> Error (Ananke_error.Parse_error (Exn.to_string exn))
      with
      | Error _ as err -> err
      | Ok state ->
        (match
           try Ok (Rng.t_of_sexp snap.rng) with
           | exn -> Error (Ananke_error.Parse_error (Exn.to_string exn))
         with
         | Error _ as err -> err
         | Ok rng ->
           (* Clock equals completed command count; keep Command_id sequence continuous. *)
           let command_counter = snap.at |> Logical_time.to_int64 |> Int64.to_int_exn in
           let t = create config in
           Ok
             { t with
               state
             ; rng
             ; clock = snap.at
             ; event_index = snap.at_index
             ; command_counter
             }))
  ;;

  let check_invariants (config : Config.t) state =
    let outcomes = Check.evaluate_named state D.invariants in
    let violations = Check.violations_of_outcomes outcomes in
    match config.invariant_mode, violations with
    | Stop, v :: _ -> Error (Ananke_error.Invariant_violation (Violation.to_string v))
    | Stop, [] | Record, _ | Warn, _ -> Ok (outcomes, violations)
  ;;

  let record_event t event =
    let trace =
      if t.config.trace_enabled then Trace.add_event event t.trace else t.trace
    in
    let metrics = Metrics.record_event t.metrics in
    let event_index = Event_index.succ t.event_index in
    { t with trace; metrics; event_index }
  ;;

  let maybe_snapshot t =
    if not t.config.snapshot_each_command
    then t
    else (
      let snapshot = snapshot t in
      let trace = Trace.add_snapshot snapshot t.trace in
      let metrics = Metrics.record_snapshot t.metrics in
      record_event { t with trace; metrics } (Event.System Snapshot_taken))
  ;;

  let step_internal t command =
    let id = Command_id.fresh t.command_counter in
    let command_counter = t.command_counter + 1 in
    let cmd_record = Command.create id t.clock ([%sexp_of: D.command] command) in
    let t = record_event { t with command_counter } (Event.Command cmd_record) in
    let metrics = Metrics.record_command t.metrics in
    let t = { t with metrics } in
    match D.transition t.state t.rng command with
    | Error err -> Error err
    | Ok (new_state, emitted_events, rng) ->
      let t = { t with state = new_state; rng } in
      let t =
        List.fold emitted_events ~init:t ~f:(fun acc ev ->
          record_event acc (Event.Emitted ([%sexp_of: D.event] ev)))
      in
      let metrics = Metrics.record_invariant_check t.metrics in
      let t = { t with metrics } in
      (match check_invariants t.config t.state with
       | Error err -> Error err
       | Ok (outcomes, violations) ->
         let t = record_event t (Event.System (Invariant_checked outcomes)) in
         let t =
           { t with
             violations = List.rev_append violations t.violations
           ; clock = Logical_time.succ t.clock
           }
         in
         let t = record_event t (Event.System Clock_advanced) in
         let t = maybe_snapshot t in
         let trace =
           let metadata : Run_metadata.t =
             { t.trace.metadata with
               command_count = t.command_counter
             ; event_count = Trace.event_count t.trace
             }
           in
           { t.trace with metadata }
         in
         let trace = Trace.set_final_state ([%sexp_of: D.state] t.state) trace in
         let t = { t with trace } in
         Ok (t, List.map emitted_events ~f:[%sexp_of: D.event]))
  ;;

  let to_result t emitted =
    { Transition_result.state = t.state
    ; emitted
    ; trace = Trace.seal t.trace
    ; metrics = t.metrics
    ; violations = List.rev t.violations
    ; rng = t.rng
    }
  ;;

  let step t command =
    match step_internal t command with
    | Error _ as error -> error
    | Ok (t, emitted) -> Ok (to_result t emitted)
  ;;

  let run t commands =
    let rec loop t emitted = function
      | [] ->
        (* wall_time_ns is reserved for a future runtime timing hook. *)
        let metrics = Metrics.set_wall_time_ns 0L t.metrics in
        Ok (to_result { t with metrics } (List.rev emitted))
      | cmd :: rest ->
        (match step_internal t cmd with
         | Error _ as err -> err
         | Ok (t, step_emitted) -> loop t (List.rev_append step_emitted emitted) rest)
    in
    loop t [] commands
  ;;
end
