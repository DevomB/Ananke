open Base

module E = Ananke_elevator.Domain
module R = Runtime.Make (E)
module Rep = Replay.Make (E)

let%test "replay reproduces trace" =
  let commands = [ E.Request_floor 2; E.Step; E.Step ] in
  let config = Config.default in
  match R.create config |> fun rt -> R.run rt commands with
  | Error _ -> false
  | Ok result -> (
      match Rep.replay result.trace config with
      | Error _ -> false
      | Ok replayed -> (
          match Rep.verify result.trace replayed with
          | Ok () -> true
          | Error _ -> false))
