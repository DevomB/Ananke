open Base

type t = string [@@deriving compare, equal, sexp]

let of_string s = s
let to_string t = t
let fresh n = sprintf "cmd-%d" n

let%test "command ids round-trip" =
  let id = fresh 7 in
  equal (of_string (to_string id)) id
