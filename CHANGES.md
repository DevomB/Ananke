# Changelog

## Unreleased

### Added

- Static typed domain registry (`Domain_registry`) — CLI dispatches via packed `Domain.S` modules; no Dynlink plugins.
- Versioned trace envelopes (`Trace_envelope`) with compatibility checks and migrations from legacy bare traces.
- Typed snapshot restore via `state_of_sexp` + serialized `Rng.t` (`Runtime.restore`).
- Replay-from-checkpoint API (`Replay.replay_from_checkpoint` / `check_from_checkpoint`) and CLI `checkpoint`.
- Divergence reports with structural event/state diffs (`Divergence.t`).
- Named invariant outcomes recorded as `Event.System (Invariant_checked …)` inspectable evidence.
- Base_quickcheck domain-test harness (`ananke.domain_test` / `Harness.Make`).
- Trace minimization (`Minimize`) and CLI `minimize`.
- Explicit deterministic `Rng.t` (SplitMix64) with sexp-serialized state; ambient `Random` forbidden in domains.
- Trace branching (`Branch.fork` / `fork_from_snapshot`) and CLI `branch`.
- Initial MVP: deterministic event runtime with replay, snapshot diffing, and invariant verification.
- CLI: `run`, `replay`, `diff`, `verify`, `trace`, `inspect`, `doctor`, `snapshot`, `checkpoint`, `branch`, `minimize`, `report`, `benchmark`, `init`.
