# Extending Chronicle

## 1. Define a domain module

Create `examples/my_domain/domain.ml` implementing `Domain.S`:

```ocaml
type state = { ... } [@@deriving sexp, compare]
type command = ... [@@deriving sexp]
type event = ... [@@deriving sexp]

let name = "my_domain"
let version = 1
let initial_state = ...
let transition state command = ...
let invariants = [ my_invariant ]
```

Expose `command_of_sexp` for scenario loading.

## 2. Add a dune library

```scheme
(library
 (name chronicle_my_domain)
 (public_name chronicle_my_domain)
 (libraries chronicle.runtime base)
 (preprocess (pps ppx_jane)))
```

## 3. Wire into CLI

In `lib/cli/chronicle_cli.ml`, add a branch in `run`, `replay`, and `verify` for your domain name.

## 4. Write scenarios

Place `.sexp` files under `examples/my_domain/scenarios/`.

## 5. Test

Add tests under `test/` using `Runtime.Make` and `Replay.Make`.

## Advanced example: matching engine

`examples/matching_engine/` is a finance-flavored limit order book (not production trading logic). It demonstrates richer state (`Map`-backed open orders), multi-event commands (place then auto-match), and domain invariants such as an uncrossed book and unique order ids. Use it as a template when your domain needs aggregate structures and explicit `Match` steps.

## Tips

- Keep `transition` pure — no `printf`, no `Clock.now`, no mutable globals
- Emit fine-grained events; they are your debugging timeline
- Use invariants to encode impossible states, not just nice-to-haves
- Bump `version` when changing state shape so old traces are identifiable
