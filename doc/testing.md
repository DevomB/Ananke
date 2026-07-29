# Testing

Ananke uses `ppx_inline_test` and `ppx_expect` via dune `runtest`.

## Layout

| Directory | Focus |
|-----------|-------|
| `test/kernel` | Type round-trips, ordering |
| `test/runtime` | Elevator step behavior |
| `test/replay` | Replay matching, divergence diffs, trace minimization |
| `test/determinism` | Identical runs → identical traces |
| `test/domain_test` | Base_quickcheck invariant/determinism over generated commands |
| `test/integration` | Scenario → file → reload → replay |

## Domain property harness

`ananke.domain_test` (`Harness.Make`) takes a `Domain.S` plus a command
`Base_quickcheck.Generator` and checks:

- **invariants** — runs never raise `Invariant_violation`; successful finals pass `D.invariants`
- **determinism** — identical config + command list → equal traces (or equal errors)

Wire a generator, then call `test_invariants` / `test_determinism` from an inline test.
See `test/domain_test/test_domain_test.ml`.

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
