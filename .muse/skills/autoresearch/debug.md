---
name: autoresearch:debug
description: "Hunt bugs with scientific method: hypothesize, test, falsify, repeat"
argument-hint: "[Scope: <glob>] [Symptom: <text>] [Iterations: N] [--fix] [--evals]"
---

EXECUTE IMMEDIATELY.

## Parse Arguments

Extract from $ARGUMENTS:
- `Scope:` or `--scope` — file globs to investigate
- `Symptom:` or `--symptom` — error message or behavior description
- `Iterations:` or `--iterations` — default 15. "unlimited" for unbounded.
- `--fix` — shorthand for `--chain fix`
- `--severity` — filter: critical, high, medium, low
- `--technique` — force specific technique
- `--evals`, `--evals-interval N`, `--chain`

## Setup (if required context missing)

If Scope and Symptom both missing:
1. Auto-scan: run tests, lint, typecheck to detect existing failures
2. request_user_input (single batch):
   Q1 (Issue): "What's the problem?" — hunt all bugs, specific error, failing tests, CI failure, performance
   Q2 (Scope): "Which files?" — suggested globs + entire codebase
   Q3 (Depth): "How deep?" — quick (5), standard (15), deep (30+), unlimited
   Q4 (After): "When bugs found?" — report only, find and fix (--chain fix), chain to other, ask each time
If all provided → skip.

## Investigation Techniques

| Technique | When to Use |
|---|---|
| Binary search | Know when it worked, find when it broke |
| Differential | Compare working vs broken state |
| Minimal reproduction | Simplify to smallest failing case |
| Trace | Follow execution path through code |
| Pattern search | Grep for known anti-patterns |
| Working backwards | Start from error, trace to root cause |

## Establish Baseline (before loop)

1. Auto-scan for failures if no symptom provided
2. Create output directory: `autoresearch/debug-{YYMMDD}-{HHMM}/`
3. TSV header: `# metric_direction: higher_is_better\niteration\ttimestamp\thypothesis\tstatus\ttechnique\tevidence\tfile_line`
4. Metric = cumulative confirmed findings count

## Iteration Loop

### Phase 1: Review Context
- Read results TSV (past findings)
- Assess: what's been tested, what vectors remain
- If no hypotheses left → early stop

### Phase 2: Hypothesize
- Form ONE specific, falsifiable hypothesis
- Format: "I hypothesize that {X} because {evidence}. Test by {Y}."
- Hypothesis must be testable and different from all previous

### Phase 3: Investigate
- Apply appropriate technique for this hypothesis
- Read relevant code, run targeted tests, check logs
- Collect evidence (file:line references required)

### Phase 4: Classify
- **confirmed** — hypothesis correct, bug found with evidence
- **disproven** — hypothesis wrong, evidence against it
- **inconclusive** — can't prove or disprove, needs different approach

### Phase 5: Log
Append to TSV: iteration, timestamp, hypothesis, status, technique, evidence, file_line

### Eval Checkpoint
If --evals: check if current_iteration % interval == 0 → run checkpoint analysis.

### Bounded Check
If bounded: current_iteration >= max_iterations → exit loop, print summary.

## Summary

Print: total hypotheses tested, confirmed/disproven/inconclusive counts, all confirmed bugs with severity and file:line.

## Eval Checkpoint (--evals flag)

If --evals present:
- Compute interval: floor(max_iterations / 3), min 1. Fixed 10 if unbounded. Override: --evals-interval N.
- Every {interval} iterations, pause and analyze current results TSV.
- Print: `--- Eval Checkpoint (iterations {X}-{Y}) ---\nFindings: {confirmed} confirmed | Trend: {up/flat/down}\n{one-line recommendation}\n---`
- If plateau 3+ checkpoints (no new confirmed) → recommend early stop.
- At loop end → full evals summary to evals-summary.md in output directory.

## Chain Handoff

After completion, write handoff.json to output directory: version "2.1.0", source "debug", timestamp, status (COMPLETE|USER_INTERRUPT|BOUNDED|ERROR), results_tsv path, findings = confirmed bugs with severity + file:line, config{scope, symptom}.
If --fix flag → chain to fix automatically.
Invoke next target in --chain order. Propagate --evals flag.
