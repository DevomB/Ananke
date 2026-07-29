# Extending Ananke

## 1. Define a domain module

Create `examples/my_domain/domain.ml` implementing `Domain.S`:

```ocaml
type state = { ... } [@@deriving sexp, compare]
type command = ... [@@deriving sexp]
type event = ... [@@deriving sexp]

let name = "my_domain"
let version = 1
let initial_state = ...
let transition state rng command = ...  (* thread rng; draw only via Rng *)
let invariants = [ "my_invariant", my_invariant ]
```

Expose `command_of_sexp` for scenario loading and `state_of_sexp` for snapshot restore.

If the domain needs randomness, draw from the passed `Rng.t` and return the advanced value. Never call `Stdlib.Random` / `Base.Random`.

## 2. Add a dune library

```scheme
(library
 (name ananke_my_domain)
 (public_name ananke.my_domain)
 (libraries ananke.runtime base)
 (preprocess (pps ppx_jane)))
```

## 3. Register with the CLI

Add a packed entry to `Domain_registry.all` in `lib/cli/domain_registry.ml`:

```ocaml
let all : packed list =
  [ (module Elevator : Ananke_runtime.Domain.S)
  ; (module Ledger : Ananke_runtime.Domain.S)
  ; (module Matching_engine : Ananke_runtime.Domain.S)
  ; (module My_domain : Ananke_runtime.Domain.S)  (* new *)
  ]
```

CLI subcommands (`run`, `replay`, `verify`, `snapshot`, `checkpoint`, `branch`, `minimize`, `report`, `doctor`) look up domains through this static registry — no new `match` branches.

## 4. Write scenarios

Place `.sexp` files under `examples/my_domain/scenarios/`.

## 5. Test

Add tests under `test/` using `Runtime.Make` and `Replay.Make`.

## Advanced example: matching engine

`examples/matching_engine/` is a finance-flavored limit order book (not production trading logic). It demonstrates richer state (`Map`-backed open orders), multi-event commands (place then auto-match), and domain invariants such as an uncrossed book and unique order ids. Use it as a template when your domain needs aggregate structures and explicit `Match` steps.

## Tips

- Keep `transition` pure — no `printf`, no `Clock.now`, no mutable globals, no ambient RNG
- Emit fine-grained events; they are your debugging timeline
- Use invariants to encode impossible states, not just nice-to-haves
- Bump `version` when changing state shape so old traces are identifiable
- Property-test with `ananke.domain_test` (`Harness.Make`) plus a command generator — see `test/domain_test/`
