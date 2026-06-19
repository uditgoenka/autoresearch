---
name: autoresearch:regression
description: "Layered regression stability gate: capture baseline behavior on the base ref, diff the candidate, verdict STABLE/UNSTABLE before you push"
argument-hint: "[Base: <ref>] [Scope: <glob>] [--select auto|full|affected] [--samples N] [--noise-band %] [--matrix] [--max-runs N] [--baseline-cache] [Baseline: <prebuilt-ref>] [--probe|--no-probe|--probe deep] [--predict --reason --debug --fix --fix-cycles N --evals --evals-interval N --chain]"
---

EXECUTE IMMEDIATELY.

A regression is a **green→red transition ONLY**. The gate orchestrates the project's OWN test/bench/snapshot/migrate commands (it is a protocol, not a bundled framework), captures baseline behavior in an isolated git worktree, re-runs the candidate, and reports a tiered ship/no-ship verdict.

## Parse Arguments

Extract from $ARGUMENTS:
- `Base:` or `--base` — base ref to diff against. Default: `git merge-base HEAD main` (else `main`/`master`).
- `Scope:` or `--scope` — file globs limiting the change surface.
- `--select auto|full|affected` — test selection (default `auto`). `auto` = use the detected affected-test mapper if available, else FULL suite. Never a silent subset.
- `--samples N` — SCORE samples/side (default 7). `--noise-band %` — perf tolerance (default 5%).
- `--matrix` — opt-in matrix axis (OFF by default). `--max-runs N` — ceiling (default 200).
- `--baseline-cache` (default on) — reuse `baseline/<full-sha>/` by SHA. `Baseline: <prebuilt-ref>` — bypass capture.
- `--probe` (default) / `--probe deep` / `--no-probe`.
- `--predict --reason --debug --fix --fix-cycles N --evals --evals-interval N --chain <targets>` and `--<sub>` shorthand.
- `Iterations:` — repeat-axis count for `--select`/repeat sweeps.

## Setup / Probe-on-launch

1. Auto-detect per-dimension verify commands: `package.json` scripts, `Makefile`, `nx`, migrate config, bench/snapshot/size scripts.
2. AskUserQuestion (single batch) to confirm detected commands + base ref + which dimensions to run.
3. **Auto-skip probe** when CI / no-TTY / `--mode autonomous` / complete-config / chained-handoff — log the inferred config instead of asking.

## Classification Phase (first-class, before any differential)

Establish the baseline green-set per dimension, then tag each unit. Match by **test-id first, then path**.

| State | Meaning | Gated? |
|---|---|---|
| `regression-eligible` | green on baseline | YES — only green→red counts |
| `pre-existing` | red→red (already failing) | no — excluded |
| `new-coverage` | absent→red (brand-new test) | no — new coverage, ungated |
| `flaky` | nondeterministic on baseline | no — routed to flakiness SCORE |
| `baseline-unavailable` | dimension never green | no — advisory only |

**Core invariant: red→red, absent→red, and flake→red are NOT regressions.** Run flakiness N× on **both** baseline and candidate; a candidate failure inside the baseline flake-envelope routes to flakiness SCORE, never to a regression. `5/5 green ≠ non-flaky` — detection probability is `1−(1−p)^n` (≈23% at p=5%, n=5); print it.

## Baseline Capture

`git worktree add --detach <full-sha>` (detached SHA — avoids "branch already checked out" when Base==HEAD) → `baseline/<full-sha>/`; `--baseline-cache` reuses by SHA. Then per worktree: `git submodule update --init` + dependency install (lockfile is SHA-pinned so the cache stays sound). Per-dimension **setup tiers**: api-contract = file-diff, no build; functional / integration-e2e / data-migration = full env. On completion or crash: `git worktree remove` + `git worktree prune`. Warn on concurrent index-lock contention. `Baseline: <prebuilt-ref>` bypasses capture.

## Dimension Registry (8)

| Dim | Tier | Compare | Key params |
|---|---|---|---|
| functional | HARD | baseline green-set vs candidate; new fail = regression | test cmd, globs |
| api-contract | HARD | schema/exports diff → breaking? | schema cmd, breaking ruleset |
| data-migration | HARD | default: up applies clean + idempotent re-apply + app boots/schema valid; schema/rowcount roundtrip opt-in | migrate cmds, fixture, allowlisted DB |
| integration-e2e | HARD | e2e green-set diff | e2e cmd |
| flakiness | SCORE | run N× on baseline + candidate, count nondeterministic | runs (def 5), flake-threshold |
| performance | SCORE | K **independent-process** samples/side, Mann-Whitney U AND effect beyond `max(noise-band%, k·stdev)`, report median delta | bench cmd, samples=7, noise-band=5%, k=2 |
| resource | SCORE | mem/bundle/size delta vs budget | size cmd, budget |
| visual-ui | SCORE | containerize render; default `maxDiffPixelRatio` + AA-detection; SSIM = per-page escalation | snapshot cmd, diff-threshold, mask regions |

