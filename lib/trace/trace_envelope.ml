open Base

type t =
  { version : Trace_version.t
  ; trace : Trace.t
  }
[@@deriving sexp, compare, equal]

type compatibility =
  | Compatible
  | Needs_migration of
      { from : Trace_version.t
      ; toward : Trace_version.t
      }
  | Incompatible of
      { found : Trace_version.t
      ; reason : string
      }
[@@deriving sexp, compare, equal]

let wrap trace = { version = Trace_version.current; trace }

let check version =
  if Int.equal version Trace_version.current
  then Compatible
  else if version > Trace_version.current
  then
    Incompatible
      { found = version
      ; reason =
          Printf.sprintf
            "trace version %d is newer than supported %d"
            version
            Trace_version.current
      }
  else if version < Trace_version.min_supported
  then
    Incompatible
      { found = version
      ; reason =
          Printf.sprintf
            "trace version %d is below minimum supported %d"
            version
            Trace_version.min_supported
      }
  else Needs_migration { from = version; toward = Trace_version.current }
;;

(* v0 bare Trace.t and v1 envelope payload share the same shape. *)
let migrate_step version trace =
  match version with
  | 0 -> Ok (1, trace)
  | n when Int.equal n Trace_version.current -> Ok (n, trace)
  | n when n > Trace_version.current ->
    Error
      (Ananke_error.Incompatible_version
         (Printf.sprintf
            "cannot migrate forward from future version %d (current %d)"
            n
            Trace_version.current))
  | n ->
    Error
      (Ananke_error.Incompatible_version
         (Printf.sprintf "no migration defined from version %d" n))
;;

let rec migrate ~from trace =
  match check from with
  | Compatible -> Ok trace
  | Incompatible { reason; _ } -> Error (Ananke_error.Incompatible_version reason)
  | Needs_migration { from; _ } ->
    (match migrate_step from trace with
     | Error _ as err -> err
     | Ok (next, trace) ->
       if next <= from
       then
         Error
           (Ananke_error.Incompatible_version
              (Printf.sprintf "migration from %d did not advance (got %d)" from next))
       else migrate ~from:next trace)
;;

let version_field_of_sexp_fields fields =
  List.find_map fields ~f:(function
    | Sexp.List [ Atom "version"; value ] -> Some (Trace_version.t_of_sexp value)
    | _ -> None)
;;

let of_wire_sexp sexp =
  match sexp with
  | Sexp.List fields ->
    (match version_field_of_sexp_fields fields with
     | None ->
       (try
          let trace = Trace.t_of_sexp sexp in
          migrate ~from:0 trace
        with
        | exn -> Error (Ananke_error.Parse_error (Exn.to_string exn)))
     | Some version ->
       (match check version with
        | Incompatible { reason; _ } -> Error (Ananke_error.Incompatible_version reason)
        | Compatible | Needs_migration _ ->
          (try
             let envelope = t_of_sexp sexp in
             if not (Int.equal envelope.version version)
             then Error (Ananke_error.Parse_error "envelope version field mismatch")
             else migrate ~from:envelope.version envelope.trace
           with
           | exn -> Error (Ananke_error.Parse_error (Exn.to_string exn)))))
  | Sexp.Atom _ ->
    Error (Ananke_error.Parse_error "expected list sexp for trace envelope")
;;

let to_wire_sexp trace = [%sexp_of: t] (wrap trace)

let sample_metadata =
  Run_metadata.create
    ~domain:"elevator"
    ~domain_version:1
    ~rng_seed:1
    ~started_at:Logical_time.zero
    ~command_count:0
    ~event_count:0
;;

let%test "current version is compatible" =
  match check Trace_version.current with
  | Compatible -> true
  | _ -> false
;;

let%test "legacy version needs migration" =
  match check 0 with
  | Needs_migration { from = 0; toward } -> Int.equal toward Trace_version.current
  | _ -> false
;;

let%test "future version is incompatible" =
  match check (Trace_version.current + 1) with
  | Incompatible _ -> true
  | _ -> false
;;

let%test "wire roundtrip preserves trace" =
  let trace = Trace.empty sample_metadata |> Trace.seal in
  match of_wire_sexp (to_wire_sexp trace) with
  | Ok loaded -> Trace.equal loaded trace
  | Error _ -> false
;;

let%test "legacy bare sexp migrates" =
  let trace = Trace.empty sample_metadata |> Trace.seal in
  let bare = [%sexp_of: Trace.t] trace in
  match of_wire_sexp bare with
  | Ok loaded -> Trace.equal loaded trace
  | Error _ -> false
;;

let%expect_test "envelope serializes with version" =
  let trace = Trace.empty sample_metadata |> Trace.seal in
  Stdlib.print_endline (Sexp.to_string_hum (to_wire_sexp trace));
  [%expect
    {|
    ((version 1)
     (trace
      ((metadata
        ((domain elevator) (domain_version 1) (rng_seed 1) (started_at 0)
         (command_count 0) (event_count 0)))
       (events ()) (final_state ()) (snapshots ()) (sealed true))))
    |}]
;;
