# Changelog

## Unreleased

### Added

- Initial MVP: deterministic event runtime with replay, snapshot diffing, and invariant verification.
- `chronicle.kernel` core types: logical time, commands, events, errors.
- `chronicle.runtime` functor `Runtime.Make` as the main extension point.
- Trace recording, snapshot capture, structural sexp diffing.
- Scenario loader, replay engine, and metrics collection.
- CLI: `run`, `replay`, `diff`, `verify`, `trace`, `inspect`, `doctor`, `snapshot`, `report`, `benchmark`, `init`.
- Elevator, ledger, and matching_engine example domains with scenarios.
