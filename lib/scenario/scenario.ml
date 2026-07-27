open Core

type t =
  { name : string
  ; domain : string
  ; rng_seed : int
  ; commands : Sexp.t list
  }
[@@deriving sexp, compare, equal]

let load sexp =
  try
    let scenario = t_of_sexp sexp in
    if String.is_empty scenario.domain then
      Error (Ananke_error.Parse_error "scenario domain must not be empty")
    else Ok scenario
  with
  | Sexp.Of_sexp_error (exn, _) ->
      Error (Ananke_error.Parse_error (Exn.to_string exn))
  | exn -> Error (Ananke_error.Parse_error (Exn.to_string exn))
;;

let load_file path =
  try
    let sexp = Sexp.load_sexp path in
    load sexp
  with
  | Sys_error msg -> Error (Ananke_error.Io_error msg)
  | exn -> Error (Ananke_error.Io_error (Exn.to_string exn))
;;

let command_sexps t = t.commands
