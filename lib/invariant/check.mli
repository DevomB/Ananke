(** When to evaluate domain invariants. *)

type when_ =
  | After_each_command
[@@deriving sexp, compare, equal]

type 'state checker = 'state -> (unit, Violation.t) Result.t

val run_all
  :  'state
  -> 'state checker list
  -> (unit, Violation.t list) Result.t
