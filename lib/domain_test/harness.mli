(** Base_quickcheck harness for domain command sequences.

    Domains supply a command generator; the harness checks invariant and
    determinism properties over randomly generated command lists. *)

module type Command_gen = sig
  type t

  val quickcheck_generator : t Base_quickcheck.Generator.t
  val quickcheck_shrinker : t Base_quickcheck.Shrinker.t
  val sexp_of : t -> Base.Sexp.t
end

module Make
    (D : Ananke_runtime.Domain.S)
    (Cmd : Command_gen with type t = D.command) : sig
  (** Bounded-length lists of generated commands. *)
  val commands_generator : Cmd.t list Base_quickcheck.Generator.t

  (** Two runs with the same config and commands agree on Ok-trace or Error. *)
  val check_determinism : ?config:Ananke_runtime.Config.t -> Cmd.t list -> unit

  (** [Invariant_violation] never; successful finals satisfy [D.invariants]. *)
  val check_invariants : ?config:Ananke_runtime.Config.t -> Cmd.t list -> unit

  val test_determinism : ?config:Ananke_runtime.Config.t -> ?trials:int -> unit -> unit
  val test_invariants : ?config:Ananke_runtime.Config.t -> ?trials:int -> unit -> unit
end
