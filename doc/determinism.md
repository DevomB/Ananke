# Determinism

Ananke treats determinism as a first-class property, not an accident of single-threaded code.

## Logical time

`Logical_time.t` is a private `int64` wrapper advanced only by the runtime after each successful command. Domain code never reads wall-clock time. Ordering is entirely `(logical_time, event_index)`.

## Event index

`Event_index.t` assigns a stable position to every recorded event within a run. Replay compares events at the same index.

## Explicit RNG

`Rng.t` is a SplitMix64 generator with sexp-serializable state. The runtime seeds it from `Config.rng_seed` and passes it into every `Domain.transition`. Domains that need randomness must draw from that value and return the advanced state. Domains that do not need randomness thread the RNG through unchanged.

**Never** call ambient generators (`Stdlib.Random`, `Base.Random`, `Random.self_init`, …) from domain code. Ambient entropy breaks replay and checkpoint resume.

Snapshots capture both domain state and RNG sexp so restore continues the same stream.

## What must be pure

| Component | Deterministic requirement |
|-----------|---------------------------|
| `Domain.transition` | Same `(state, rng, command)` → same `(state', events', rng')` |
| `Domain.invariants` | Same `state` → same result |
| Trace serialization | `sexp_of` / `t_of_sexp` round-trip |
| `Rng.t` | Same seed / serialized state → same draw sequence |

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
- `test/runtime` includes a coin-flip domain that draws only from explicit `Rng.t`
