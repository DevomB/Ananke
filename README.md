# Ananke

Ananke is a typed, deterministic event runtime for building and debugging stateful systems. It records every command, emitted event, and system transition in a replayable trace, captures snapshots, diffs state structurally, and checks domain invariants after each step.

This is an **event-systems laboratory**, not a backtesting engine.

## Install

Requirements: OCaml 5.x, opam, dune.

### Linux / macOS

```bash
cd JS_Project/ananke
opam install . --deps-only --with-test
dune build
dune runtest
```

Or use the setup script:

```bash
./scripts/setup.sh
```

### Windows

Install opam and a compiler (pick one):

```powershell
winget install OCaml.opam
winget install Diskuv.OCaml
```

Then from the project root:

```powershell
cd JS_Project\ananke
.\scripts\setup.ps1
```

CI builds on every push via GitHub Actions (`.github/workflows/ci.yml`).

## Quick demo

Run the elevator scenario:

```bash
dune exec ananke -- run --domain elevator examples/elevator/scenarios/up_down.sexp
```

This writes `examples/elevator/scenarios/up_down.trace.sexp` and verifies replay determinism.

Run the ledger scenario:

```bash
dune exec ananke -- run --domain ledger examples/ledger/scenarios/deposit_withdraw.sexp
```

Limit order book example (finance-flavored, infrastructure-only):

```bash
dune exec ananke -- run --domain matching_engine examples/matching_engine/scenarios/basic.sexp
```

Or `make demo-matching-engine`.

Inspect a trace:

```bash
dune exec ananke -- inspect examples/elevator/scenarios/up_down.trace.sexp
dune exec ananke -- trace examples/elevator/scenarios/up_down.trace.sexp
dune exec ananke -- verify examples/elevator/scenarios/up_down.trace.sexp
dune exec ananke -- report -t examples/elevator/scenarios/up_down.trace.sexp
dune exec ananke -- snapshot -t examples/elevator/scenarios/up_down.trace.sexp --at-index 5 -o /tmp/snap.snap
```

Benchmark and scaffold:

```bash
dune exec ananke -- benchmark --domain elevator --iterations 1000
dune exec ananke -- init --name counter --output-dir examples
```

Health check:

```bash
dune exec ananke -- doctor
```

## Architecture

Ananke is organized as small libraries:

| Library | Role |
|---------|------|
| `ananke.kernel` | Logical time, commands, events, errors |
| `ananke.runtime` | `Domain.S` signature and `Runtime.Make` functor |
| `ananke.trace` | Trace recording and timeline lookup |
| `ananke.snapshot` | Versioned state snapshots with digest |
| `ananke.diff` | Structural sexp diff |
| `ananke.invariant` | Invariant checking |
| `ananke.scenario` | Scenario loader |
| `ananke.replay` | Replay and determinism verification |
| `ananke.metrics` | Counters and timing |
| `ananke.io` | S-expression file I/O |
| `ananke.cli` | Cmdliner CLI |

See [doc/architecture.md](doc/architecture.md) for the full design.

## Extending

Implement `Domain.S` with your state, commands, events, `transition`, and `invariants`. Instantiate `Runtime.Make(YourDomain)` and run scenarios. See [doc/extending.md](doc/extending.md).

## License

MIT — see [LICENSE](LICENSE).
