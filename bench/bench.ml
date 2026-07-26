open Base

module E = Chronicle_elevator.Domain
module R = Runtime.Make (E)

let commands =
  List.init 100 ~f:(fun i ->
      if i mod 2 = 0 then E.Request_floor (i mod 8) else E.Step)
;;

let () =
  let rt = R.create Config.default in
  match R.run rt commands with
  | Ok result ->
      printf "bench: processed %d commands, %d events\n"
        result.metrics.commands_processed result.metrics.events_recorded
  | Error err -> failwith (Chronicle_error.to_string err)
