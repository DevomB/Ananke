open Base
module E = Ananke_elevator.Domain
module R = Runtime.Make (E)
module Rep = Replay.Make (E)

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
       && String.equal divergence.message "replay ended before the expected event")
;;
