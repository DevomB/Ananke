# Determinism

Ananke treats determinism as a first-class property, not an accident of single-threaded code.

## Logical time

`Logical_time.t` is a private `int64` wrapper advanced only by the runtime after each successful command. Domain code never reads wall-clock time. Ordering is entirely `(logical_time, event_index)`.

## Event index

`Event_index.t` assigns a stable position to every recorded event within a run. Replay compares events at the same index.

## What must be pure

| Component | Deterministic requirement |
|-----------|---------------------------|
| `Domain.transition` | Same `(state, command)` → same `(state', events')` |
| `Domain.invariants` | Same `state` → same result |
| Trace serialization | `sexp_of` / `t_of_sexp` round-trip |

## What is recorded but not driving behavior (MVP)

`Config.rng_seed` is stored in trace metadata for future stochastic domains. Example domains (elevator, ledger) do not draw random numbers.

## Verification flow

```
run(commands) → trace₀
replay(trace₀) → trace₁
verify(trace₀, trace₁) → Ok | Divergence
```

`Divergence.t` pinpoints the first index where events differ.

## Testing

- `test/determinism` runs identical command lists twice and asserts `Trace.equal`
- `test/replay` replays elevator traces
- `test/integration` runs scenario → file → reload → replay → verify
