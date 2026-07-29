(** Deterministic PRNG with serializable state.

    Domains must draw randomness only through [Rng] values passed into
    [transition]. Never use [Stdlib.Random], [Base.Random], or any other
    ambient generator — those break replay and checkpoint resume. *)

open Base

type t [@@deriving sexp, compare, equal]

(** Build an RNG from [Config.rng_seed]. Same seed → identical stream. *)
val create : int -> t

(** 30-bit non-negative integer, and the advanced state. *)
val bits : t -> t * int

(** Uniform draw in [[0, exclusive_upper_bound)]. *)
val int : t -> exclusive_upper_bound:int -> t * int

val bool : t -> t * bool

(** Uniform float in [[0, 1)]. *)
val float : t -> t * float
