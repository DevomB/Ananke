open Base

type t =
  { index : Event_index.t
  ; expected : Event.t
  ; actual : Event.t
  ; message : string
  ; event_diff : Diff.t
  ; state_diff : Diff.t option
  }
[@@deriving sexp, compare, equal]

let state_diff_of ?expected_state ?actual_state () =
  match expected_state, actual_state with
  | Some left, Some right ->
    let changes = Diff.diff left right in
    if Diff.is_empty changes then None else Some changes
  | _ -> None
;;

let create ~index ~expected ~actual ~message ?expected_state ?actual_state () =
  { index
  ; expected
  ; actual
  ; message
  ; event_diff = Diff.diff (Event.sexp_of_t expected) (Event.sexp_of_t actual)
  ; state_diff = state_diff_of ?expected_state ?actual_state ()
  }
;;

let to_string d =
  let base =
    Printf.sprintf "divergence at index %d: %s" (Event_index.to_int d.index) d.message
  in
  let event_part =
    if Diff.is_empty d.event_diff
    then ""
    else Printf.sprintf "\nevent diff:\n%s" (Diff.to_string d.event_diff)
  in
  let state_part =
    match d.state_diff with
    | None -> ""
    | Some changes -> Printf.sprintf "\nstate diff:\n%s" (Diff.to_string changes)
  in
  base ^ event_part ^ state_part
;;

let%expect_test "to_string includes structural event diff" =
  let expected = Event.Emitted (Sexp.List [ Sexp.Atom "Arrived_at"; Sexp.Atom "1" ]) in
  let actual = Event.Emitted (Sexp.List [ Sexp.Atom "Arrived_at"; Sexp.Atom "2" ]) in
  let d =
    create
      ~index:(Event_index.of_int 3)
      ~expected
      ~actual
      ~message:"event mismatch at replay"
      ()
  in
  Stdlib.print_endline (to_string d);
  [%expect
    {|
    divergence at index 3: event mismatch at replay
    event diff:
    changed 1.1: 1 -> 2
    |}]
;;

let%expect_test "to_string includes structural state diff" =
  let expected_state =
    Sexplib.Sexp.of_string "((floor 1) (direction Idle) (requests ()))"
  in
  let actual_state =
    Sexplib.Sexp.of_string "((floor 2) (direction Idle) (requests ()))"
  in
  let d =
    create
      ~index:(Event_index.of_int 4)
      ~expected:(Event.System Snapshot_taken)
      ~actual:(Event.System Snapshot_taken)
      ~message:"final state mismatch"
      ~expected_state
      ~actual_state
      ()
  in
  Stdlib.print_endline (to_string d);
  [%expect
    {|
    divergence at index 4: final state mismatch
    state diff:
    changed 0.1: 1 -> 2
    |}]
;;
