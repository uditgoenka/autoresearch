# /autoresearch:learn — The Documentation Engine

Autonomous documentation engine. Scouts your codebase, learns its structure and patterns, generates or refreshes comprehensive docs, then validates and iteratively fixes them until they match reality. Default: 10 iterations (validation-fix loop).

---

## How It Works — 8 Phases

```
Scout → Analyze → Map → Generate → Validate → Fix → Finalize → Log
```

1. **Scout** — parallel reconnaissance across the codebase (files, LOC, dependencies)
2. **Analyze** — classify project type, detect tech stack, calculate staleness gap
3. **Map** — discover existing docs, identify gaps, decide what to create or update
4. **Generate** — spawn a docs-manager agent with all gathered context
5. **Validate** — mechanical checks: broken references, invalid links, bad config keys
6. **Fix** — re-run docs-manager targeting only failed checks (up to 3 iterations)
7. **Finalize** — git diff summary, file inventory, size compliance report
8. **Log** — append to `learn-results.tsv` + write `summary.md`

Generated docs land in `docs/` directly. The `learn/` directory is the audit trail only.

---

## 5 Modes

| Mode | What It Does | When to Use |
|------|-------------|-------------|
| `init` | Scouts from scratch, creates all core docs | New project, no docs yet |
| `update` | Reads existing docs, refreshes stale content | Docs exist but may be stale |
| `check` | Read-only health audit — no file writes | Before a release, quick pulse |
| `summarize` | Creates/updates `codebase-summary.md` only | Onboarding, quick orientation |
| `wiki` | Generates a navigable `wiki/` knowledge base with architecture diagrams, per-module deep dives, glossary, and onboarding guide | Developer KT sessions, onboarding, a "second brain" for the codebase |

**Auto-detection:** if `docs/` has 0 files → defaults to `init`. If docs exist → defaults to `update`.

---

## All Flags

| Flag | Purpose | Default |
|------|---------|---------|
| `Iterations: N` | Override default of 10 (validation-fix loop) | 10 |
| `--mode <mode>` | `init`, `update`, `check`, `summarize`, `wiki` | Auto-detected |
| `--scope <glob>` | Limit codebase learning to specific dirs | Everything |
| `--depth <level>` | `quick`, `standard`, `deep` | `standard` |
| `--file <name>` | Selective update — target one doc file | All docs |
| `--scan` | Force fresh scout in summarize mode | false |
| `--topics <list>` | Focus summarize on specific topics | All |
| `--modules <list>` | Wiki mode: override module auto-detection with a comma-separated list | Auto-detect |
| `--force` | Wiki mode: regenerate all pages from scratch, ignore manifest | false |
| `--no-fix` | Skip validation-fix loop | false |
| `--format <type>` | `markdown`, `html`, `json`, `rst` | markdown |
| `--chain <targets>` | Chain to next command(s) after completion | none |

---

## Examples

### Initialize docs for a new project

```
/autoresearch:learn --mode init
```

Creates: `docs/project-overview-pdr.md`, `docs/codebase-summary.md`, `docs/code-standards.md`, `docs/system-architecture.md`, `README.md`. Conditionally adds deployment guide, design guidelines, and roadmap when detected.

### Refresh docs after a sprint

```
/autoresearch:learn --mode update
```

Reads existing docs in parallel, identifies stale sections based on recent git changes, updates while preserving your custom structure.

### Health check before a release

```
/autoresearch:learn --mode check
```

Read-only. Returns staleness status, file sizes, validation warnings, coverage of core doc types. No files modified.

### Generate codebase summary only

```
/autoresearch:learn --mode summarize
```

### Scope to one module

```
/autoresearch:learn --mode update --scope src/api/**
```

### Update a single document

```
/autoresearch:learn --mode update --file system-architecture.md
```

### Deep documentation with deployment coverage

```
/autoresearch:learn --mode init --depth deep
```

Generates all core docs plus `deployment-guide.md`, `design-guidelines.md`, and `project-roadmap.md` regardless of auto-detection signals.

### Focused summary on specific topics

```
/autoresearch:learn --mode summarize --scan --topics "authentication, payments, rate-limiting"
```

