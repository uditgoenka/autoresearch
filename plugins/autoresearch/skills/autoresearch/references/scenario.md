# Scenario

Use for `autoresearch:scenario`.

Setup gate:
- Require a seed `Scenario` and a `Domain`.

Flow:
1. Parse the seed situation.
2. Decompose it across happy path, failure, abuse, scale, concurrency, permissions, recovery, and related dimensions.
3. Generate concrete scenarios.
4. Deduplicate and classify them.
5. Expand useful scenarios into edge cases and derivatives.
6. Log everything in a structured results file.

Outputs:
- `scenario/{YYMMDD}-{HHMM}-{slug}/scenarios.md`
- `scenario/{YYMMDD}-{HHMM}-{slug}/edge-cases.md`
- `scenario/{YYMMDD}-{HHMM}-{slug}/scenario-results.tsv`
