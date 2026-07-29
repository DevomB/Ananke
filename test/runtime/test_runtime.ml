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

let%test "snapshot restore resumes typed domain state" =
  let rt = R.create Config.default in
  match R.run rt [ E.Request_floor 4; E.Step ] with
  | Error _ -> false
  | Ok result ->
    (* Rebuild capture via [state_of_sexp]-compatible sexp payload. *)
    let snap =
      Snapshot.create
        Snapshot_version.current
        (Logical_time.of_int64 2L)
        (Event_index.of_int 0)
        ~state:(E.sexp_of_state result.state)
        ~rng:([%sexp_of: Rng.t] result.rng)
    in
    (match R.restore Config.default snap with
     | Error _ -> false
     | Ok restored ->
       Int.equal (E.compare_state (R.state restored) result.state) 0
       && Rng.equal (R.rng restored) result.rng
       && Logical_time.equal (R.clock restored) snap.at
       && Int.equal (E.compare_state (E.state_of_sexp snap.state) result.state) 0
       &&
         (match R.step restored E.Step with
         | Error _ -> false
         | Ok continued -> Int.equal continued.state.floor 2))
;;

let%test "runtime snapshot round-trips through restore" =
  let rt = R.create Config.default in
  let snap = R.snapshot rt in
  match R.restore Config.default snap with
  | Error _ -> false
  | Ok restored ->
    Int.equal (E.compare_state (R.state restored) E.initial_state) 0
    &&
      (match R.run restored [ E.Request_floor 3; E.Step ] with
      | Error _ -> false
      | Ok continued -> Int.equal continued.state.floor 1)
;;

let%test "snapshot restore rejects digest mismatch" =
  let snap = R.snapshot (R.create Config.default) in
  let bad = { snap with digest = "deadbeef" } in
  match R.restore Config.default bad with
  | Error (Ananke_error.Parse_error _) -> true
  | _ -> false
;;

let%test "trace records passed invariant outcomes" =
  match R.create Config.default |> fun rt -> R.step rt (E.Request_floor 3) with
  | Error _ -> false
  | Ok result ->
    (match Trace.invariant_outcomes result.trace with
     | [ Event.Passed { name = "no_empty_travel" }
       ; Event.Passed { name = "floor_valid" }
       ] -> true
     | _ -> false)
;;

module Neg = struct
  type state = int [@@deriving sexp, compare]
  type command = Dec [@@deriving sexp]
  type event = Unit [@@deriving sexp]

  let name = "neg"
  let version = 1
  let initial_state = 0
  let transition state rng Dec = Ok (state - 1, [ Unit ], rng)

  let invariants =
    [ ( "nonneg"
      , fun state ->
          if state >= 0
          then Ok ()
          else Error { Violation.name = "nonneg"; message = "balance below zero" } )
    ]
  ;;

  let command_of_sexp = command_of_sexp
  let state_of_sexp = state_of_sexp
end

let%test "trace records invariant violations as evidence" =
  let module NR = Runtime.Make (Neg) in
  let config = { Config.default with invariant_mode = Record } in
  match NR.create config |> fun rt -> NR.step rt Neg.Dec with
  | Error _ -> false
  | Ok result ->
    (match Trace.invariant_violations result.trace with
     | [ Event.Violated { name = "nonneg"; message = "balance below zero" } ] ->
       List.length result.violations = 1
     | _ -> false)
;;

(** Stochastic domain that draws only from the explicit [Rng.t]. *)
module Coin = struct
  type state = { heads : int } [@@deriving sexp, compare]
  type command = Flip [@@deriving sexp]

  type event =
    | Heads
    | Tails
  [@@deriving sexp]

  let name = "coin"
  let version = 1
  let initial_state = { heads = 0 }

  let transition state rng Flip =
    let rng, heads = Rng.bool rng in
    if heads
    then Ok ({ heads = state.heads + 1 }, [ Heads ], rng)
    else Ok (state, [ Tails ], rng)
  ;;

  let invariants = []
  let command_of_sexp = command_of_sexp
  let state_of_sexp = state_of_sexp
end

module CR = Runtime.Make (Coin)

let%test "rng domain is deterministic for a fixed seed" =
  let config = { Config.default with rng_seed = 99 } in
  let flips = List.init 8 ~f:(fun _ -> Coin.Flip) in
  match CR.create config |> fun rt -> CR.run rt flips with
  | Error _ -> false
  | Ok first ->
    (match CR.create config |> fun rt -> CR.run rt flips with
     | Error _ -> false
     | Ok second ->
       Int.equal (Coin.compare_state first.state second.state) 0
       && Rng.equal first.rng second.rng
       && Trace.equal first.trace second.trace)
;;

let%test "serialized rng resumes the same stream after checkpoint" =
  let config = { Config.default with rng_seed = 13 } in
  match CR.create config |> fun rt -> CR.run rt [ Coin.Flip; Coin.Flip ] with
  | Error _ -> false
  | Ok midway ->
    let snap =
      Snapshot.create
        Snapshot_version.current
        (Logical_time.of_int64 2L)
        (Event_index.of_int 0)
        ~state:(Coin.sexp_of_state midway.state)
        ~rng:([%sexp_of: Rng.t] midway.rng)
    in
    (match CR.restore config snap with
     | Error _ -> false
     | Ok restored ->
       (match CR.run restored [ Coin.Flip; Coin.Flip ] with
        | Error _ -> false
        | Ok from_snap ->
          (match
             CR.create config
             |> fun rt -> CR.run rt [ Coin.Flip; Coin.Flip; Coin.Flip; Coin.Flip ]
           with
           | Error _ -> false
           | Ok full ->
             Int.equal (Coin.compare_state from_snap.state full.state) 0
             && Rng.equal from_snap.rng full.rng)))
;;
