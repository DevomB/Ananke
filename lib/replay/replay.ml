(* Alias before [open Base] — Base.Domain (OCaml 5) would otherwise shadow. *)
module Domain_ = Domain
open Base

module Make (D : Domain_.S) = struct
  module R = Runtime.Make (D)

  let command_of_sexp sexp =
    try Ok (D.command_of_sexp sexp) with
    | Sexp.Of_sexp_error (exn, _) -> Error (Ananke_error.Parse_error (Exn.to_string exn))
    | exn -> Error (Ananke_error.Parse_error (Exn.to_string exn))
  ;;

  let commands_of_sexps sexps =
    List.fold sexps ~init:(Ok []) ~f:(fun acc sexp ->
      match acc with
      | Error _ -> acc
      | Ok commands ->
        (match command_of_sexp sexp with
         | Error _ as error -> error
         | Ok command -> Ok (command :: commands)))
    |> function
    | Error _ as error -> error
    | Ok commands -> Ok (List.rev commands)
  ;;

  let commands_of_trace (trace : Trace.t) =
    let sexps =
      List.filter_map trace.events ~f:(function
        | Event.Command command -> Some command.payload
        | _ -> None)
    in
    commands_of_sexps sexps
  ;;

  let replay (trace : Trace.t) config =
    match commands_of_trace trace with
    | Error _ as err -> err
    | Ok commands ->
      let runtime = R.create config in
      (match R.run runtime commands with
       | Error _ as err -> err
       | Ok result -> Ok result.trace)
  ;;

  let final_states (original : Trace.t) (replayed : Trace.t) =
    original.final_state, replayed.final_state
  ;;

  let diverge ~index ~expected ~actual ~message (original : Trace.t) (replayed : Trace.t) =
    let expected_state, actual_state = final_states original replayed in
    Divergence.create ~index ~expected ~actual ~message ?expected_state ?actual_state ()
  ;;

  let verify (original : Trace.t) (replayed : Trace.t) =
    let original_events = original.events in
    let replayed_events = replayed.events in
    let rec compare_events index expected_events actual_events =
      match expected_events, actual_events with
      | [], [] ->
        (match original.final_state, replayed.final_state with
         | Some expected_state, Some actual_state
           when not (Sexp.equal expected_state actual_state) ->
           Error
             (Divergence.create
                ~index:(Event_index.of_int index)
                ~expected:(Event.System Snapshot_taken)
                ~actual:(Event.System Snapshot_taken)
                ~message:"final state mismatch"
                ~expected_state
                ~actual_state
                ())
         | _ -> Ok ())
      | expected :: expected_rest, actual :: actual_rest ->
        if Event.equal expected actual
        then compare_events (index + 1) expected_rest actual_rest
        else
          Error
            (diverge
               ~index:(Event_index.of_int index)
               ~expected
               ~actual
               ~message:"event mismatch at replay"
               original
               replayed)
      | [], actual :: _ ->
        Error
          (diverge
             ~index:(Event_index.of_int index)
             ~expected:(Event.Emitted (Sexp.Atom "<end-of-trace>"))
             ~actual
             ~message:"replay produced an extra event"
             original
             replayed)
      | expected :: _, [] ->
        Error
          (diverge
             ~index:(Event_index.of_int index)
             ~expected
             ~actual:(Event.Emitted (Sexp.Atom "<end-of-trace>"))
             ~message:"replay ended before the expected event"
             original
             replayed)
    in
    compare_events 0 original_events replayed_events
  ;;

  let suffix_start (trace : Trace.t) (snapshot : Snapshot.t) =
    let i = Event_index.to_int snapshot.at_index in
    let count = Trace.event_count trace in
    (* [at_index] is the last consumed event, or [count] for a past-the-end cursor
       (e.g. branch snapshots taken after a prefix with no further events). *)
    if i >= count then count else i + 1
  ;;

  let commands_after (trace : Trace.t) at_index =
    let start = Event_index.to_int at_index in
    let suffix_events = List.drop trace.events start in
    commands_of_trace { trace with events = suffix_events }
  ;;

  let replay_from_checkpoint (original : Trace.t) (snapshot : Snapshot.t) config =
    let start = suffix_start original snapshot in
    match commands_after original (Event_index.of_int start) with
    | Error _ as err -> err
    | Ok commands ->
      (match R.restore config snapshot with
       | Error _ as err -> err
       | Ok runtime ->
         (match R.run runtime commands with
          | Error _ as err -> err
          | Ok result -> Ok result.trace))
  ;;

  let verify_same_result (original : Trace.t) (suffix_replayed : Trace.t) snapshot =
    let start = suffix_start original snapshot in
    let expected_events = List.drop original.events start in
    let expected =
      { original with
        events = expected_events
      ; snapshots = []
      ; metadata = { original.metadata with event_count = List.length expected_events }
      }
    in
    verify expected suffix_replayed
  ;;

  let check_from_checkpoint original snapshot config =
    match replay_from_checkpoint original snapshot config with
    | Error _ as err -> err
    | Ok suffix ->
      (match verify_same_result original suffix snapshot with
       | Ok () -> Ok ()
       | Error divergence ->
         Error (Ananke_error.Replay_divergence (Divergence.to_string divergence)))
  ;;
end
