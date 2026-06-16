---
name: autoresearch_learn
description: "Scout codebase and auto-generate docs — or a navigable wiki knowledge base — with validation-fix loop"
argument-hint: "[Mode: <init|update|check|summarize|wiki>] [Scope: <glob>] [Iterations: N] [--depth <level>] [--modules <list>] [--force] [--evals]"
---

EXECUTE IMMEDIATELY.

## Parse Arguments

Extract from $ARGUMENTS:
- `Mode:` or `--mode` — init (create from scratch), update (refresh existing), check (validate), summarize (brief overview), wiki (navigable knowledge base)
- `Scope:` or `--scope` — file globs to document
- `Depth:` or `--depth` — overview, standard, comprehensive
- `--file <path>` — specific file to document
- `--scan` — force fresh codebase scout
- `--topics` — comma-separated focus topics
- `--modules <list>` — wiki mode: comma-separated module names/paths overriding auto-detection
- `--force` — wiki mode: regenerate all pages from scratch, ignore existing manifest
- `--no-fix` — validate only, don't auto-fix issues
- `--format` — markdown (default), json, rst
- `Iterations:` or `--iterations` — default 10. "unlimited" for unbounded.
- `--evals`, `--evals-interval N`, `--chain`, `--<subcommand>`

## Setup (if Mode or Scope missing)

question (single batch):
  Q1 (Mode): "What to do?" — init (generate docs), update (refresh), check (validate), summarize (overview), wiki (knowledge base)
  Q2 (Scope): "Which files?" — suggested globs + entire codebase
  Q3 (Depth): "How detailed?" — overview only, standard, comprehensive
  Q4 (Topics): "Focus on?" — architecture, API, database, testing, all
If all provided → skip.

## Establish Baseline

1. Scout codebase: file tree, imports/exports, existing docs
2. Identify documentation gaps (undocumented files, outdated docs, missing READMEs)
3. Create output directory: `autoresearch/learn-{YYMMDD}-{HHMM}/`
4. TSV header: `# metric_direction: higher_is_better\niteration\ttimestamp\tfile_documented\tvalidation_status\tissues_found\tissues_fixed\tdescription`
5. Metric = files with valid documentation (higher is better)

## Summarize Mode (no loop)

If mode == summarize:
- One-shot: scan codebase → produce structured summary
- Write summary.md to output directory
- Skip iteration loop entirely

## Wiki Mode (no per-file loop)

If mode == wiki: reuse Scout (Phase 1) + Analyze output, then generate a navigable `wiki/` knowledge base. Skip the init/update/check loop. Metric = `pages_generated / pages_planned × 100` (from manifest); size target 300 lines/page.

