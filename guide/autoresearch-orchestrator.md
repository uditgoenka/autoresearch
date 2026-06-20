# /autoresearch — Autonomous Orchestrator Mode

Type a plain-language goal. The orchestrator classifies it, selects a pipeline, and loops across subcommands until the goal is verifiably met — no manual chaining, no babysitting iteration counts.

It is a **meta-loop over the existing 14 commands** — it never edits code itself, only sequences the tools that do.

---

## When to Use

- You have a goal but don't know which command or chain to pick
- You want the system to choose and adapt the pipeline as it learns what's working
- Your goal is predicate-bearing: fix-broken, ship-ready, optimize, harden, build-feature
- You want one upfront confirmation, then autonomous iteration until done

**Not for:** goals where you already know the exact command to run (use that command directly); goals with a `Metric:` / `Verify:` already defined (classic loop runs unchanged); large greenfield scaffolding from scratch (the orchestrator iterates toward green on a defined acceptance check; it is not a code generator).

---

## Quick Start

```
/autoresearch help me fix the login bug
```

The agent:
1. **Classifies** the goal into a Goal archetype (e.g., `fix-broken`)
2. **Derives a Success predicate** — the concrete command + expected result that defines "done"
3. **Confirms once** — shows you the archetype, mode, predicate, and pipeline before any work begins
4. **Round-0 dry-run** — proves the predicate command runs and returns a value; safety-screens every derived shell command
5. **Prints a banner** — projected cycle budget, `--max-cycles` ceiling, Units-remaining definition
6. **Loops** — assess gap → route to next subcommand → run it → recompute Units remaining → repeat
7. **Stops** when the predicate is met, on Plateau (5 flat cycles), or at the ceiling (default 50)
8. **Ship gate** — if your goal implies shipping, explicit approval is always required; no auto-ship

---

## Mode Detection

The root `/autoresearch` entry point selects a mode automatically based on what you type:

| Input | Mode | Behavior |
|-------|------|----------|
| `Metric:` or `Verify:` present | Classic loop | Unchanged from existing behavior |
| Free-form natural-language goal | Orchestrator | Classifies → selects pipeline → loops |
| Nothing (bare invocation) | Setup wizard | Interactive setup as before |
| `--classic` flag | Classic loop | Force classic regardless of input |
| `--auto` flag | Orchestrator | Force orchestrator regardless of input |

The detected mode is always printed in a banner — routing is never silent.

---

## Two Orchestrator Modes

### Orchestration Loop

For predicate-bearing archetypes (`fix-broken`, `ship-ready`, `optimize-metric`, `harden`, `build-feature`). A mechanical Success predicate exists, so the orchestrator can measure progress and loop until done.

**Flow:**
```
classify goal
  → derive Success predicate (confirm once)
  → round-0 dry-run (prove predicate + screen commands)
  → LOOP:
      assess gap (cheap signals + affected-test verify)
      → next-hop (route to next subcommand)
      → run subcommand (its own bounded inner loop)
      → record outcome: progressed / no-op / failed / blocked
      → fold handoff.json into orchestrator-state.json
      → recompute Units remaining
  → STOP: predicate met | Plateau | ceiling | blocked
  → ship gate (if pipeline includes ship)
```

### Single-Pass Dispatch

For subjective or terminal archetypes (`explore`, `document`, `decide-design`, `what-to-build`). No mechanical predicate can be derived, so the orchestrator routes to one self-terminating subcommand, lets it run, and reports. No loop, no Plateau, no ceiling, no ship gate.

```
classify goal → route to one subcommand → run → report
```

---

## Flags

| Flag | Purpose | Default |
|------|---------|---------|
| `--dry-run` | Print derived config + planned pipeline; stop without executing | off |
| `--max-cycles N` | Override cycle ceiling | `50` |
| `--classic` | Force classic metric loop | off |
| `--auto` | Force orchestrator mode | off |
| `--evals` | Mid-run evals checkpoints (like other looping commands) | off |
| `--evals-interval N` | Checkpoint every N cycles | floor(max/3) |

---

## Goal Archetypes

