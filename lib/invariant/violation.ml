open Base

type t =
  { name : string
  ; message : string
  }
[@@deriving sexp, compare, equal]

let to_string t = sprintf "%s: %s" t.name t.message