### Module Discovery (priority order)
1. `--modules` flag (explicit override, always wins; every path must resolve inside project root — reject escapes)
2. Monorepo workspaces (`workspaces` in package.json, Cargo workspace members, `pnpm-workspace.yaml`)
3. Per-directory project files (`pyproject.toml`, `Cargo.toml`, `go.mod`, `*.csproj`)
4. Heuristic: dirs with 3+ source files (code extensions only — .ts/.py/.go/.rs/.java/.rb/.swift/.kt/.c/.cpp/.cs; tests count, config/markdown don't); nested dirs roll up to nearest module ancestor

Cap 10 modules. If >10, group by top-level dir; if a group has >5 sub-modules, expand and take 10 largest by file count.

### Plan (write-ahead)
1. `mkdir -p wiki/modules/`; append `wiki-manifest.json` to `.gitignore` if absent
2. Write `wiki-manifest.json` BEFORE generating — `{version:"1", generated_at, generation_status:"in_progress", modules_detected:[…], pages_planned:N, pages:{ "wiki/architecture.md":{status:"pending",type:"architecture"}, "wiki/modules/<name>.md":{…"module"}, "wiki/glossary.md":{…}, "wiki/onboarding.md":{…}, "wiki/index.md":{…} }}`
3. Write stub `wiki/index.md` listing every planned page as `[pending]` (navigation survives interruption)
4. Resume: if valid manifest exists → `--force` deletes it and regenerates all, else skip `"generated"` pages and only do `"pending"`. Corrupted manifest (invalid JSON, or missing `version`/`pages`) without `--force` → error directing user to `--force`.

### Generate (priority-first, one agent call per page, bounded context)
1. `architecture.md` — system overview from scout context. Up to 5 Mermaid diagrams, 3 types only (`graph TD`, `sequenceDiagram`, `classDiagram`); include one canonical example of each in the prompt; pick by signal.
2. Module pages (alphabetical) — per-module agent gets: (a) file listing, (b) first 50 lines of ≤10 key files (entry points → largest → alphabetical), (c) Phase 2 overview. Required sections: Overview, Key Files; optional: Patterns/API/Dependencies/Getting Started.
3. `glossary.md` — domain terms from class names, exports, types, comments; filter language keywords + stdlib; soft cap ~60-80, prioritize terms in 3+ files.
4. `onboarding.md` — reading order, env setup, first-contribution workflow, gotchas. Sources: dir structure, README/docs, manifests, entry-point sampling, `git log --since='6 months ago'` directory frequency (skip with note if not a git repo or >10s).
5. `index.md` — final pass: replace stub with real page descriptions + reading order.

### Per-page contract
- `generated_by: autoresearch` in YAML frontmatter
- ~300 lines/page (soft); Mermaid ≤15 nodes/diagram; forward-only cross-links, ≤10 per page

### Safety
- **Secrets (2-layer):** (1) prompt instructs "summarize config, never include verbatim values from .env/credentials or strings matching key/secret/token/password; extract env var *names* not *values*"; (2) post-gen, `grep -rlE '(AKIA[0-9A-Z]{16}|sk-[a-zA-Z0-9]{20,}|ghp_[a-zA-Z0-9]{36}|password\s*[:=]\s*\S+|mongodb(\+srv)?://\S+|postgres(ql)?://\S+)' wiki/` and warn (non-blocking) in the report.
- **Name collision:** before overwriting a page, check for `generated_by: autoresearch` frontmatter; if absent (user-created) skip with warning. `--force` overrides.

### Finish
After each page is written, flip its manifest entry `pending`→`generated` (interrupt-safe). When all done, set `generation_status:"complete"`. Then run Phase 3 (Validate) with wiki path swap: replace `docs/` with `wiki/` (`ls wiki/*.md wiki/modules/*.md 2>/dev/null`), use maxLoc 300. Output: `✓ Wiki: [N] modules, [M] pages generated`.

## Iteration Loop (init/update/check modes)

### Phase 1: Scout
- Scan for documentation gaps
- Prioritize: no docs → outdated docs → incomplete docs
- If no gaps remain → early stop (SUCCESS)

### Phase 2: Generate/Update
- Pick highest-priority gap
- Write or update documentation for ONE file/module
- Follow project conventions for doc format and location

### Phase 3: Validate
- Check generated docs against code: descriptions accurate? Examples valid? Links work?
- Run doc linters if available
- Record: validation_status (pass/fail), issues found

### Phase 4: Fix (unless --no-fix)
- If validation finds issues → fix the doc
- Commit clean doc: `docs: document {file/module}`

### Phase 5: Log
Append to TSV: iteration, timestamp, file_documented, validation_status, issues_found, issues_fixed, description

### Eval Checkpoint
If --evals: check if current_iteration % interval == 0 → run checkpoint.

### Bounded Check
If bounded: current_iteration >= max_iterations → exit loop.

## Output

- `learn-results.tsv`
- `summary.md` — documentation overview
- `validation-report.md` — issues found/fixed

## Summary

Print: files documented, validation pass rate, issues found/fixed, remaining gaps.

## Eval Checkpoint (--evals flag)

If --evals present:
- Compute interval: floor(max_iterations / 3), min 1. Fixed 10 if unbounded.
- Print: `--- Eval Checkpoint (iterations {X}-{Y}) ---\nDocs written: {n} | Validation: {pass}/{total} | Gaps remaining: {m}\n{recommendation}\n---`
- If 3+ checkpoints with no new docs → recommend early stop.
- At loop end → full evals summary to evals-summary.md.

## Chain Handoff

After completion, write handoff.json: version "2.1.0", source "learn", timestamp, status, results_tsv path, findings = documentation gaps remaining, config{mode, scope, depth}.
Invoke next target in --chain order. Propagate --evals flag.
