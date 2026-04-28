# Reason

Use for `autoresearch:reason`.

Setup gate:
- Require a `Task`, `Domain`, and the intended reasoning mode.

Flow:
1. Generate candidate answers.
2. Critique them adversarially.
3. Synthesize improved candidates unless `--no-synthesis` is set.
4. Blind-judge the candidates.
5. Track convergence.
6. Stop when the convergence threshold or iteration limit is reached.
7. If `--chain` is present, hand off the winning output.

Outputs:
- `reason/{YYMMDD}-{HHMM}-{slug}/summary.md`
- `reason/{YYMMDD}-{HHMM}-{slug}/lineage.md`
- `reason/{YYMMDD}-{HHMM}-{slug}/handoff.json`
