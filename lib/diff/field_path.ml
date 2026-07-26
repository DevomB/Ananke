open Base

type t = string list [@@deriving sexp, compare, equal]

let to_string path = String.concat ~sep:"." path
let root = []
