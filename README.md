# Chronicle

Chronicle is a typed, deterministic event runtime for building and debugging stateful systems. It records every command, emitted event, and system transition in a replayable trace, captures snapshots, diffs state structurally, and checks domain invariants after each step.

This is an **event-systems laboratory**, not a backtesting engine.

## Install

Requirements: OCaml 5.x, opam, dune.

### Linux / macOS

```bash
cd JS_Project/chronicle
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
cd JS_Project\chronicle
.\scripts\setup.ps1
```

CI builds on every push via GitHub Actions (`.github/workflows/ci.yml`).

## Quick demo

Run the elevator scenario:

```bash
dune exec chronicle -- run --domain elevator examples/elevator/scenarios/up_down.sexp
```

This writes `examples/elevator/scenarios/up_down.trace.sexp` and verifies replay determinism.

Run the ledger scenario:

```bash
dune exec chronicle -- run --domain ledger examples/ledger/scenarios/deposit_withdraw.sexp
```

Limit order book example (finance-flavored, infrastructure-only):

```bash
dune exec chronicle -- run --domain matching_engine examples/matching_engine/scenarios/basic.sexp
```

Or `make demo-matching-engine`.

Inspect a trace:

```bash
dune exec chronicle -- inspect examples/elevator/scenarios/up_down.trace.sexp
dune exec chronicle -- trace examples/elevator/scenarios/up_down.trace.sexp
dune exec chronicle -- verify examples/elevator/scenarios/up_down.trace.sexp
dune exec chronicle -- report -t examples/elevator/scenarios/up_down.trace.sexp
dune exec chronicle -- snapshot -t examples/elevator/scenarios/up_down.trace.sexp --at-index 5 -o /tmp/snap.snap
```

Benchmark and scaffold:

```bash
dune exec chronicle -- benchmark --domain elevator --iterations 1000
dune exec chronicle -- init --name counter --output-dir examples
```

Health check:

```bash
dune exec chronicle -- doctor
```

## Architecture

Chronicle is organized as small libraries:

| Library | Role |
|---------|------|
| `chronicle.kernel` | Logical time, commands, events, errors |
| `chronicle.runtime` | `Domain.S` signature and `Runtime.Make` functor |
| `chronicle.trace` | Trace recording and timeline lookup |
| `chronicle.snapshot` | Versioned state snapshots with digest |
| `chronicle.diff` | Structural sexp diff |
| `chronicle.invariant` | Invariant checking |
| `chronicle.scenario` | Scenario loader |
| `chronicle.replay` | Replay and determinism verification |
| `chronicle.metrics` | Counters and timing |
| `chronicle.io` | Sexp file I/O (Core) |
| `chronicle.cli` | Cmdliner CLI |

See [doc/architecture.md](doc/architecture.md) for the full design.

## Extending

Implement `Domain.S` with your state, commands, events, `transition`, and `invariants`. Instantiate `Runtime.Make(YourDomain)` and run scenarios. See [doc/extending.md](doc/extending.md).

## License

MIT — see [LICENSE](LICENSE).
