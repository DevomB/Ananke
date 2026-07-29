(* Alias before [open Base] — Base.Domain (OCaml 5) would otherwise shadow. *)
module Domain_ = Domain
open Base

type t =
  { snapshot : Snapshot.t
  ; baseline : Trace.t
  ; alternate : Trace.t
  ; state_diff : Diff.t
  }
[@@deriving sexp, compare, equal]

let diverged t = not (Diff.is_empty t.state_diff)

module Make (D : Domain_.S) = struct
  module R = Runtime.Make (D)

  let state_sexp (snap : Snapshot.t) (trace : Trace.t) =
    match trace.final_state with
    | Some state -> state
    | None -> snap.state
  ;;

  let run_suffix config snap suffix =
    match R.restore config snap with
    | Error _ as err -> err
    | Ok runtime -> R.run runtime suffix
  ;;

  let fork_from_snapshot config snap ~baseline_suffix ~alternate_suffix =
    match run_suffix config snap baseline_suffix with
    | Error _ as err -> err
    | Ok baseline_result ->
      (match run_suffix config snap alternate_suffix with
       | Error _ as err -> err
       | Ok alternate_result ->
         let left = state_sexp snap baseline_result.trace in
         let right = state_sexp snap alternate_result.trace in
         Ok
           { snapshot = snap
           ; baseline = baseline_result.trace
           ; alternate = alternate_result.trace
           ; state_diff = Diff.diff left right
           })
  ;;

  let snapshot_after_prefix (result : D.state Transition_result.t) =
    Snapshot.create
      Snapshot_version.current
      (Logical_time.of_int64 (Int64.of_int result.trace.metadata.command_count))
      (Event_index.of_int (Trace.event_count result.trace))
      ~state:([%sexp_of: D.state] result.state)
      ~rng:([%sexp_of: Rng.t] result.rng)
  ;;

  let fork config ~prefix ~baseline_suffix ~alternate_suffix =
    match R.create config |> fun runtime -> R.run runtime prefix with
    | Error _ as err -> err
    | Ok prefix_result ->
      let snap = snapshot_after_prefix prefix_result in
      fork_from_snapshot config snap ~baseline_suffix ~alternate_suffix
  ;;
end
