open Base

type t = private int [@@deriving compare, equal, sexp]

let zero = (0 :> t)
let of_int n = (n :> t)
let to_int (t : t) = (t : int)
let succ t = of_int (to_int t + 1)

let%test "event index increments" =
  equal (succ zero) (of_int 1) && equal (of_int 42 |> to_int) 42
