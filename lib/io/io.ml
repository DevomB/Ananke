open Base

let read_sexp path =
  try Ok (Sexplib.Sexp.load_sexp path) with
  | Sys_error msg -> Error (Ananke_error.Io_error msg)
  | exn -> Error (Ananke_error.Parse_error (Exn.to_string exn))
;;

let write_sexp path sexp =
  try
    Sexplib.Sexp.save_hum path sexp;
    Ok ()
  with
  | Sys_error msg -> Error (Ananke_error.Io_error msg)
  | exn -> Error (Ananke_error.Io_error (Exn.to_string exn))
;;

let write_text path text =
  try
    let channel = Stdlib.open_out_bin path in
    Exn.protect
      ~f:(fun () -> Stdlib.output_string channel text)
      ~finally:(fun () -> Stdlib.close_out channel);
    Ok ()
  with
  | Sys_error msg -> Error (Ananke_error.Io_error msg)
  | exn -> Error (Ananke_error.Io_error (Exn.to_string exn))
;;

let read_trace path =
  match read_sexp path with
  | Error _ as err -> err
  | Ok sexp -> Trace_envelope.of_wire_sexp sexp
;;

let write_trace path trace = write_sexp path (Trace_envelope.to_wire_sexp trace)

let read_snapshot path =
  match read_sexp path with
  | Error _ as err -> err
  | Ok sexp ->
    (try Ok (Snapshot.t_of_sexp sexp) with
     | exn -> Error (Ananke_error.Parse_error (Exn.to_string exn)))
;;

let write_snapshot path snapshot = write_sexp path ([%sexp_of: Snapshot.t] snapshot)