The orchestrator classifies your goal into one of 9 archetypes and selects a starting pipeline. The router adapts per cycle from observed state — the preset is a starting point, not a fixed script.

| Archetype | Example Goals | Mode | Starting Pipeline |
|-----------|--------------|------|-------------------|
| `fix-broken` | "fix the login bug", "tests are failing" | Orchestration loop | debug → fix → regression |
| `ship-ready` | "make this shippable", "get this to production" | Orchestration loop | regression → fix → ship |
| `optimize-metric` | "make the API faster", "reduce bundle size" | Orchestration loop | plan (internal) → core loop |
| `harden` | "security-harden the auth module", "close the XSS" | Orchestration loop | security → fix → security |
| `build-feature` | "build this feature TDD", "implement the checkout flow" | Orchestration loop | scenario → fix (TDD-ladder) |
| `explore` | "explore what could go wrong here" | Single-pass dispatch | scenario |
| `document` | "document this codebase", "generate API docs" | Single-pass dispatch | learn |
| `decide-design` | "should we use event sourcing?", "pick the caching strategy" | Single-pass dispatch | reason |
| `what-to-build` | "what should we build next?", "research product improvements" | Single-pass dispatch | improve |

---

## Success Predicate

Before the loop starts, the orchestrator derives a concrete Success predicate — a specific shell command and its expected result. This is the mechanical definition of "done."

The upfront confirmation shows:
- **Archetype detected** (e.g., `fix-broken`)
- **Mode** (Orchestration loop or Single-pass dispatch)
- **Predicate** — exact command + expected result (e.g., `npm test` → exit 0, 0 failing)
- **Terminal choice** — stop at verified vs. proceed to ship

This is one question, upfront. Catching a misclassification at cycle 0 is free; catching it at cycle 40 is not.

---

## Units Remaining

The Orchestration loop's progress scalar. Lower is better. Recomputed every cycle.

**Default weights:**
- Each failing test = 1
- Each open HARD regression = 1
- Metric delta (if applicable) = normalized to its target

A cycle where Units cannot be computed (e.g., runner crash) returns `unknown`. Unknown cycles are excluded from Plateau counting; repeated unknowns route to `BLOCKED`, not `PLATEAU`.

---

## Plateau & Ceiling

**Plateau** — Units remaining is flat or worse for 5 consecutive computed cycles. The orchestrator stops and reports; it does not spin forever on an unreachable goal. Plateau catches both stalls (no progress) and thrash (oscillation that nets zero).

**Ceiling** — Hard backstop at 50 cycles (override with `--max-cycles`). Prevents a mis-derived goal from running away.

Both conditions produce a checkpoint report — partial progress is preserved, not lost.

---

## Build-Feature TDD Ladder

When the archetype is `build-feature`, no climbing metric exists yet. The orchestrator reframes progress as `green-assertion-count` — a monotone integer that can only go up.

- A change turning a red sub-test green is **kept**.
- A change regressing a green sub-test is **reverted**.
- A floor-guard prevents reverting scaffolding commits that pass zero new tests yet still let the build compile.
- If the scope is detected as large net-new (greenfield), the orchestrator advises handing off to a dedicated build command rather than grinding cycles.

---

## Shell Command Safety

Every derived shell command is safety-screened before the loop starts and again on resume from a persisted state file. The screen rejects:

