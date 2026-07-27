# Invariants

Invariants are domain-owned predicates evaluated by the runtime after each successful command.

## Domain definition

```ocaml
val invariants : (state -> (unit, Violation.t) Result.t) list
```

Each function returns `Ok ()` or `Error { name; message }`.

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

Every check emits `Event.System Invariant_checked` so you can see invariant evaluation points in the trace timeline.

## Check module

`Check.run_all` executes all registered checkers and collects violations. The runtime assigns names `invariant-0`, `invariant-1`, … when domains do not set explicit names.
