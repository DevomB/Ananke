open Base

type t = int [@@deriving sexp_of]

let compare (a : t) (b : t) = Int.compare (a : int) (b : int)
let equal (a : t) (b : t) = Int.equal (a : int) (b : int)
let zero = (0 :> t)
let of_int n = (n :> t)
let to_int (t : t) : int = t
let succ t = of_int (to_int t + 1)
let t_of_sexp s = of_int (Int.t_of_sexp s)

let%test "event index increments" =
  equal (succ zero) (of_int 1) && equal (of_int 42 |> to_int) 42
;;
