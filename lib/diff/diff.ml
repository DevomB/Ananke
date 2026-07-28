open Base

type t = Change.t list [@@deriving sexp, compare, equal]

let rec diff_sexp path left right =
  if phys_equal left right
  then []
  else if Sexp.compare left right = 0
  then []
  else (
    match left, right with
    | Sexp.Atom l, Sexp.Atom r when String.equal l r -> []
    | Sexp.Atom _, Sexp.Atom _ -> [ Change.Changed (path, left, right) ]
    | Sexp.List ls, Sexp.List rs ->
      let rec walk i ls rs =
        match ls, rs with
        | [], [] -> []
        | [], r :: rs_rest ->
          Change.Added (path @ [ Int.to_string i ], r) :: walk (i + 1) [] rs_rest
        | l :: ls_rest, [] ->
          Change.Removed (path @ [ Int.to_string i ], l) :: walk (i + 1) ls_rest []
        | l :: ls_rest, r :: rs_rest ->
          diff_sexp (path @ [ Int.to_string i ]) l r @ walk (i + 1) ls_rest rs_rest
      in
      walk 0 ls rs
    | _ -> [ Change.Changed (path, left, right) ])
;;

let diff left right = diff_sexp Field_path.root left right
let is_empty changes = List.is_empty changes
let to_string changes = changes |> List.map ~f:Change.describe |> String.concat ~sep:"\n"

let%expect_test "diff detects atom change" =
  let before = Sexplib.Sexp.of_string "(balance 100)" in
  let after = Sexplib.Sexp.of_string "(balance 50)" in
  let changes = diff before after in
  Stdlib.print_endline (Sexp.to_string_hum [%sexp (changes : t)]);
  [%expect {| ((Changed (() balance 100 50))) |}]
;;

let%expect_test "diff detects list addition" =
  let before = Sexplib.Sexp.of_string "(requests ())" in
  let after = Sexplib.Sexp.of_string "(requests (3))" in
  let changes = diff before after in
  Stdlib.print_endline (Sexp.to_string_hum [%sexp (changes : t)]);
  [%expect {| ((Added (0 3))) |}]
;;
