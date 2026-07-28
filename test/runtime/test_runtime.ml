open Base
module E = Ananke_elevator.Domain
module R = Runtime.Make (E)

let%test "elevator accepts floor request" =
  let rt = R.create Config.default in
  match R.step rt (E.Request_floor 3) with
  | Error _ -> false
  | Ok result -> List.mem result.state.requests 3 ~equal:Int.equal
;;

let%test "elevator step moves toward request" =
  match R.create Config.default |> fun rt -> R.run rt [ E.Request_floor 2; E.Step ] with
  | Error _ -> false
  | Ok result -> Int.equal result.state.floor 1
;;

let%test "run preserves command ids and logical time" =
  match R.create Config.default |> fun rt -> R.run rt [ E.Request_floor 2; E.Step ] with
  | Error _ -> false
  | Ok result ->
    let commands =
      List.filter_map result.trace.events ~f:(function
        | Event.Command command -> Some command
        | Event.Emitted _ | Event.System _ -> None)
    in
    (match commands with
     | [ first; second ] ->
       Command_id.equal first.id (Command_id.fresh 0)
       && Logical_time.equal first.at Logical_time.zero
       && Command_id.equal second.id (Command_id.fresh 1)
       && Logical_time.equal second.at (Logical_time.of_int64 1L)
     | _ -> false)
;;
