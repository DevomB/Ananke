(* Alias before [open Base] — Base.Domain (OCaml 5) would otherwise shadow. *)
module Domain_ = Domain
module Runtime_config = Config
open Base
open Base_quickcheck

module type Command_gen = sig
  type t

  val quickcheck_generator : t Generator.t
  val quickcheck_shrinker : t Shrinker.t
  val sexp_of : t -> Sexp.t
end

module Make (D : Domain_.S) (Cmd : Command_gen with type t = D.command) = struct
  module R = Runtime.Make (D)

  let commands_generator = Generator.list Cmd.quickcheck_generator
  let run_once config commands = R.create config |> fun rt -> R.run rt commands

  let check_determinism ?(config = Runtime_config.default) commands =
    let command_sexps = List.map commands ~f:Cmd.sexp_of in
    match run_once config commands, run_once config commands with
    | Ok a, Ok b ->
      if not (Trace.equal a.trace b.trace)
      then
        raise_s
          [%message
            "nondeterministic traces"
              (command_sexps : Sexp.t list)
              ~left:(a.trace : Trace.t)
              ~right:(b.trace : Trace.t)]
    | Error e1, Error e2 ->
      if not (Ananke_error.equal e1 e2)
      then
        raise_s
          [%message
            "nondeterministic errors"
              (command_sexps : Sexp.t list)
              (e1 : Ananke_error.t)
              (e2 : Ananke_error.t)]
    | Ok _, Error e | Error e, Ok _ ->
      raise_s
        [%message
          "mixed ok/error across identical runs"
            (command_sexps : Sexp.t list)
            (e : Ananke_error.t)]
  ;;

  let check_invariants ?(config = Runtime_config.default) commands =
    let command_sexps = List.map commands ~f:Cmd.sexp_of in
    match run_once config commands with
    | Error (Ananke_error.Invariant_violation msg) ->
      raise_s
        [%message
          "invariant violated during run" (command_sexps : Sexp.t list) (msg : string)]
    | Error (Ananke_error.Invalid_command _) -> ()
    | Error err ->
      raise_s
        [%message
          "unexpected runtime error" (command_sexps : Sexp.t list) (err : Ananke_error.t)]
    | Ok result ->
      List.iter D.invariants ~f:(fun (name, inv) ->
        match inv result.state with
        | Ok () -> ()
        | Error v ->
          raise_s
            [%message
              "final state fails invariant"
                (command_sexps : Sexp.t list)
                (name : string)
                (v.name : string)
                (v.message : string)
                (result.state : D.state)])
  ;;

  let qc_config ~trials =
    { Test.default_config with
      seed = Test.Config.Seed.Deterministic "ananke-domain-test"
    ; test_count = trials
    }
  ;;

  let test_with ~(config : Runtime_config.t) ~trials ~f =
    Test.run_exn
      ~config:(qc_config ~trials)
      (module struct
        type t = D.command list

        let sexp_of_t commands =
          [%sexp_of: Sexp.t list] (List.map commands ~f:Cmd.sexp_of)
        ;;

        let quickcheck_generator = commands_generator
        let quickcheck_shrinker = Shrinker.list Cmd.quickcheck_shrinker
      end)
      ~f:(fun commands -> f ~config commands)
  ;;

  let test_determinism ?(config = Runtime_config.default) ?(trials = 50) () =
    test_with ~config ~trials ~f:(fun ~config commands ->
      check_determinism ~config commands)
  ;;

  let test_invariants ?(config = Runtime_config.default) ?(trials = 50) () =
    test_with ~config ~trials ~f:(fun ~config commands ->
      check_invariants ~config commands)
  ;;
end
