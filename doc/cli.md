# CLI

The `ananke` executable dispatches fourteen subcommands.

## `run`

Execute a scenario file against a domain.

```bash
dune exec ananke -- run --domain elevator SCENARIO.sexp [--seed N] [-o TRACE.sexp]
```

Domains: `elevator`, `ledger`, `matching_engine`.

Writes a trace (default: `SCENARIO.trace.sexp`) and verifies replay inline.

## `replay`

Re-execute commands from a trace and compare event streams.

```bash
dune exec ananke -- replay TRACE.sexp
```

## `diff`

Structural diff of final states from traces or snapshots.

```bash
dune exec ananke -- diff LEFT.sexp RIGHT.sexp
```

## `verify`

Replay + determinism check without writing output.

```bash
dune exec ananke -- verify TRACE.sexp
```

## `trace`

Print numbered events.

```bash
dune exec ananke -- trace TRACE.sexp
```

## `inspect`

Print trace metadata and final state summary.

```bash
dune exec ananke -- inspect TRACE.sexp
```

## `snapshot`

Extract a snapshot at a given event index from a trace.

```bash
dune exec ananke -- snapshot -t TRACE.sexp --at-index 5 -o SNAP.snap
```

Uses a stored snapshot when present; otherwise replays commands through that index.

## `checkpoint`

Restore a snapshot at an event index and verify the post-checkpoint command suffix matches the original trace.

```bash
dune exec ananke -- checkpoint -t TRACE.sexp --at-index 5
```

## `branch`

Fork from a shared prefix scenario, apply baseline vs alternate suffixes, and print the structural state diff.

```bash
dune exec ananke -- branch --domain elevator \
  --prefix prefix.sexp --baseline base.sexp --alternate alt.sexp
```

Each path is a scenario file (same format as `run`).

## `minimize`

Shrink a failing scenario to a minimal reproducing command sequence.

```bash
dune exec ananke -- minimize --domain elevator SCENARIO.sexp
```

## `report`

Summarize a trace: event counts, metrics, and invariant violations.

```bash
dune exec ananke -- report -t TRACE.sexp [--format text|sexp]
```

Default format is human-readable text on stdout.

## `benchmark`

Run a built-in throughput benchmark.

```bash
dune exec ananke -- benchmark [--iterations 1000] [--domain elevator|ledger]
```

Prints commands/sec to stdout.

## `init`

Scaffold a new domain directory with `domain.ml`, `domain.mli`, `dune`, and a sample scenario.

```bash
dune exec ananke -- init --name my_domain --output-dir examples
```

Creates `examples/my_domain/` with a minimal counter domain template.

## `doctor`

Quick installation sanity check.

```bash
dune exec ananke -- doctor
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
