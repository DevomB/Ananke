open Base

type t =
  | Added of Field_path.t * Sexp.t
  | Removed of Field_path.t * Sexp.t
  | Changed of Field_path.t * Sexp.t * Sexp.t
[@@deriving sexp, compare, equal]

let describe = function
  | Added (path, value) ->
      Printf.sprintf "added %s = %s" (Field_path.to_string path) (Sexp.to_string_hum value)
  | Removed (path, value) ->
      Printf.sprintf "removed %s (was %s)" (Field_path.to_string path) (Sexp.to_string_hum value)
  | Changed (path, old_v, new_v) ->
      Printf.sprintf "changed %s: %s -> %s"
        (Field_path.to_string path)
        (Sexp.to_string_hum old_v)
        (Sexp.to_string_hum new_v)
;;
