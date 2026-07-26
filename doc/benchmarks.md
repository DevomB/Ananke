# Benchmarks

A minimal benchmark lives in `bench/`.

## Run

```bash
dune exec ./bench/chronicle_bench.exe
```

## What it measures

The bench runs 100 elevator commands (alternating `Request_floor` and `Step`) and prints command/event counts plus wall time recorded in `Metrics.t`.

## Interpreting results

Chronicle MVP is not optimized for throughput. The bench exists as a baseline for future work:

- trace append currently uses list concatenation
- invariant checks run sequentially after each command
- snapshots are optional (`Config.snapshot_each_command`)

## Future benchmarks

- Large traces (10k+ events) replay time
- Diff on deep nested sexps
- Snapshot digest throughput
