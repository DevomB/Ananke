open Base

type packed = (module Ananke_runtime.Domain.S)

module Elevator = Ananke_elevator.Domain
module Ledger = Ananke_ledger.Domain
module Matching_engine = Ananke_matching_engine.Domain

let all : packed list =
  [ (module Elevator : Ananke_runtime.Domain.S)
  ; (module Ledger : Ananke_runtime.Domain.S)
  ; (module Matching_engine : Ananke_runtime.Domain.S)
  ]
;;

let name_of (module D : Ananke_runtime.Domain.S) = D.name
let names = List.map all ~f:name_of
let names_doc = String.concat ~sep:", " names
let normalize name = String.lowercase (String.strip name)

let find name =
  let key = normalize name in
  List.find all ~f:(fun packed -> String.equal (normalize (name_of packed)) key)
;;

let find_exn name =
  match find name with
  | Some packed -> packed
  | None ->
    failwith (Printf.sprintf "unknown domain: %s (expected one of: %s)" name names_doc)
;;

let with_domain name ~f = f (find_exn name)
