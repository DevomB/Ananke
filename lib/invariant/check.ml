open Base

type when_ = After_each_command [@@deriving sexp, compare, equal]
type 'state checker = 'state -> (unit, Violation.t) Result.t

let run_all state checkers =
  let violations =
    List.filter_map checkers ~f:(fun checker ->
      match checker state with
      | Ok () -> None
      | Error v -> Some v)
  in
  match violations with
  | [] -> Ok ()
  | vs -> Error vs
;;
