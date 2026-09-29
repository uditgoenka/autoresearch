---
name: autoresearch:fix
description: "Crush errors one-by-one until zero remain: tests, types, lint, build"
argument-hint: "[Target: <cmd>] [Scope: <glob>] [Guard: <cmd>] [Iterations: N] [--evals] [--from-debug]"
---

EXECUTE IMMEDIATELY.

## Parse Arguments

Extract from $ARGUMENTS:
- `Target:` or `--target` — command that shows errors (e.g., `npm test`, `tsc --noEmit`)
- `Scope:` or `--scope` — file globs to modify
- `Guard:` or `--guard` — safety command (must always pass)
- `Iterations:` or `--iterations` — default 20. "unlimited" for unbounded.
- `--from-debug` — read handoff.json from previous debug run
- `--category` — filter: test, type, lint, build
- `--evals`, `--evals-interval N`, `--chain`

## Setup (if required context missing)

If Target and Scope both missing:
1. Auto-detect failures: run test suite, type checker, linter, build
2. Present results via request_user_input (single batched call):
   Q1 (Fix What): "Found [N] test failures, [M] type errors, [K] lint errors. Fix what?" — everything, only tests, only types, only lint
   Q2 (Guard): "Safety command that must always pass?" — npm test, tsc, npm run build, skip
   Q3 (Scope): "Which files can I modify?" — suggested globs from error locations + all
   Q4 (Launch): "Ready?" — fix until zero, fix with limit, cancel
If all provided → skip setup.
If --from-debug → read handoff.json for scope and findings.

## Precondition Checks

Verify: git repo exists, clean working tree, no lock files, no detached HEAD. Fail fast on critical issues.

## Establish Baseline (Iteration 0)

1. Run Target command → count errors (metric = error count, direction = lower_is_better)
2. Record baseline in TSV
3. Create output directory: `autoresearch/fix-{YYMMDD}-{HHMM}/`
4. TSV header: `# metric_direction: lower_is_better\niteration\ttimestamp\terror_type\terror_fixed\tcommit\tmetric\tdelta\tguard\tstatus\tdescription`

## Iteration Loop (until zero errors or max_iterations)

### Phase 1: Review
- Read results TSV + git log
- Run Target to get current error list
- If error count == 0 → exit loop (SUCCESS)

### Phase 2: Prioritize
Order: crash/fatal → test failures → type errors → lint → warnings.
Within category: easiest first (single-file fixes before cross-file).

### Phase 3: Fix ONE Thing
- Pick the highest-priority error
- Make ONE focused fix (atomic — addresses exactly one error)
- Record error type and which error was fixed

### Phase 4: Commit
- Stage and commit: `experiment: fix {error_type} — {description}`

### Phase 5: Verify
- Run Target → count errors → compute delta
- Expected: error count decreased by 1 or more

### Phase 6: Guard
- If Guard set → run Guard. If fails → revert.

### Phase 7: Decide
- **keep** — error count decreased AND guard passes
- **keep (reworked)** — fix needed adjustment, second attempt worked
- **discard** — error count same/increased → `git revert HEAD --no-edit`
- **crash** — target/guard command failed → revert
- **hook-blocked** — git hook blocked the commit
- **metric-error** — target output not parseable → revert

### Phase 8: Log
Append row: iteration, timestamp, error_type, error_fixed, commit/-, metric (error count), delta, guard, status, description

### Eval Checkpoint
If --evals: check if current_iteration % interval == 0 → run checkpoint analysis.

### Bounded Check
If bounded: current_iteration >= max_iterations → exit loop, print summary.

## Summary

Print: total errors fixed, remaining errors, error types distribution, fix success rate.

## Eval Checkpoint (--evals flag)

If --evals present:
- Compute interval: floor(max_iterations / 3), min 1. Fixed 10 if unbounded. Override: --evals-interval N.
- Every {interval} iterations, pause and analyze current results TSV.
- Print: `--- Eval Checkpoint (iterations {X}-{Y}) ---\nErrors: {start} → {end} ({delta}) | Kept: {n}/{total} | Trend: {up/flat/down}\n{one-line recommendation}\n---`
- If plateau 3+ checkpoints → recommend early stop.
- At loop end → full evals summary to evals-summary.md in output directory.

## Chain Handoff

After completion, write handoff.json to output directory: version "2.1.0", source "fix", timestamp, status (COMPLETE|USER_INTERRUPT|BOUNDED|ERROR), results_tsv path, findings = unfixed errors, config{target, scope, guard}.
Invoke next target in --chain order. Propagate --evals flag.
