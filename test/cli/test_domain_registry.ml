open Base

let%test "registry lists builtin domains" =
  let expected = [ "elevator"; "ledger"; "matching_engine" ] in
  List.equal String.equal Domain_registry.names expected
;;

let%test "find is case-insensitive" =
  match Domain_registry.find "Elevator" with
  | None -> false
  | Some (module D : Ananke_runtime.Domain.S) -> String.equal D.name "elevator"
;;

let%test "find rejects unknown domains" = Option.is_none (Domain_registry.find "nope")

let%test "with_domain applies packed module" =
  Domain_registry.with_domain "ledger" ~f:(fun (module D : Ananke_runtime.Domain.S) ->
    String.equal D.name "ledger" && Int.equal D.version 1)
;;
