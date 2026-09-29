---
name: autoresearch:scenario
description: "Generate edge cases across 12 dimensions from a seed scenario"
argument-hint: "[Scenario: <text>] [Domain: <type>] [Scope: <glob>] [Iterations: N] [--depth <level>] [--focus <area>] [--evals]"
---

EXECUTE IMMEDIATELY.

## Parse Arguments

Extract from $ARGUMENTS:
- `Scenario:` — seed scenario description (or full $ARGUMENTS text if no keyword)
- `Domain:` or `--domain` — web, mobile, API, CLI, data pipeline, infrastructure
- `Scope:` or `--scope` — file globs for codebase context
- `Focus:` or `--focus` — specific dimension to prioritize
- `--depth` — shallow (10), standard (20), deep (40+)
- `--format` — markdown (default), json, gherkin
- `Iterations:` or `--iterations` — default 20. "unlimited" for unbounded.
- `--evals`, `--evals-interval N`, `--chain`, `--<subcommand>`

## Setup (if Scenario or Domain missing)

request_user_input (single batch):
  Q1 (Scenario): "Describe the feature/flow to explore"
  Q2 (Domain): "What domain?" — web app, mobile app, API, CLI, data pipeline, infrastructure
  Q3 (Scope): "Which files for context?" — suggested globs + entire codebase
  Q4 (Depth): "How deep?" — quick (10), standard (20), deep (40+), unlimited
If all provided → skip.

## 12 Dimensions

| # | Dimension | Explores |
|---|---|---|
| 1 | Happy path | Normal successful flows |
| 2 | Validation | Input boundaries, types, formats |
| 3 | Permissions | Auth, roles, access control |
| 4 | Concurrency | Race conditions, deadlocks, ordering |
| 5 | State | Invalid transitions, corruption |
| 6 | Scale | High volume, large data, many users |
| 7 | Failure | Network errors, timeouts, partial failures |
| 8 | Security | Injection, abuse, bypass attempts |
| 9 | Integration | Third-party failures, API contract violations |
| 10 | Data | Null, empty, unicode, injection, overflow |
| 11 | UX | Confusion, misuse, accessibility |
| 12 | Recovery | Retry, rollback, idempotency |

## Establish Baseline

1. Read seed scenario + codebase context
2. Create output directory: `autoresearch/scenario-{YYMMDD}-{HHMM}/`
3. TSV header: `iteration\ttimestamp\tscenario\tdimension\tclassification\tseverity\tdescription`
4. No metric_direction comment (exploration, not optimization)

## Iteration Loop

### Phase 1: Review
- Read results TSV, check dimension coverage
- Identify underexplored dimensions
- If --focus → prioritize that dimension

### Phase 2: Generate
- Pick next dimension (round-robin, or priority if --focus)
- Generate 3-5 specific scenarios for this dimension
- Each: title, dimension, classification, severity, description

### Phase 3: Classify
- **new** — genuinely novel edge case
- **extension** — builds on previously found scenario
- **duplicate** — already covered (skip, don't log)

### Phase 4: Log
Append new/extension scenarios to TSV. Skip duplicates.
Severity: critical/high/medium/low.

### Phase 5: Saturation Check
If 3 consecutive iterations produce only duplicates → dimension saturated, move to next.
If ALL dimensions saturated → early stop.

### Eval Checkpoint
If --evals: check if current_iteration % interval == 0 → run checkpoint.

### Bounded Check
If bounded: current_iteration >= max_iterations → exit loop.

## Output

- Write `scenarios.md` (organized by dimension, severity-ranked within each)
- Write `edge-cases.md` (flat severity-ranked list)
- `scenario-results.tsv`

## Summary

Print: total scenarios (new/extension/duplicate), dimension coverage (X/12 explored), severity distribution.

## Eval Checkpoint (--evals flag)

If --evals present:
- Compute interval: floor(max_iterations / 3), min 1. Fixed 10 if unbounded.
- Print: `--- Eval Checkpoint (iterations {X}-{Y}) ---\nNew scenarios: {n} | Dimensions covered: {x}/12 | Saturation: {status}\n{recommendation}\n---`
- If 3+ checkpoints with mostly duplicates → recommend early stop.
- At loop end → full evals summary to evals-summary.md.

## Chain Handoff

After completion, write handoff.json: version "2.1.0", source "scenario", timestamp, status, results_tsv path, findings = scenarios by severity, config{scenario, domain, scope}.
Invoke next target in --chain order. Propagate --evals flag.
