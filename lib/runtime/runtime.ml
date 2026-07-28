open Base

module Make (D : Domain.S) = struct
  type t =
    { config : Config.t
    ; state : D.state
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
    ; trace
    ; metrics = Metrics.empty
    ; clock = Logical_time.zero
    ; event_index = Event_index.zero
    ; command_counter = 0
    ; violations = []
    }
  ;;

  let state t = t.state
  let trace t = t.trace
  let metrics t = t.metrics
  let clock t = t.clock
  let event_index t = t.event_index

  let named_invariants =
    List.mapi D.invariants ~f:(fun i checker ->
      let name = Printf.sprintf "invariant-%d" i in
      fun state ->
        match checker state with
        | Ok () -> Ok ()
        | Error v -> Error { v with name })
  ;;

  let check_invariants (config : Config.t) state =
    match Check.run_all state named_invariants with
    | Ok () -> Ok []
    | Error violations ->
      (match config.invariant_mode with
       | Stop ->
         Error
           (Ananke_error.Invariant_violation
              (Violation.to_string (List.hd_exn violations)))
       | Record | Warn -> Ok violations)
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
      let snapshot =
        Snapshot.create
          Snapshot_version.current
          t.clock
          t.event_index
          ([%sexp_of: D.state] t.state)
      in
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
    match D.transition t.state command with
    | Error err -> Error err
    | Ok (new_state, emitted_events) ->
      let t = { t with state = new_state } in
      let t =
        List.fold emitted_events ~init:t ~f:(fun acc ev ->
          record_event acc (Event.Emitted ([%sexp_of: D.event] ev)))
      in
      let metrics = Metrics.record_invariant_check t.metrics in
      let t = { t with metrics } in
      let t = record_event t (Event.System Invariant_checked) in
      (match check_invariants t.config t.state with
       | Error err -> Error err
       | Ok violations ->
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

  let step t command =
    match step_internal t command with
    | Error _ as error -> error
    | Ok (t, emitted) ->
      Ok
        { Transition_result.state = t.state
        ; emitted
        ; trace = Trace.seal t.trace
        ; metrics = t.metrics
        ; violations = List.rev t.violations
        }
  ;;

  let run t commands =
    let rec loop t emitted = function
      | [] ->
        (* wall_time_ns is reserved for a future runtime timing hook. *)
        let metrics = Metrics.set_wall_time_ns 0L t.metrics in
        Ok
          { Transition_result.state = t.state
          ; emitted = List.rev emitted
          ; trace = Trace.seal t.trace
          ; metrics
          ; violations = List.rev t.violations
          }
      | cmd :: rest ->
        (match step_internal t cmd with
         | Error _ as err -> err
         | Ok (t, step_emitted) -> loop t (List.rev_append step_emitted emitted) rest)
    in
    loop t [] commands
  ;;
end
