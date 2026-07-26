# CLI

The `chronicle` executable dispatches eleven subcommands.

## `run`

Execute a scenario file against a domain.

```bash
dune exec chronicle -- run --domain elevator SCENARIO.sexp [--seed N] [-o TRACE.sexp]
```

Domains: `elevator`, `ledger`, `matching_engine`.

Writes a trace (default: `SCENARIO.trace.sexp`) and verifies replay inline.

## `replay`

Re-execute commands from a trace and compare event streams.

```bash
dune exec chronicle -- replay TRACE.sexp
```

## `diff`

Structural diff of final states from traces or snapshots.

```bash
dune exec chronicle -- diff LEFT.sexp RIGHT.sexp
```

## `verify`

Replay + determinism check without writing output.

```bash
dune exec chronicle -- verify TRACE.sexp
```

## `trace`

Print numbered events.

```bash
dune exec chronicle -- trace TRACE.sexp
```

## `inspect`

Print trace metadata and final state summary.

```bash
dune exec chronicle -- inspect TRACE.sexp
```

## `snapshot`

Extract a snapshot at a given event index from a trace.

```bash
dune exec chronicle -- snapshot -t TRACE.sexp --at-index 5 -o SNAP.snap
```

Uses a stored snapshot when present; otherwise replays commands through that index.

## `report`

Summarize a trace: event counts, metrics, and invariant violations.

```bash
dune exec chronicle -- report -t TRACE.sexp [--format text|sexp]
```

Default format is human-readable text on stdout.

## `benchmark`

Run a built-in throughput benchmark.

```bash
dune exec chronicle -- benchmark [--iterations 1000] [--domain elevator|ledger]
```

Prints commands/sec to stdout.

## `init`

Scaffold a new domain directory with `domain.ml`, `domain.mli`, `dune`, and a sample scenario.

```bash
dune exec chronicle -- init --name my_domain --output-dir examples
```

Creates `examples/my_domain/` with a minimal counter domain template.

## `doctor`

Quick installation sanity check.

```bash
dune exec chronicle -- doctor
```

## Scenario format

```scheme
((name my-scenario)
 (domain elevator)
 (rng_seed 42)
 (commands
  ((Request_floor 3)
   Step)))
```

Commands are domain-specific sexps parsed by each example domain.
