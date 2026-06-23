---
name: autoresearch
description: "Autonomous iteration loop: modify, verify, keep/discard against any metric"
version: 2.2.1
---

# Autoresearch — Autonomous Goal-directed Iteration

## Safety Invariants (all subcommands)
- Never push, publish, or deploy without explicit user approval.
- Bounded by default. Override with `Iterations: unlimited`.
- All results logged to `autoresearch/{subcommand}-{YYMMDD}-{HHMM}/` directory.
- Chain handoff via `handoff.json`. Evals reads `*-results.tsv`.

## Dispatch (bare `/autoresearch`)

Parse the invocation in this order:

| Condition | Mode |
|---|---|
| `Metric:` or `Verify:` present | **Classic** — existing metric loop, unchanged |
| Free-form natural-language goal, no metric/verify | **Orchestrator** — see Orchestrator section |
| Nothing | **Setup wizard** — interactive config builder |
| `--classic` flag | Force Classic regardless of goal text |
| `--auto` flag | Force Orchestrator regardless of goal text |

Print a banner on every invocation: `[autoresearch] mode: classic | orchestrator | wizard`.

## Subcommands

| Command | Does | Default Iterations |
|---|---|---|
| `/autoresearch` | Iterate against a metric: modify → verify → keep/discard | 25 |
| `/autoresearch_plan` | Convert a goal into validated Scope, Metric, Verify config | N/A |
| `/autoresearch_debug` | Hunt bugs: hypothesize → test → falsify → repeat | 15 |
| `/autoresearch_fix` | Crush errors one-by-one until zero remain | 20 |
| `/autoresearch_security` | STRIDE + OWASP audit with red-team personas | 15 |
| `/autoresearch_ship` | Ship through 8 phases: checklist → dry-run → deploy → verify | N/A |
| `/autoresearch_scenario` | Generate edge cases across 12 dimensions | 20 |
| `/autoresearch_predict` | 5 expert personas debate before implementation | N/A |
| `/autoresearch_learn` | Scout codebase → generate docs or wiki → validate → fix loop | 10 |
| `/autoresearch_reason` | Adversarial debate with blind judges until convergence | 8 |
| `/autoresearch_probe` | 8 personas interrogate requirements until saturation | 15 |
| `/autoresearch_improve` | Research ICP challenges, discover improvements, generate PRDs | 15 |
| `/autoresearch_evals` | Analyze iteration results: trends, plateaus, regressions | N/A |
| `/autoresearch_regression` | Regression stability gate: baseline vs candidate, verdict STABLE/UNSTABLE | N/A |

## Universal Flags

| Flag | Applies To | Purpose |
|---|---|---|
| `Iterations: N` | All looping | Set iteration count |
| `Iterations: unlimited` | All looping | Opt-in unbounded |
| `--evals` | All looping | Mid-loop checkpoints + final summary |
| `--evals-interval N` | All looping | Override checkpoint frequency |
| `--chain <targets>` | All | Sequential handoff after completion |
| `--<subcommand>` | All | Shorthand for `--chain <subcommand>` |
| `--dry-run` | Orchestrator | Print derived config + planned pipeline; no execution |
| `--max-cycles N` | Orchestrator | Hard ceiling on orchestration cycles (default 50) |
| `--classic` | Bare `/autoresearch` | Force Classic metric-loop mode |
| `--auto` | Bare `/autoresearch` | Force Orchestrator mode |

## Orchestrator

Activated when a plain-language goal is given without `Metric:`/`Verify:`. Classifies the goal into a **Goal archetype** — see `references/orchestrator-routing.md` for the archetype table and router decision table.

**Two modes based on archetype:**
- **Orchestration loop** — predicate-bearing archetypes (ship-ready, optimize-metric, fix-broken, harden, build-feature, explore). Goal has a mechanical Success predicate; the loop runs until that predicate is met.
- **Single-pass dispatch** — subjective/terminal archetypes (document, what-to-build, decide-design). Routes once to the fitting subcommand (learn / improve / reason), lets it self-terminate, then reports. No loop, no Plateau, no ship gate.

