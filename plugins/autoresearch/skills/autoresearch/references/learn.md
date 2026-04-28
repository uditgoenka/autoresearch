# Learn

Use for `autoresearch:learn`.

Setup gate:
- Require a `Mode` and enough scope context to know what to document.

Modes:
- `init`
- `update`
- `check`
- `summarize`

Flow:
1. Scout the repo or delta.
2. Analyze the architecture and docs surface.
3. Map code areas to docs.
4. Generate or update docs.
5. Validate.
6. Run the fix loop unless `--no-fix` is set.
7. Finalize and log.

Outputs:
- `learn/{YYMMDD}-{HHMM}-{slug}/summary.md`
- `learn/{YYMMDD}-{HHMM}-{slug}/validation-report.md`
- `learn/{YYMMDD}-{HHMM}-{slug}/learn-results.tsv`
