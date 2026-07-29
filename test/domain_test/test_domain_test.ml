open Base
open Base_quickcheck

module Elevator_cmd = struct
  open Ananke_elevator.Domain

  type t = command

  let quickcheck_generator =
    Generator.weighted_union
      [ ( 2.
        , Generator.map Generator.small_positive_or_zero_int ~f:(fun n ->
            Request_floor (n % 11)) )
      ; 3., Generator.return Step
      ]
  ;;

  let quickcheck_shrinker = Shrinker.atomic
  let sexp_of = [%sexp_of: command]
end

module Elevator_harness = Harness.Make (Ananke_elevator.Domain) (Elevator_cmd)

module Ledger_cmd = struct
  open Ananke_ledger.Domain

  type t = command

  let positive_amount =
    Generator.map Generator.small_strictly_positive_int ~f:(fun n -> Int.max 1 (n % 50))
  ;;

  let quickcheck_generator =
    Generator.union
      [ Generator.map positive_amount ~f:(fun n -> Deposit n)
      ; Generator.map positive_amount ~f:(fun n -> Withdraw n)
      ; Generator.map positive_amount ~f:(fun n -> Transfer ("other", n))
      ]
  ;;

  let quickcheck_shrinker = Shrinker.atomic
  let sexp_of = [%sexp_of: command]
end

module Ledger_harness = Harness.Make (Ananke_ledger.Domain) (Ledger_cmd)

let%test_unit "elevator invariants hold under generated commands" =
  Elevator_harness.test_invariants ~trials:40 ()
;;

let%test_unit "elevator runs are deterministic under generated commands" =
  Elevator_harness.test_determinism ~trials:40 ()
;;

let%test_unit "ledger invariants hold under generated commands" =
  Ledger_harness.test_invariants ~trials:40 ()
;;

let%test_unit "ledger runs are deterministic under generated commands" =
  Ledger_harness.test_determinism ~trials:40 ()
;;

let%test "elevator harness accepts a known valid sequence" =
  let open Ananke_elevator.Domain in
  try
    Elevator_harness.check_invariants [ Request_floor 3; Step; Step ];
    Elevator_harness.check_determinism [ Request_floor 3; Step; Step ];
    true
  with
  | _ -> false
;;