### Orchestration Loop Steps

Backed by `scripts/orchestrate.sh` (deterministic seam — all routing logic lives there). Subcommands exposed: `classify`, `next-hop`, `units`, `plateau`, `screen-cmd`, `verdict`, `validate-state`, `screen-state-predicate`.

1. **Classify** — `scripts/orchestrate.sh classify "<goal>"` → archetype label + mode.
2. **Derive predicate** — reuse `plan` logic to produce a concrete Success predicate: exact shell command + expected output. For `optimize-metric`, run the full plan/wizard derivation internally.
3. **Confirm** — ONE `question` showing: archetype, mode, concrete predicate (command + expected output), terminal choice (stop-at-verified vs proceed-to-ship). Misclassifications are caught here, not mid-run.
4. **Round-0 dry-run** — prove the predicate command runs and returns a value; safety-screen every derived command via `screen-cmd`; print projected cycle budget. Stop here if `--dry-run`.
5. **Loop** until predicate satisfied:
   a. Assess state via cheap signals (last `handoff.json`, regression verdict, error count) + affected-test verify.
   b. `scripts/orchestrate.sh next-hop orchestrator-state.json` → next subcommand.
   c. Run subcommand (its own bounded inner loop).
   d. Record per-hop outcome ∈ {progressed, no-op, failed, blocked}.
   e. Fold hop's `handoff.json` into `orchestrator-state.json`.
   f. `scripts/orchestrate.sh units` → recompute **Units remaining**.
6. **Stop conditions** (checked after each hop):
   - Predicate met → ship gate (only if ship is in the pipeline) else `CONVERGED`.
   - `scripts/orchestrate.sh plateau orchestrator-state.json` → true → stop + report `PLATEAU`.
   - Cycles > ceiling (default 50, override `--max-cycles N`) → stop + report `CEILING`.
   - Hop outcome `blocked`/`failed` with no alternative route → checkpoint + stop + report `BLOCKED`.

### Orchestrator State

`orchestrator-state.json` — orchestrator-owned, additive. Tracks: goal, archetype, predicate, terminal-choice, `units_remaining` history, cycle count, per-hop pipeline log with outcomes, current incumbent. Each hop's `handoff.json` is unchanged (single-hop bridge); the orchestrator reads it and folds it in. Two clearly-owned state objects, no overlap.

### Orchestrator Safety Invariants

- **Never auto-approve ship/deploy/push.** The orchestrator never passes `--auto` to `ship`; deploy always requires explicit user approval.
- **Data-migration behind anchored DB-URL allowlist.** Reuses regression's allowlist — host must be `localhost`/`127.0.0.1`/container hostname, or database name carries `_test`/`_ci` suffix. Bare substring match does not qualify. Anything else refused.
- **screen-cmd on every derived command** — run before the loop starts AND on every command read from a persisted state file on resume. Persisted commands are never trusted; resume re-screens the pinned predicate via `screen-state-predicate` and refuses on `refuse`.
- **No un-screened commands mid-loop.** The autonomous loop cannot introduce new shell commands that bypass `screen-cmd`.
- **Predicate pinned, not re-derived.** Round-0 writes the derived Success predicate verbatim into `orchestrator-state.json`; every cycle and every resume reuses that exact string so "done" is reproducible across runs.
- **Validate the ledger before routing.** `validate-state` gates `orchestrator-state.json` (required fields + coarse types); a malformed ledger is not trusted to route from.
- **Independent verify before convergence.** High-impact changes accepted on the working signal set `pending_verify`; `next-hop` routes to a `verify` hop (held-out / adversarial check) before `DONE` or ship. The verify hop never auto-approves ship.
- **Unknown-units cycles excluded from Plateau counter.** A cycle where `units` returns `unknown` (e.g. runner crash) is not counted as zero-progress; repeated `unknown` routes to `BLOCKED`.