`--select auto` mapper (`jest --findRelatedTests` fed the changed-file list; `nx affected` project-graph) is **best-effort static-import** — blind to dynamic/runtime/global-setup couplings. The report names the mapper + its blind-spot caveat; a HARD STABLE earned on an affected subset prints "run `--select full` for high-stakes". FULL suite is the correctness default.

- **performance independence:** each sample = an independent process launch (warmups discarded), never an in-process iteration — autocorrelation/GC/thermal otherwise violate Mann-Whitney's independence assumption. At n=7 the test detects only ≳1σ regressions; raise `--samples` for tight gates.
- **data-migration guard:** opt-in. Before any migration the DB URL MUST pass an **anchored** allowlist — host is exactly `localhost` / `127.0.0.1` / a container or service hostname, OR the database name carries a `_test` / `_ci` suffix. A bare substring (e.g. `test` inside `latest`, `ci` inside `precision`) does **not** qualify. Anything else is refused — ephemeral only, never dev/prod — and even an allowlisted URL requires explicit user confirm before applying. Missing/absent down-migration = forward-only advisory, **never a finding**.

## Differential Loop (per dim × axis × run)

Run candidate verify vs baseline metric → compute `regressed` bool + 0-100 `subscore`. Axes: `diff` (default), `repeat N×`, `full`, `matrix` (opt-in). Log one TSV row per cell.

**--max-runs ceiling:** projected = dims × axes × samples × matrix-cells; if > `--max-runs` (default 200) → warn + require confirm (CI default = abort with message).

## Verdict

- Any HARD `regressed=true` with `classification=eligible` → **UNSTABLE** (green→red hard-blocks).
- Else `stability_score = Σ(weight × dim_subscore)` over SCORE dims that ran (flakiness .30 / performance .30 / resource .20 / visual .20, renormalized over present dims). **STABLE iff ≥ 95** (`REG_THRESHOLD`/weights overridable).
- Print the **score math** (per-dim contribution table) + declare **dims-ran vs UNAVAILABLE** — an UNAVAILABLE dimension is always listed, never silently passed.

Backed by `scripts/score-regression.sh verdict <results.tsv>` (exit 0 STABLE / 1 UNSTABLE).

## Hunter (root cause)

On a confirmed HARD regression, auto-engage. Bisect (reuse `debug`) ONLY when the failing case passes a **3/3 reproducibility gate**. SCORE / non-deterministic regressions → differential root-cause + optional `--reason` / `--predict`, no bisect. Non-reproducible → "manual triage" finding.

## --fix Re-gate

`--fix` repairs blocking regressions, max **3 cycles** (`--fix-cycles N`). Each cycle MUST strictly shrink the blocking-set else STOP "fix not converging". Intermediate re-gate scopes to failing+touched dims; the final cycle runs the full battery. No HARD-gate bypass.

## Output

`autoresearch/regression-{YYMMDD}-{HHMM}/` → `regression-results.tsv`, `stability-report.md`, `dimensions/<dim>.md`, `baseline/`, `evals-summary.md` (if `--evals`), `handoff.json`.

TSV header: `# metric_direction: higher_is_better` then
`iteration\ttimestamp\tdimension\taxis\ttier\tclassification\tbaseline\tcandidate\tdelta\tregressed\tsubscore\tseverity\tstatus\tfile_line\tdescription`.

## Eval Checkpoint (--evals flag)

Interval = floor(max_runs / 3), min 1 (fixed 10 if unbounded); override `--evals-interval N`. Every interval, analyze the results TSV; print trend (up/flat/down) + one-line recommendation. Plateau 3+ checkpoints → recommend early stop. At end → full summary to `evals-summary.md`.

## Chain Handoff

Write `handoff.json` to the output directory: version "2.1.0", source "regression", timestamp,
`status` ∈ family enum {COMPLETE, CONVERGED, SATURATED, BOUNDED, USER_INTERRUPT, ERROR} (backward-compat with evals/ship consumers),
`verdict` ∈ {STABLE, UNSTABLE, BASELINE_UNAVAILABLE} + `regression_state` ∈ {REGRESSION_FOUND, REGRESSION_FIXED, none} — `ship` reads `verdict` for the deploy-gate,
`results_tsv` path, `findings` = blocking regressions (dim, severity, file_line, classification), `config`{base, scope, dims, axes, verdict-math}.

If `--fix` → chain to fix automatically. Invoke next `--chain` target in order; propagate `--evals`. Canonical combo: `--predict --evals --fix --ship` = predict → gate → (hunter on HARD) → fix(≤3) → re-gate → ship iff STABLE (deploy still needs explicit approval).

## Safety

Verify-command screen (no `rm -rf` / `curl|sh`); worktree cleanup + prune on crash; data-migration refuses any non-allowlisted DB URL; probe auto-skips non-interactively; chained `ship` never auto-deploys.
