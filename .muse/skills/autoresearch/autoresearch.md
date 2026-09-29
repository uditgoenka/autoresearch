---
name: autoresearch
description: "Autonomous iteration loop: modify, verify, keep/discard against any metric"
argument-hint: "[Goal: <text>] [Scope: <glob>] [Metric: <text>] [Verify: <cmd>] [Guard: <cmd>] [Iterations: N] [--evals]"
---

EXECUTE IMMEDIATELY — do not deliberate before reading this protocol.

## Parse Arguments

Extract from $ARGUMENTS:
- `Goal:` — what to improve
- `Scope:` or `--scope` — file globs
- `Metric:` — what to measure
- `Direction:` — higher_is_better (default) or lower_is_better
- `Verify:` — shell command that outputs a number
- `Guard:` — optional safety command (must always pass)
- `Iterations:` or `--iterations` — integer N for bounded mode (default: 25). "unlimited" for unbounded.
- `--evals` — enable mid-loop checkpoints
- `--evals-interval N` — checkpoint frequency override
- `--chain <targets>` — comma-separated downstream commands

## Setup (if required context missing)

If Goal, Scope, Metric, or Verify missing → use request_user_input (single batched call):
  Q1 (Goal): "What do you want to improve?"
  Q2 (Scope): "Which files?" — suggest globs from project
  Q3 (Metric+Verify): "How to measure? Provide a shell command that outputs a number"
  Q4 (Guard): "Safety command that must always pass?" — options: test cmd, build cmd, skip
If ALL provided inline → skip setup, proceed directly.

## Precondition Checks

1. Verify git repo exists (`git rev-parse --git-dir`)
2. Check clean working tree (`git status --porcelain`) — warn if dirty
3. Check for stale lock files, detached HEAD
4. If Guard set → run Guard to establish guard baseline
5. Fail fast on any critical issue. Warn on non-critical.

## Verify Safety Screen

Before first dry-run, screen Verify command for: rm -rf, fork bombs, curl|sh, embedded credentials, outbound writes. Block dangerous commands.

## Establish Baseline (Iteration 0)

1. Run Verify command → extract numeric metric
2. Record as iteration 0 in TSV: `0\t{timestamp}\t{commit}\t{metric}\t0.0\t{guard}\t-\tbaseline\tinitial state`
3. Create output directory: `autoresearch/loop-{YYMMDD}-{HHMM}/`
4. Write TSV header: `# metric_direction: {direction}\niteration\ttimestamp\tcommit\tmetric\tdelta\tguard\tguard-metric\tstatus\tdescription`

## Iteration Loop

For each iteration (1 to max_iterations, or unbounded):

### Phase 1: Review (read git history as memory)
- Read last 10-20 lines of results TSV
- Run `git log --oneline -20` — see what worked/failed
- If last iteration was "keep" → run `git diff HEAD~1` to see what improved metric
- Identify: what worked, what failed, what's untried

### Phase 2: Modify
- Based on review, make ONE focused change to improve the metric
- Change must be atomic — one logical unit of work

### Phase 3: Commit
- Stage and commit with `experiment: {description}` prefix
- Record commit SHA

### Phase 4: Verify
- Run Verify command → extract new metric value
- Calculate delta from previous iteration
- Metric improved (correct direction) → candidate for keep

### Phase 5: Guard (if configured)
- Run Guard command. If fails → revert regardless of metric improvement

### Phase 6: Decide
- **keep** — metric improved, guard passed → commit stays
- **discard** — metric worsened → `git revert HEAD --no-edit`
- **crash** — verify/guard command failed → `git revert HEAD --no-edit`
- **no-op** — no change made this iteration
- **hook-blocked** — git hook blocked the commit
- **metric-error** — verify output not a valid number → `git revert HEAD --no-edit`

### Phase 7: Log
Append row to TSV: iteration, timestamp, commit/-, metric, delta, guard status, guard-metric, status, description

### Eval Checkpoint
If --evals: check if current_iteration % interval == 0 → run checkpoint analysis.

### Bounded Check
If bounded: current_iteration >= max_iterations → exit loop, print summary.

## Summary (after loop ends)

Print: total iterations, kept/discarded counts, starting metric → final metric, improvement %, top 3 most effective changes.

## Eval Checkpoint (--evals flag)

If --evals present:
- Compute interval: floor(max_iterations / 3), min 1. Fixed 10 if unbounded. Override: --evals-interval N.
- Every {interval} iterations, pause and analyze current results TSV.
- Print: `--- Eval Checkpoint (iterations {X}-{Y}) ---\nMetric: {start} → {end} ({delta}) | Kept: {n}/{total} | Trend: {up/flat/down}\n{one-line recommendation}\n---`
- If plateau 3+ checkpoints → recommend early stop.
- At loop end → full evals summary to evals-summary.md in output directory.

## Chain Handoff

After completion, write handoff.json to output directory: version "2.1.0", source "loop", timestamp, status (COMPLETE|USER_INTERRUPT|BOUNDED|ERROR), results_tsv path, findings[], config{goal, scope, metric, direction, verify}.
Invoke next target in --chain order. Propagate --evals flag.
