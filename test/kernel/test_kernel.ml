open Base

let%test "command round trip" =
  let cmd =
    Command.create (Command_id.fresh 1) Logical_time.zero (Sexp.Atom "ping")
  in
  let sexp = [%sexp_of: Command.t] cmd in
  let cmd' = Command.t_of_sexp sexp in
  Command.equal cmd cmd'
;;

let%test "event ordering is stable" =
  let e1 = Event.System Clock_advanced in
  let e2 = Event.System Invariant_checked in
  Int.equal (Event.compare e1 e2) (compare (e1 : Event.t) (e2 : Event.t))
