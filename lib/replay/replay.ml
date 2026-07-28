open Base

module Make (D : Domain.S) = struct
  module R = Runtime.Make (D)

  let commands_of_trace (trace : Trace.t) =
    let parse_command sexp =
      try Ok (D.command_of_sexp sexp) with
      | Sexp.Of_sexp_error (exn, _) ->
        Error (Ananke_error.Parse_error (Exn.to_string exn))
      | exn -> Error (Ananke_error.Parse_error (Exn.to_string exn))
    in
    List.fold trace.events ~init:(Ok []) ~f:(fun acc event ->
      match acc with
      | Error _ -> acc
      | Ok cmds ->
        (match event with
         | Event.Command cmd ->
           (match parse_command cmd.payload with
            | Error _ as err -> err
            | Ok cmd -> Ok (cmd :: cmds))
         | _ -> Ok cmds))
    |> function
    | Error _ as err -> err
    | Ok cmds -> Ok (List.rev cmds)
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

  let verify (original : Trace.t) (replayed : Trace.t) =
    let original_events = original.events in
    let replayed_events = replayed.events in
    let rec compare_events index expected_events actual_events =
      match expected_events, actual_events with
      | [], [] -> Ok ()
      | expected :: expected_rest, actual :: actual_rest ->
        if Event.equal expected actual
        then compare_events (index + 1) expected_rest actual_rest
        else
          Error
            { Divergence.index = Event_index.of_int index
            ; expected
            ; actual
            ; message = "event mismatch at replay"
            }
      | [], actual :: _ ->
        Error
          { Divergence.index = Event_index.of_int index
          ; expected = Event.System Clock_advanced
          ; actual
          ; message = "replay produced an extra event"
          }
      | expected :: _, [] ->
        Error
          { Divergence.index = Event_index.of_int index
          ; expected
          ; actual = Event.System Clock_advanced
          ; message = "replay ended before the expected event"
          }
    in
    compare_events 0 original_events replayed_events
  ;;
end
