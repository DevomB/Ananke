# Invariants

Invariants are domain-owned named predicates evaluated by the runtime after each successful command.

## Domain definition

```ocaml
val invariants : (string * (state -> (unit, Violation.t) Result.t)) list
```

Each entry is `(name, checker)`. The checker returns `Ok ()` or `Error { name; message }`.

## Runtime modes

`Config.invariant_mode` controls behavior:

| Mode | On violation |
|------|----------------|
| `Stop` | Halt run with `Ananke_error.Invariant_violation` |
| `Record` | Continue; accumulate violations in `Transition_result.violations` |
| `Warn` | Same as `Record` (MVP; CLI may log later) |

## Example: elevator

- **no_empty_travel** — direction `Up`/`Down` requires pending requests in that direction
- **floor_valid** — current floor within `[0, 10]`

## Example: ledger

- **non_negative_balance** — `balance >= 0` after every command

## Trace visibility

Every check emits `Event.System (Invariant_checked outcomes)` so the sealed trace carries
inspectable pass/fail evidence — not only a check marker.

Each outcome is either:

- `Passed { name }` — checker held (name from the domain registry entry)
- `Violated { name; message }` — checker failed (prefers `Violation.name` when set; also
  accumulated in `Transition_result.violations` under `Record`/`Warn`)

`Trace.invariant_outcomes` / `Trace.invariant_violations` (and the same helpers on `Event`)
read that evidence without re-running the domain. CLI `inspect` and `report` surface it.

## Check module

`Check.evaluate_named` runs `(name, checker)` pairs into outcomes. `Check.run_all` still
collects violations only.
