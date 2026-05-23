# /autoresearch:learn — The Codebase Documentation Engine

Autonomous documentation engine. Scouts your codebase, learns its structure and patterns, generates or refreshes comprehensive docs, then validates and iteratively fixes them until they match reality.

---

## How It Works

Each run follows an 8-phase pipeline:

```
Scout → Analyze → Map → Generate → Validate → Fix → Finalize → Log
```

1. **Scout** — Parallel reconnaissance across the codebase (files, LOC, dependencies, monorepo detection)
2. **Analyze** — Classify project type (web app, CLI, API, library), detect tech stack, calculate staleness gap
3. **Map** — Discover existing docs, identify gaps, decide what to create or update
4. **Generate** — Spawn a `docs-manager` agent with all gathered context to write or refresh docs
5. **Validate** — Mechanical checks: broken references, invalid links, bad config keys, oversized files
6. **Fix** — Re-run `docs-manager` targeting only failed checks (up to 3 iterations)
7. **Finalize** — Git diff summary, file inventory, size compliance report
8. **Log** — Append results to `learn-results.tsv` + write `summary.md`

Generated docs land in `docs/` directly. The `learn/` directory is the audit trail only.

---

## 5 Modes

| Mode | What It Does | When to Use |
|------|-------------|-------------|
| `init` | Scouts from scratch, creates all core docs + conditional docs | New project, no docs yet |
| `update` | Reads existing docs, identifies what changed, refreshes content | Docs exist but may be stale |
| `check` | Read-only health audit — no file writes | Before a release, quick pulse check |
| `summarize` | Creates/updates `codebase-summary.md` only | Onboarding, quick orientation |
| `wiki` | Generates navigable `wiki/` knowledge base with architecture diagrams, per-module deep dives, glossary, and onboarding guide | Developer KT sessions, onboarding, "second brain" for the codebase |

Auto-detection: if `docs/` has 0 files → defaults to `init`. If docs exist → defaults to `update`.

---

## Interactive Setup

When you run `/autoresearch:learn` without flags, Claude does a quick pre-scan first (counts existing docs, checks git staleness, detects project type), then asks 4 questions in a single prompt:

| # | Question | Options |
|---|----------|---------|
| 1 | What documentation operation? | Init / Update / Check / Summarize / Wiki (recommended one pre-selected based on state) |
| 2 | Which parts of the codebase? | Detected top-level dirs as globs + "Everything" |
| 3 | How comprehensive? | Quick (overview only) / Standard (all core docs) / Deep (+ deployment, design, API reference) |
| 4 | Ready to start? | Launch / Edit config / Cancel |

If you provide `--mode` plus at least one other flag, setup is skipped entirely and Claude starts immediately.

---

## Flags

| Flag | Purpose | Default |
|------|---------|---------|
| `--mode <mode>` | init, update, check, summarize, wiki | Auto-detected from docs/ state |
| `--scope <glob>` | Limit codebase learning to specific dirs | Everything |
| `--depth <level>` | quick, standard, deep | standard |
| `--file <name>` | Selective update — target one doc file | All docs |
| `--scan` | Force fresh scout in summarize mode | false |
| `--topics <list>` | Focus summarize on specific topics | All |
| `--no-fix` | Accept first-pass docs, skip validation-fix loop | false |
| `--modules <list>` | Wiki mode: override module auto-detection with comma-separated list | auto-detect |
| `--force` | Wiki mode: regenerate all pages from scratch, ignore manifest | false |
| `--format <type>` | Output format: `markdown` (default), `html`, `json`, `rst` | markdown |

---

## Examples

### 1. Interactive (no args)

```
/autoresearch:learn
```

Claude pre-scans, then asks 4 questions. Minimum viable usage — just run it and answer the prompts.

---

### 2. Initialize docs for a new project

```
/autoresearch:learn --mode init
```

Scouts the full codebase, creates `docs/project-overview-pdr.md`, `docs/codebase-summary.md`, `docs/code-standards.md`, `docs/system-architecture.md`, and `README.md`. Conditionally adds `docs/deployment-guide.md` (if Dockerfile/CI detected), `docs/design-guidelines.md` (if frontend detected), `docs/project-roadmap.md` (if milestone tracking detected).

### 3. Refresh docs after a sprint

```
/autoresearch:learn --mode update
```

Reads existing docs in parallel, identifies stale sections based on recent git changes, updates content while preserving your custom structure.

### 4. Quick health check before a release

```
/autoresearch:learn --mode check
```

Read-only. Returns a health report with staleness status, file sizes, validation warnings, and coverage of core doc types. No files are modified.

### 5. Generate a codebase summary only

```
/autoresearch:learn --mode summarize
```

Creates or refreshes `docs/codebase-summary.md`. Useful for onboarding new team members or sharing a project snapshot.

### 6. Scope learning to one module

