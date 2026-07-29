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

let evaluate_named state named =
  List.map named ~f:(fun (fallback_name, checker) ->
    match checker state with
    | Ok () -> Event.Passed { name = fallback_name }
    | Error v ->
      let name =
        if String.is_empty v.Violation.name then fallback_name else v.Violation.name
      in
      Event.Violated { name; message = v.Violation.message })
;;

let violations_of_outcomes outcomes =
  List.filter_map outcomes ~f:(function
    | Event.Violated { name; message } -> Some { Violation.name; message }
    | Event.Passed _ -> None)
;;
