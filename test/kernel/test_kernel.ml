open Base

let%test "command round trip" =
  let cmd = Command.create (Command_id.fresh 1) Logical_time.zero (Sexp.Atom "ping") in
  let sexp = [%sexp_of: Command.t] cmd in
  let cmd' = Command.t_of_sexp sexp in
  Command.equal cmd cmd'
;;

let%test "event ordering is stable" =
  let e1 = Event.System Clock_advanced in
  let e2 = Event.System (Invariant_checked []) in
  Int.(Event.compare e1 e2 > 0)
;;

let%test "invariant outcome event round trips" =
  let e =
    Event.System
      (Invariant_checked
         [ Passed { name = "ok-check" }
         ; Violated { name = "bad-check"; message = "broke" }
         ])
  in
  Event.equal e (Event.t_of_sexp ([%sexp_of: Event.t] e))
;;

let%test "invariant outcomes extract from events" =
  let events =
    [ Event.System
        (Invariant_checked
           [ Passed { name = "a" }; Violated { name = "b"; message = "x" } ])
    ; Event.System Clock_advanced
    ]
  in
  match Event.invariant_violations events with
  | [ Event.Violated { name = "b"; message = "x" } ] -> true
  | _ -> false
;;

let%test "rng create is pure given seed" =
  let _, a = Rng.int (Rng.create 5) ~exclusive_upper_bound:100 in
  let _, b = Rng.int (Rng.create 5) ~exclusive_upper_bound:100 in
  Int.equal a b
;;