### Skip validation-fix loop (fast pass)

```
/autoresearch:learn --mode update --no-fix
```

### Generate a wiki knowledge base

```
/autoresearch:learn --mode wiki
```

Scouts the codebase, detects up to 10 modules, then generates a `wiki/` directory with: `index.md` (table of contents), `architecture.md` (system overview with Mermaid diagrams), per-module deep dives in `modules/`, `glossary.md` (domain terms from code), and `onboarding.md` (reading order, setup, gotchas). Pages are cross-linked and kept under ~300 lines. A manifest tracks progress for resume on interruption.

### Wiki for specific modules

```
/autoresearch:learn --mode wiki --modules auth,api,payments
```

Overrides automatic module detection — only generates pages for the named modules. Useful when heuristics miss a module or you want a focused wiki.

### Force-regenerate the wiki

```
/autoresearch:learn --mode wiki --force
```

Ignores the existing manifest and regenerates every page from scratch. Use after significant codebase changes or if the manifest is corrupted.

### Wiki scoped to one subsystem

```
/autoresearch:learn --mode wiki --scope src/api/**
```

Generates pages only for modules within the scope — combines with auto-detection; modules outside the scope are dropped with a warning.

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

The wiki is **descriptive** (explains what the code does) — separate from `docs/`, which is **prescriptive** (tells developers what to do). Both coexist without conflict.

**Resume:** if interrupted, re-running `wiki` mode picks up where it left off (pending pages only); `--force` regenerates everything.

**Won't overwrite your content:** a custom page (one lacking `generated_by: autoresearch` frontmatter) is skipped with a warning. `--force` overrides.

---

## Core Docs Generated

| Doc | Always | Conditional |
|-----|--------|-------------|
| `project-overview-pdr.md` | Yes | — |
| `codebase-summary.md` | Yes | — |
| `code-standards.md` | Yes | — |
| `system-architecture.md` | Yes | Includes Mermaid diagrams |
| `README.md` | Yes | — |
| `api-reference.md` | — | API routes detected |
| `deployment-guide.md` | — | Dockerfile/CI detected |
| `testing-guide.md` | — | Test directories detected |
| `design-guidelines.md` | — | Frontend components detected |
| `configuration-guide.md` | — | `.env.example` or `config/` detected |
| `project-roadmap.md` | — | Milestone tracking detected |

---

## Learn Score

```
learn_score = (validation_score × 0.5)
            + (docs_coverage × 0.3)
            + (size_compliance × 0.2)
```

| Score | Rating |
|-------|--------|
| 90–100 | Excellent |
| 70–89 | Good — minor gaps |
| < 70 | Needs work |

---

## Output Structure

```
learn/{YYMMDD}-{HHMM}-{slug}/
├── learn-results.tsv      Iteration log — one row per run
├── summary.md             Executive summary of what was learned
├── validation-report.md   Last validation output with warnings
└── scout-context.md       Merged scout reports for reference
```

---

## Chain Patterns

### learn → security

```
/autoresearch:learn --mode init
/autoresearch:security
```

### check → update (conditional)

```
/autoresearch:learn --mode check
# If report says "Stale":
/autoresearch:learn --mode update
```

### learn → ship

```
/autoresearch:learn --mode update
/autoresearch:ship --type code-pr
```

---

## Anti-Patterns

| Anti-Pattern | Do This Instead |
|---|---|
| Running `update` on a project with no docs | Use `init` first |
| Running `init` again on an existing project | Use `update` to preserve content |
| Using `check` and expecting file changes | Use `update` when you want changes |
| Scoping `init` to a single subdir | Use `--scope` with `update` mode |
| Skipping `--scope` on a 50k-file monorepo | Scope to the package you care about |

---

## FAQ

**Q: How is `update` different from `init`?**
Update reads existing docs first, then surgically refreshes stale sections while preserving structure and custom additions. Init generates from scratch.

**Q: Can I run `:learn` in CI?**
Yes. Use `--mode check` for a read-only health gate. `learn-results.tsv` is parseable for CI reporting.

**Q: What if the scout finds very little code?**
Claude stops and warns you to verify source files exist or to narrow scope.