```
/autoresearch:learn --mode update --scope src/api/**
```

Scouts and updates docs for the API module only. Useful when a subsystem has changed significantly and you don't want to re-process the entire codebase.

### 7. Update a single document

```
/autoresearch:learn --mode update --file system-architecture.md
```

Targets exactly one file. Reads the current content, re-scouts relevant code, updates that doc only. Fastest path when architecture changed but everything else is current.

### 8. Deep documentation with deployment coverage

```
/autoresearch:learn --mode init --depth deep
```

Generates all core docs plus `deployment-guide.md`, `design-guidelines.md`, and `project-roadmap.md` regardless of auto-detection signals. Use before a major launch or handoff.

### 9. Diff-based targeted update

```
/autoresearch:learn --mode update
```

When running in `update` mode, Claude automatically diffs existing docs against the current codebase and only regenerates sections that are stale. Files with no relevant code changes are skipped entirely, making updates faster and more precise.

### 10. Generate docs in a different format

```
/autoresearch:learn --mode init --format rst
```

Outputs documentation in reStructuredText instead of Markdown. Supports `markdown`, `html`, `json`, and `rst`. Useful for projects using Sphinx or other non-Markdown doc systems.

### 11. Skip the fix loop for a quick pass

```
/autoresearch:learn --mode update --no-fix
```

Accepts first-pass generated docs without running the validation-fix loop. Faster, but may leave broken references in place. Good for exploratory updates where you plan to review manually.

### 12. Focused summary on specific topics

```
/autoresearch:learn --mode summarize --scan --topics "authentication, payments, rate-limiting"
```

Forces a fresh scout, then generates a summary scoped to those topics. Useful for explaining a specific subsystem to a new contributor.

### 13. Generate a wiki knowledge base

```
/autoresearch:learn --mode wiki
```

Scouts the codebase, detects up to 10 modules, then generates a `wiki/` directory with: `index.md` (table of contents), `architecture.md` (system overview with Mermaid diagrams), per-module deep dives in `modules/`, `glossary.md` (domain terms from code), and `onboarding.md` (reading order, setup, gotchas). All pages are cross-linked and kept under ~300 lines. A manifest tracks generation progress for resume on interruption.

### 14. Wiki with specific modules

```
/autoresearch:learn --mode wiki --modules auth,api,payments
```

Overrides automatic module detection. Only generates wiki pages for the specified modules. Useful when heuristics miss a module or you want a focused wiki.

### 15. Force-regenerate wiki

```
/autoresearch:learn --mode wiki --force
```

Ignores existing manifest, regenerates all wiki pages from scratch. Use when the codebase has changed significantly or the manifest is corrupted.

### 16. Wiki scoped to one subsystem

```
/autoresearch:learn --mode wiki --scope src/api/**
```

Generates wiki pages only for modules within the specified scope. Combines with auto-detection — modules outside scope are dropped with a warning.

---

## Wiki Output Structure

```
wiki/
├── index.md                    # TOC, numbered reading order
├── architecture.md             # System overview with Mermaid diagrams
├── modules/
│   ├── auth.md                 # Per-module: purpose, key files, patterns
│   ├── api.md
│   └── ...                     # One page per detected module (cap: 10)
├── glossary.md                 # Domain terms extracted from code
├── onboarding.md               # Start here: reading order, setup, gotchas
└── wiki-manifest.json          # Completion tracking (in .gitignore)
```

The wiki is **descriptive** (explains what code does) — separate from `docs/` which is **prescriptive** (tells developers what to do). Both coexist without conflict.

---

## Output — learn/ Directory Structure

```
learn/{YYMMDD}-{HHMM}-{slug}/
├── learn-results.tsv      # Iteration log — one row per run
├── summary.md             # Executive summary of what was learned
├── validation-report.md   # Last validation output with warnings
└── scout-context.md       # Merged scout reports for reference
```

Generated and updated docs go to `docs/` directly — not here. The `learn/` folder is the audit trail.

---

## Composite Metric — The Learn Score

After each run, Claude calculates a single learn score:

```
learn_score = (validation_score × 0.5)
            + (docs_coverage × 0.3)
            + (size_compliance × 0.2)

Where:
  validation_score = passing_docs / total_docs × 100
  docs_coverage    = existing_core_docs / expected_core_docs × 100
  size_compliance  = docs_under_limit / total_docs × 100
```

| Score | Rating |
|-------|--------|
| 90–100 | Excellent — docs are comprehensive and valid |
| 70–89 | Good — minor gaps or warnings |
| <70 | Needs work — significant gaps or validation failures |

The score is logged to `learn-results.tsv` so you can track doc health over time.

---

## Conditional Documentation (v1.8.1)

Beyond the 5 core docs, learn auto-detects signals and generates additional docs when relevant:

