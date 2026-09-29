---
name: autoresearch:evals
description: "Analyze iteration results: trends, plateaus, regressions, recommendations"
argument-hint: "[path/to/results.tsv] [--format text|json|md]"
---

EXECUTE IMMEDIATELY.

## Parse Arguments

Extract from $ARGUMENTS:
- Positional path to a specific TSV file
- `--format` — output format: text (default console), json, md (markdown file)
- `--compare <path>` — (v2.2.0 placeholder, not yet implemented)

## Input Discovery

1. If path provided → use that TSV directly
2. If no path → scan current directory + `autoresearch/*/` for `*-results.tsv` files
3. If multiple found → request_user_input: "Which results to analyze?" — list found files
4. If none found → request_user_input: "Provide path to results TSV"
5. Also scan project root for v2.0.03 legacy TSV files (backward compat)

## Parse TSV

1. Read line 1: extract `# metric_direction: higher_is_better|lower_is_better` comment
   - If missing → infer from column names (metric/error_count → guess, or ask user)
2. Read line 2: header row → detect available columns
3. Read remaining lines: data rows
4. Handle missing `timestamp` column gracefully (v2.0.03 compat)

## Column Detection & Analysis

Activate analysis based on columns present in header:

| Column | Analysis |
|---|---|
| `metric` | Trend direction, plateau detection (3+ flat iterations), diminishing returns, biggest single-iteration jumps |
| `delta` | Per-iteration efficiency, cumulative improvement, effort-to-gain ratio |
| `status` | Keep/discard rate, crash frequency, success streaks, failure clusters, longest winning streak |
| `guard` + `guard-metric` | Guard failure rate, metric-improved-but-guard-failed analysis |
| `severity` | Severity distribution (critical/high/medium/low/info), critical discovery rate per iteration |
| `hypothesis` + `status` | Confirmation rate, investigation efficiency, most productive techniques |
| `commit` | File hotspot analysis (cross-ref with `git diff` for kept commits), change size correlation |
| `technique` | Technique effectiveness ranking |
| `dimension` | Dimension coverage completeness (X/12) |
| `candidate_label` + `judge_verdict` | Convergence speed, oscillation count |
| `error_type` | Error category distribution, fix rate per category |
| `classification` | New vs extension vs duplicate ratio, saturation curve |
| `convergence_count` | Convergence trajectory |

Unknown columns: report presence but skip analysis. Forward-compatible with future subcommands.

## Report Structure

```
## Evals Summary — {subcommand} ({N} iterations)

### Key Metrics
- Total iterations: N | Kept: X | Reverted: Y | Revert rate: Z%
- Starting metric: A | Final metric: B | Improvement: C%

### Trend Analysis
- Metric progression: [description of trajectory]
- Plateau detected at iteration N (metric stable for M iterations)
- Biggest win: iteration X (+delta, description)
- Biggest loss: iteration Y (-delta, description)
- Diminishing returns: [after iteration N, average delta dropped below threshold]

### Patterns
- What types of changes succeeded: [extracted from descriptions of kept iterations]
- What types of changes failed: [extracted from descriptions of discarded iterations]
- File hotspots: [files changed most in kept iterations, if commit data available]
- Technique effectiveness: [ranked by confirmation rate, if technique column present]

### Recommendation
- [continue / stop / change strategy — based on trend, plateau, revert rate]
- [specific actionable suggestion based on pattern analysis]
```

## Output

- Console: structured report (30-50 lines)
- If `--format md` → write `evals-summary.md` in same directory as input TSV
- If `--format json` → write `evals-summary.json` with structured data

## Mid-Loop Checkpoint Protocol (for --evals flag in other commands)

This section documents the checkpoint protocol that looping commands embed:

- **Adaptive interval:** `floor(max_iterations / 3)`, minimum 1. Fixed 10 for unbounded. Override: `--evals-interval N`.
- **Checkpoint format (5 lines max):**
  ```
  --- Eval Checkpoint (iterations {X}-{Y}) ---
  Metric: {start} → {end} ({delta}) | Kept: {n}/{total} | Trend: {up/flat/down}
  {one-line recommendation}
  ---
  ```
- **Early stop recommendation:** if plateau detected for 3+ consecutive checkpoints
- **Final summary:** at loop end, produce full evals report to console + evals-summary.md

### Adaptive Interval Examples

| Subcommand | Default Iterations | Interval | Checkpoints At |
|---|---|---|---|
| reason | 8 | 2 | 2, 4, 6, 8 |
| learn | 10 | 3 | 3, 6, 9, final |
| debug/security | 15 | 5 | 5, 10, 15 |
| fix/scenario | 20 | 6 | 6, 12, 18, final |
| core | 25 | 8 | 8, 16, 24, final |
| unbounded | unlimited | 10 | every 10 |

## Backward Compatibility

- v2.0.03 TSV files: column names preserved, `timestamp` absence handled gracefully
- Fuzzy column matching: `metric_value` → `metric`, `error_count` → `metric`
- Files in project root (not `autoresearch/` subdirectory) → discovered during scan
- v2.0.03 status values all supported: baseline, keep, keep (reworked), discard, crash, no-op, hook-blocked, metric-error
