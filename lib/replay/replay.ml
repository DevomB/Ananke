open Base

module Make (D : Domain.S) = struct
  module R = Runtime.Make (D)

  let commands_of_trace trace =
    let parse_command sexp =
      try Ok (D.command_of_sexp sexp) with
      | Sexp.Of_sexp_error (exn, _) ->
          Error (Ananke_error.Parse_error (Exn.to_string exn))
      | exn -> Error (Ananke_error.Parse_error (Exn.to_string exn))
    in
    List.fold trace.events ~init:(Ok []) ~f:(fun acc event ->
        match acc with
        | Error _ -> acc
        | Ok cmds -> (
            match event with
            | Event.Command cmd -> (
                match parse_command cmd.payload with
                | Error _ as err -> err
                | Ok cmd -> Ok (cmd :: cmds))
            | _ -> Ok cmds))
    |> function
    | Error _ as err -> err
    | Ok cmds -> Ok (List.rev cmds)
  ;;

  let replay trace config =
    match commands_of_trace trace with
    | Error _ as err -> err
    | Ok commands ->
        let runtime = R.create config in
        (match R.run runtime commands with
         | Error _ as err -> err
         | Ok result -> Ok result.trace)
  ;;

  let verify original replayed =
    let original_events = original.events in
    let replayed_events = replayed.events in
    if List.length original_events <> List.length replayed_events then (
      let expected =
        List.hd original_events
        |> Option.value ~default:(Event.System Clock_advanced)
      in
      let actual =
        List.hd replayed_events
        |> Option.value ~default:(Event.System Clock_advanced)
      in
      Error
        { Divergence.index = Event_index.zero
        ; expected
        ; actual
        ; message =
            sprintf "event count mismatch: expected %d got %d"
              (List.length original_events)
              (List.length replayed_events)
        })
    else
      List.foldi original_events ~init:(Ok ()) ~f:(fun i acc expected ->
          match acc with
          | Error _ -> acc
          | Ok () -> (
              match List.nth replayed_events i with
              | None -> Ok ()
              | Some actual ->
                  if Event.equal expected actual then Ok ()
                  else
                    Error
                      { Divergence.index = Event_index.of_int i
                      ; expected
                      ; actual
                      ; message = "event mismatch at replay"
                      }))
  ;;
end
