# Architecture

Ananke models stateful systems as **domains** driven by **commands** that produce **events** under a monotonic **logical clock**. Every step is recorded in an append-only **trace** suitable for replay and diffing.

## Layers

```
┌─────────────────────────────────────────┐
│  CLI (cmdliner)                         │
├─────────────────────────────────────────┤
│  scenario · replay · io                 │
├─────────────────────────────────────────┤
│  runtime (Runtime.Make functor)         │
├─────────────────────────────────────────┤
│  trace · snapshot · diff · invariant    │
├─────────────────────────────────────────┤
│  kernel (time, commands, events, rng)   │
└─────────────────────────────────────────┘
```

## Extension point

`Runtime.Make(D : Domain.S)` is the primary integration point. Domains provide:

- `initial_state` and `transition : state -> Rng.t -> command -> (state * event list * Rng.t, error) Result.t`
- `invariants : (string * (state -> (unit, Violation.t) Result.t)) list`

The runtime seeds `Rng.t` from `Config.rng_seed` and threads it through every transition. Domains must not use ambient randomness.

The runtime wraps each transition with:

1. Command recording (`Event.Command`)
2. Emitted domain events (`Event.Emitted`)
3. Invariant checks (`Event.System (Invariant_checked outcomes)` with named pass/fail evidence)
4. Logical clock advance (`Event.System Clock_advanced`)
5. Optional snapshots (`Event.System Snapshot_taken`)

## Trace format

Traces on disk are versioned envelopes (`Trace_envelope`) with explicit compatibility checks and migrations from older bare traces.

A trace payload is a sexp-serializable record:

- `metadata` — domain name, version, rng seed, counts
- `events` — ordered kernel events
- `final_state` — sexp of terminal domain state
- `snapshots` — optional captured snapshots

## Determinism contract

Given the same domain version, initial state, command list, and `Config.t`, Ananke must produce bit-identical traces. Replay re-executes commands extracted from the trace and compares event streams byte-for-byte (via `Event.equal`). Divergences include structural event/state diffs (`Divergence.t`), not only the first mismatched index.

## Checkpoint resume

`Runtime.restore` parses typed state via `state_of_sexp` and restores serialized `Rng.t`. `Replay.replay_from_checkpoint` / `check_from_checkpoint` restore a snapshot, replay only the suffix, and verify the same result.

## Domain property tests

`Harness.Make(D)(Cmd)` in `ananke.domain_test` runs Base_quickcheck over command lists: invariants must never break, and identical inputs must yield identical traces (or identical errors). Generators live with the test, not in `Domain.S`.

## Trace minimization

`Minimize.shrink` / `Minimize.Make(D).minimize` take a failing command sequence and a failure predicate, then drop commands (half-cuts, then single drops) until no shorter subsequence still fails. Default failure for a domain is a runtime `Error` (invalid command or invariant stop).

## Trace branching

`Branch.fork` / `fork_from_snapshot` restore a shared checkpoint, apply baseline vs alternate command suffixes, and return a structural state diff of the two finals.

## Non-goals (MVP)

- Wall-clock scheduling or async I/O
- Distributed consensus
- Market data or portfolio simulation
- Dynlink / runtime plugin loading (domains are a static typed registry)
- Built-in stochastic scenario generation (domains may consume `Rng.t` explicitly)
