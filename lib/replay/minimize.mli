(** Trace minimization: shrink a failing command sequence to a minimal
    reproducing subsequence (Quickcheck-style list shrinking). *)

open Base

type 'a t =
  { original : 'a list
  ; minimized : 'a list
  ; attempts : int
  }
[@@deriving sexp, compare, equal]

val length_reduced : _ t -> bool

(** [shrink ~fails xs] searches for a shorter subsequence of [xs] that still
    satisfies [fails]. If [fails xs] is false, returns [xs] unchanged. *)
val shrink : fails:('a list -> bool) -> 'a list -> 'a t

module Make (D : Ananke_runtime.Domain.S) : sig
  (** True when running [commands] under [config] yields [Error _]. *)
  val run_fails : Config.t -> D.command list -> bool

  (** Shrink [commands] with [fails]. By default candidates must reproduce the
      same runtime error as the original sequence. *)
  val minimize
    :  Config.t
    -> ?fails:(D.command list -> bool)
    -> D.command list
    -> D.command t

  (** Parse command sexps, then minimize. *)
  val minimize_command_sexps
    :  Config.t
    -> ?fails:(D.command list -> bool)
    -> Sexp.t list
    -> (D.command t, Ananke_error.t) Result.t
end
