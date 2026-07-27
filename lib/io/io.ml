open Base

let read_sexp path =
  try Ok (Sexp.load_sexp path) with
  | Sys_error msg -> Error (Ananke_error.Io_error msg)
  | exn -> Error (Ananke_error.Io_error (Exn.to_string exn))
;;

let write_sexp path sexp =
  try
    Sexp.save_hum sexp path;
    Ok ()
  with
  | Sys_error msg -> Error (Ananke_error.Io_error msg)
  | exn -> Error (Ananke_error.Io_error (Exn.to_string exn))
;;

let read_trace path =
  match read_sexp path with
  | Error _ as err -> err
  | Ok sexp -> (
      try Ok (Trace.t_of_sexp sexp) with
      | exn -> Error (Ananke_error.Parse_error (Exn.to_string exn)))
;;

let write_trace path trace =
  write_sexp path ([%sexp_of: Trace.t] trace)

let read_snapshot path =
  match read_sexp path with
  | Error _ as err -> err
  | Ok sexp -> (
      try Ok (Snapshot.t_of_sexp sexp) with
      | exn -> Error (Ananke_error.Parse_error (Exn.to_string exn)))
;;

let write_snapshot path snapshot =
  write_sexp path ([%sexp_of: Snapshot.t] snapshot)
