(** SplitMix64 — explicit state, sexp-serializable, no ambient entropy. *)

open Base

type t = { state : int64 } [@@deriving sexp, compare, equal]

let mix64 (z : int64) : int64 =
  let open Int64 in
  let z = z lxor (z lsr 30) in
  let z = z * 0xbf58476d1ce4e5b9L in
  let z = z lxor (z lsr 27) in
  let z = z * 0x94d049bb133111ebL in
  z lxor (z lsr 31)
;;

let create seed = { state = mix64 Int64.(of_int seed lxor 0xdeadbeefcafebabeL) }

let next t =
  let state = Int64.(t.state + 0x9e3779b97f4a7c15L) in
  let t = { state } in
  t, mix64 state
;;

let bits t =
  let t, z = next t in
  t, Int64.(to_int_exn (z land 0x3fffffffL))
;;

let int t ~exclusive_upper_bound =
  if exclusive_upper_bound <= 0
  then failwith "Rng.int: exclusive_upper_bound must be positive";
  let t, b = bits t in
  t, b % exclusive_upper_bound
;;

let bool t =
  let t, b = bits t in
  t, Int.equal (b land 1) 1
;;

let float t =
  let t, b = bits t in
  t, Float.of_int b /. Float.of_int 0x3fffffff
;;

let%test "same seed yields same stream" =
  let draw rng =
    let rng, a = int rng ~exclusive_upper_bound:100 in
    let rng, b = bool rng in
    let rng, c = bits rng in
    rng, (a, b, c)
  in
  let _, left = draw (create 42) in
  let _, right = draw (create 42) in
  [%equal: int * bool * int] left right
;;

let%test "sexp round-trip preserves subsequent draws" =
  let rng0 = create 7 in
  let rng1, _ = int rng0 ~exclusive_upper_bound:50 in
  let rng1' = t_of_sexp (sexp_of_t rng1) in
  let _, a = int rng1 ~exclusive_upper_bound:1000 in
  let _, b = int rng1' ~exclusive_upper_bound:1000 in
  Int.equal a b
;;

let%test "different seeds diverge" =
  let _, a = bits (create 1) in
  let _, b = bits (create 2) in
  not (Int.equal a b)
;;