- `rm -rf` and equivalent destructive patterns
- `curl | sh` and pipe-to-shell patterns
- Credential patterns (env vars, key files)
- Fork bombs
- Non-allowlisted DB URLs (reuses the regression command's anchored allowlist — `localhost`, `127.0.0.1`, container hostnames, or `_test`/`_ci` suffix; bare substrings do not qualify)

Un-screened shell commands cannot be introduced mid-loop.

---

## --dry-run

Prints the derived config and planned pipeline without executing anything. Use it to review before committing compute:

```
/autoresearch help me fix the login bug --dry-run
```

Output includes: detected archetype, mode, predicate command + expected result, starting pipeline, projected cycle budget.

The `optimize-metric` archetype also uses `--dry-run` to print a derived autoresearch config (equivalent to `/autoresearch:plan` output) — the existing "just give me a config" path is preserved.

---

## State & Checkpoints

The orchestrator writes `orchestrator-state.json` — its own additive state file. Each subcommand hop still writes its own `handoff.json` as usual; the orchestrator reads each hop's handoff and folds it in. Two clearly-owned state objects, no overlap.

On any failure or stop, a checkpoint is written immediately. Partial progress is always auditable and resumable.

---

## Chain Integration

Manual chains still work exactly as before. The orchestrator auto-selects chains for you when you give it a free-form goal — you can inspect the planned pipeline in the upfront confirmation or via `--dry-run`.

When the orchestrator completes, it writes a final `handoff.json` so its output can feed downstream commands if needed.

```
/autoresearch help me fix the login bug
# orchestrator runs: debug → fix → regression
# same result as manually chaining: /autoresearch:debug --fix → /autoresearch:regression
```

---

## Output Structure

```
orchestrator-{YYMMDD}-{HHMM}/
├── orchestrator-state.json       ← goal, archetype, predicate, Units history, per-hop log
├── orchestrator-report.md        ← verdict + cycle summary + predicate outcome
├── checkpoints/
│   └── cycle-{N}.json            ← per-cycle state snapshot
└── handoff.json                  ← chain integration (verdict + final state)
```

Each subcommand hop produces its own output directory as normal.

---

## Examples

### Fix a bug autonomously

```
/autoresearch help me fix the login bug
```

Classifies as `fix-broken`. Derives predicate: `npm test` → exit 0 (0 failing). Confirms once. Runs: debug → fix → regression. Stops when predicate is met or on Plateau.

### Build a feature TDD-first

```
/autoresearch help me build the checkout flow
Scope: src/checkout/**
```

Classifies as `build-feature`. Derives predicate: acceptance tests green. Runs TDD-ladder: scenario (generate tests) → fix (make them pass) → regression (no regressions). Tracks `green-assertion-count` as progress scalar.

### Single-pass: what to build next

```
/autoresearch what should we build next for enterprise customers?
```

Classifies as `what-to-build`. Single-pass dispatch to `/autoresearch:improve`. No loop. Emits research findings and PRDs. Report, done.

### Preview before committing compute

```
/autoresearch make this shippable --dry-run
```

Prints: archetype `ship-ready`, predicate `npm test && tsc --noEmit` → exit 0, pipeline `regression → fix → ship`, projected 15–30 cycles. No execution.

### Override cycle ceiling

```
/autoresearch harden the auth module
--max-cycles 20
```

Classifies as `harden`. Runs security → fix → security. Stops at 20 cycles if not converged earlier.

---

## Tips

- **Use `--dry-run` first on long-running goals.** Review the predicate before committing compute — catching a misclassification at dry-run is free.
- **The one upfront question matters.** Read the predicate carefully. "exit 0" vs "0 HARD regressions" are different definitions of done — correct it before confirming.
- **Plateau is not failure.** A Plateau report means the goal may need a different decomposition, tighter scope, or a more specific predicate. The checkpoint preserves everything you got.
- **Manual chains still work.** If you know exactly what you need, use it directly. The orchestrator is for when you don't.
- **Ship is never automatic.** Even when your goal implies shipping, the orchestrator pauses for explicit approval. Autonomy does not mean irreversibility.
- **Single-pass goals are instant.** Goals classified as `what-to-build`, `document`, or `decide-design` dispatch to one subcommand and finish — no loop overhead.

---

## Related

- [/autoresearch:debug](autoresearch-debug.md) — bug-hunting loop the orchestrator sequences for `fix-broken`
- [/autoresearch:fix](autoresearch-fix.md) — error crusher the orchestrator sequences for `fix-broken` and `build-feature`
- [/autoresearch:regression](autoresearch-regression.md) — stability gate the orchestrator sequences for `fix-broken` and `ship-ready`
- [/autoresearch:ship](autoresearch-ship.md) — shipping workflow; always requires explicit approval in orchestrator
- [/autoresearch:plan](autoresearch-plan.md) — manual goal → config wizard; subsumed by orchestrator's `optimize-metric` archetype
- [Chains & Combinations](chains-and-combinations.md) — manual pipelines; orchestrator picks them automatically for you
