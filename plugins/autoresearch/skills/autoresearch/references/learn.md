# Learn

Use for `autoresearch:learn`.

Setup gate:
- Require a `Mode` and enough scope context to know what to document.

Modes:
- `init`
- `update`
- `check`
- `summarize`
- `wiki` — generates navigable `wiki/` knowledge base (architecture diagrams, module deep dives, glossary, onboarding)

Flow:
1. Scout the repo or delta.
2. Analyze the architecture and docs surface.
3. Map code areas to docs (or Phase 3w: module discovery for wiki mode).
4. Generate or update docs (or Phase 4w: wiki content generation for wiki mode).
5. Validate.
6. Run the fix loop unless `--no-fix` is set.
7. Finalize and log.

Wiki-specific flags:
- `--modules <list>` — override module auto-detection
- `--force` — regenerate all, ignore manifest

Outputs:
- `learn/{YYMMDD}-{HHMM}-{slug}/summary.md`
- `learn/{YYMMDD}-{HHMM}-{slug}/validation-report.md`
- `learn/{YYMMDD}-{HHMM}-{slug}/learn-results.tsv`
