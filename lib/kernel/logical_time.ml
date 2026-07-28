open Base

type t = int64 [@@deriving sexp_of]

let compare (a : t) (b : t) = Int64.compare (a : int64) (b : int64)
let equal (a : t) (b : t) = Int64.equal (a : int64) (b : int64)
let zero = (0L :> t)
let of_int64 x = (x :> t)
let to_int64 (t : t) : int64 = t
let succ t = of_int64 Int64.(to_int64 t + 1L)
let add t n = of_int64 Int64.(to_int64 t + n)
let t_of_sexp s = of_int64 (Int64.t_of_sexp s)

let%test "logical time advances" =
  equal (succ zero) (of_int64 1L) && equal (add zero 5L) (of_int64 5L)
;;