| Conditional Doc | Detection Signal |
|----------------|-----------------|
| `docs/api-reference.md` | API routes, controllers, resolvers, OpenAPI/Swagger specs |
| `docs/testing-guide.md` | Test directories, test config files, CI test steps |
| `docs/configuration-guide.md` | `.env.example`, `config/` directory, feature flags |
| `docs/changelog.md` | Git history (`git log --oneline --no-merges -50`) |
| `docs/deployment-guide.md` | Dockerfile, CI config, deploy scripts |
| `docs/design-guidelines.md` | Frontend components, CSS/styling framework |
| `docs/project-roadmap.md` | Milestone tracking, TODO files, issue references |

### Architecture Diagrams

`system-architecture.md` now includes **Mermaid diagrams** automatically — component relationships, data flow, and dependency graphs rendered as code blocks. No manual diagramming needed.

### Dependency Documentation

`codebase-summary.md` now includes a **Key Dependencies** section listing major libraries/frameworks with their purpose, version, and license.

### Cross-Reference Linking

All generated docs include **"See also"** links between related documents — e.g., `system-architecture.md` links to `api-reference.md` when API routes are documented, and `testing-guide.md` links to `code-standards.md` for test conventions.

---

## Chain Patterns

### learn → security
Learn the codebase first so security audit has accurate context:

```bash
/autoresearch:learn --mode init
/autoresearch:security
```

### learn → predict
Learn recent changes, then predict where new bugs are likely:

```bash
/autoresearch:learn --mode update
/autoresearch:predict --scope src/**
```

### check → update
Use check to see if docs need work, then update only if stale:

```bash
/autoresearch:learn --mode check
# If report says "Stale" →
/autoresearch:learn --mode update
```

### learn → ship
Update docs, then open a PR with the changes:

```bash
/autoresearch:learn --mode update
/autoresearch:ship --type code-pr
```

### Full quality pipeline

```bash
/autoresearch:learn --mode init
/autoresearch:scenario --domain software
/autoresearch:security
/autoresearch:ship
```

---

## Tips

**Run `check` before `update` on large repos.** The health report shows which docs are stale and by how many days — scope your update with `--file` from there.

**Use `--scope` on monorepos.** If the codebase has >10,000 files, Claude warns you. Use `--scope packages/api/**` or similar to avoid context overflow.

**`--no-fix` is for speed, not quality.** The validation-fix loop catches hallucinated references. Skip it only for exploratory passes you plan to review manually.

**`update` preserves your structure.** Claude reads existing docs before generating — it updates content, not layout. Your custom sections survive.

**`check` is strictly read-only.** It never writes any file. Safe to run anytime, including in CI.

**`wiki` mode supports resume.** If interrupted, running it again picks up where it left off (pending pages only). Use `--force` to regenerate everything from scratch.

**Wiki pages won't overwrite your content.** If you create a custom page at `wiki/modules/auth.md`, it will be skipped (detected by missing `generated_by: autoresearch` frontmatter). Use `--force` to override.

---

## Anti-Patterns

| Anti-Pattern | Why It's Wrong | Do This Instead |
|---|---|---|
| Running `update` on a project with no docs | Nothing to update → produces empty diffs | Use `init` first |
| Using `check` then expecting file changes | Check is read-only — it never writes | Use `update` when you want changes |
| Running `init` again on a project with existing docs | Overwrites your custom content | Use `update` to preserve existing work |
| Scoping `init` to a single subdir | Core docs need full codebase context | Use `--scope` with `update` mode, not `init` |
| Skipping `--scope` on a 50k-file monorepo | Context overflow, token waste | Scope to the package or module you care about |

---

## FAQ

**Q: How is `update` different from running `init` again?**
Update reads existing docs first, then surgically refreshes stale sections while preserving structure and custom additions. Init generates from scratch and ignores existing content.

**Q: What counts as a "core doc"?**
Five always-created docs: `project-overview-pdr.md`, `codebase-summary.md`, `code-standards.md`, `system-architecture.md`, and `README.md`. Deployment guide, design guidelines, and roadmap are conditional. Additional conditional docs are generated when signals are detected — see "Conditional Documentation" below.

**Q: Why does validation still show warnings after the fix loop?**
Some issues need human judgment — ambiguous broken references, config keys that appear in multiple places. Claude lists them in `summary.md` with recommendations rather than guessing.

**Q: Can I run `:learn` in CI?**
Yes. Use `--mode check` for a read-only health gate or `--mode update --no-fix` for a fast automated refresh. `learn-results.tsv` is parseable for CI reporting.

**Q: What happens if the scout finds very little code?**
Claude stops and warns you to verify source files exist or to narrow scope with `--scope`. It will not generate docs from an empty scan.

---

<div align="center">

**[Guide Index](README.md)** | **[Chains & Combinations](chains-and-combinations.md)** | **[/autoresearch:scenario](autoresearch-scenario.md)**

</div>
