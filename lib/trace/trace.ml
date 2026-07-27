open Core

type t =
  { metadata : Run_metadata.t
  ; events : Event.t list
  ; final_state : Sexp.t option
  ; snapshots : Snapshot.t list
  ; sealed : bool [@compare.ignore] [@equal.ignore]
  }
[@@deriving sexp, compare, equal]

let empty metadata =
  { metadata; events = []; final_state = None; snapshots = []; sealed = true }
;;

let add_event event t =
  let events = if t.sealed then [ event ] else event :: t.events in
  { t with
    events
  ; sealed = false
  ; metadata = { t.metadata with event_count = t.metadata.event_count + 1 }
  }
;;

let add_snapshot snapshot t =
  let snapshots =
    if t.sealed then [ snapshot ] else snapshot :: t.snapshots
  in
  { t with snapshots; sealed = false }
;;

let seal t =
  if t.sealed then t
  else
    { t with
      events = List.rev t.events
    ; snapshots = List.rev t.snapshots
    ; sealed = true
    }
;;

let set_final_state state t = { t with final_state = Some state }
let timeline t = Timeline.of_events (if t.sealed then t.events else List.rev t.events)
let event_count t = t.metadata.event_count

let%expect_test "trace serializes compactly" =
  let metadata =
    Run_metadata.create ~domain:"elevator" ~domain_version:1 ~rng_seed:42
      ~started_at:Logical_time.zero ~command_count:1 ~event_count:2
  in
  let trace =
    empty metadata
    |> add_event
         (Event.Command
            (Command.create (Command_id.fresh 0) Logical_time.zero
               (Sexp.Atom "Request_floor")))
    |> add_event (Event.Emitted (Sexp.List [ Sexp.Atom "floor_requested"; Sexp.Atom "3" ]))
    |> seal
  in
  print_s [%sexp (trace : t)];
  [%expect {| ((metadata (...)) (events (...)) (final_state ()) (snapshots ())) |}]
;;
