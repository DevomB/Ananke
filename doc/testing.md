# Testing

Chronicle uses `ppx_inline_test` and `ppx_expect` via dune `runtest`.

## Layout

| Directory | Focus |
|-----------|-------|
| `test/kernel` | Type round-trips, ordering |
| `test/runtime` | Elevator step behavior |
| `test/replay` | Replay produces matching trace |
| `test/determinism` | Identical runs → identical traces |
| `test/integration` | Scenario → file → reload → replay |

## Running

```bash
dune runtest
```

Verbose:

```bash
dune runtest --verbose
```

## Expect tests

`lib/diff/diff.ml` and `lib/trace/trace.ml` contain `ppx_expect` tests for sexp output stability.

## Adding tests

Prefer `ppx_inline_test` for property checks. Use expect tests only when output format is the contract.

Integration tests assume cwd is the project root (dune default).
