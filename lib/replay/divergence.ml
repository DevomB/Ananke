open Base

type t =
  { index : Event_index.t
  ; expected : Event.t
  ; actual : Event.t
  ; message : string
  }
[@@deriving sexp, compare, equal]

let to_string d =
  Printf.sprintf "divergence at index %d: %s" (Event_index.to_int d.index) d.message
;;
