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
│  kernel (time, commands, events)        │
└─────────────────────────────────────────┘
```

## Extension point

`Runtime.Make(D : Domain.S)` is the primary integration point. Domains provide:

- `initial_state` and `transition : state -> command -> (state * event list, error) Result.t`
- `invariants : (state -> (unit, Violation.t) Result.t) list`

The runtime wraps each transition with:

1. Command recording (`Event.Command`)
2. Emitted domain events (`Event.Emitted`)
3. Invariant checks (`Event.System Invariant_checked`)
4. Logical clock advance (`Event.System Clock_advanced`)
5. Optional snapshots (`Event.System Snapshot_taken`)

## Trace format

A trace is a sexp-serializable record:

- `metadata` — domain name, version, rng seed, counts
- `events` — ordered kernel events
- `final_state` — sexp of terminal domain state
- `snapshots` — optional captured snapshots

## Determinism contract

Given the same domain version, initial state, command list, and `Config.t`, Ananke must produce bit-identical traces. Replay re-executes commands extracted from the trace and compares event streams byte-for-byte (via `Event.equal`).

## Non-goals (MVP)

- Wall-clock scheduling or async I/O
- Distributed consensus
- Market data or portfolio simulation
- Probabilistic execution (rng seed is recorded but not consumed in example domains)
