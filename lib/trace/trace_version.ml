open Base

type t = int [@@deriving compare, equal, sexp]

let current = 1
let min_supported = 0
