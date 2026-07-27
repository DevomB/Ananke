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
