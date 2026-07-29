(** When to evaluate domain invariants. *)

type when_ = After_each_command [@@deriving sexp, compare, equal]
type 'state checker = 'state -> (unit, Violation.t) Result.t

val run_all : 'state -> 'state checker list -> (unit, Violation.t list) Result.t

(** Evaluate named checkers into inspectable pass/fail outcomes. *)
val evaluate_named
  :  'state
  -> (string * 'state checker) list
  -> Event.invariant_outcome list

val violations_of_outcomes : Event.invariant_outcome list -> Violation.t list
