# Learn Workflow — $autoresearch learn

Autonomous codebase documentation engine. Scouts codebase structure, learns patterns and architecture, generates/updates comprehensive documentation — then validates and iteratively improves until docs are accurate.

**Core idea:** Scout → Generate → Validate → Fix → Repeat until docs match codebase reality.

## Trigger

- User invokes `$autoresearch learn`
- User says "learn this codebase", "generate docs", "document this project", "create documentation", "update docs", "check docs health", "docs status"
- User wants to understand or document an unfamiliar codebase

## Loop Support

```
# Default — auto-detect mode and learn
$autoresearch learn

# Specific mode
$autoresearch learn --mode update

# Bounded iterations for validation-fix loop
$autoresearch learn
Iterations: 5

# Scoped learning
$autoresearch learn --scope src/api/**

# Selective single-doc update
$autoresearch learn --mode update --file system-architecture.md
```

## PREREQUISITE: Interactive Setup (when invoked without flags)

**CRITICAL — BLOCKING PREREQUISITE:** If invoked without `--mode` or sufficient inline context, you MUST use direct prompting to gather config BEFORE proceeding to Phase 1.

**TOOL AVAILABILITY:** direct prompting may be a deferred tool. If calling it fails, use `ToolSearch` to fetch the schema first, then retry. NEVER skip setup because of tool issues.

### Pre-scan (before asking questions)

Detect project state for smart defaults:
1. Does `docs/` exist? How many .md files? `ls docs/*.md 2>/dev/null | wc -l`
2. Project type indicators: `ls package.json Cargo.toml go.mod pyproject.toml *.sln 2>/dev/null`
3. Staleness: `git log -1 --format='%ci' -- docs/ 2>/dev/null` vs `git log -1 --format='%ci' 2>/dev/null`
4. Scale: `find . -type f -not -path './.git/*' -not -path '*/node_modules/*' | wc -l`

### Questions (single direct prompting call — 4 questions)

| # | Header | Question | Options (from pre-scan) |
|---|--------|----------|------------------------|
| 1 | `Mode` | "What documentation operation?" | "Init — learn codebase from scratch, generate all docs (Recommended)" (if 0 docs), "Update — learn what changed, refresh docs (Recommended)" (if docs exist), "Check — read-only health assessment", "Summarize — quick codebase summary" |
| 2 | `Scope` | "Which parts of the codebase should I learn?" | Detected top-level dirs as globs + "Everything (entire codebase)" |
| 3 | `Depth` | "How comprehensive should documentation be?" | "Quick — overview + summary only", "Standard — all core docs (Recommended)", "Deep — comprehensive with deployment, design, API reference" |
| 4 | `Launch` | "Ready to start learning?" | "Launch", "Edit config", "Cancel" |

**Skip condition:** If user provides `--mode` + `--scope` or `--depth` → skip setup entirely.

**State-aware defaults:**
- `docs/` has 0 files → default Mode = Init
- `docs/` has files → default Mode = Update
- User says "check" / "health" → Mode = Check
- User says "summarize" / "summary" → Mode = Summarize

**Cancel handling:** If user selects "Cancel" → exit: "Learning cancelled. Run `$autoresearch learn` when ready."

## Architecture

```
$autoresearch learn
  ├── Phase 1: Scout — Parallel codebase reconnaissance
  ├── Phase 2: Analyze — Structure detection + project type classification
  ├── Phase 3: Map — Dynamic doc discovery + gap analysis
  ├── Phase 4: Generate — Spawn docs-manager with structured prompt
  ├── Phase 5: Validate — Mechanical verification (refs, links, completeness)
  ├── Phase 6: Fix — Re-generate failed docs with validation feedback (LOOP)
  ├── Phase 7: Finalize — Size check, inventory, git diff summary
  └── Phase 8: Log — Record results to learn-results.tsv
```

## Phase 1: Scout — Parallel Codebase Reconnaissance

**Mode-specific:**
- **Init / Update / Summarize (with `--scan`):** Execute full scout
- **Check:** SKIP entirely (read-only mode — jump to Phase 2)
- **Summarize (without `--scan`):** SKIP (use existing docs only — jump to Phase 3)

**Steps:**

1. Scan codebase, calculate files/LOC per directory
2. **Exclusion list:** `.claude`, `.opencode`, `.git`, `node_modules`, `__pycache__`, `secrets`, `vendor`, `dist`, `build`, `.next`, `.nuxt`, `coverage`, `generated`, `*.min.js`, `.cache`, `.tmp`
   - **Test directories (`tests`, `__tests__`) are NOT excluded** — scouts should scan test structure (file patterns, frameworks, fixtures) for testing-guide.md generation. Scouts read test metadata, not individual test logic.
3. **Scale awareness:**
   - Count total files: `find . -type f -not -path './.git/*' -not -path '*/node_modules/*' | wc -l`
   - If >5000 files: increase scout parallelism, add summarization step for reports
   - If >10000 files: warn user, suggest scoping with `--scope`
4. Activate `ck:scout` skill for parallel codebase exploration
5. **Scout validation:** After scouts return, verify reports contain meaningful data. If all scouts return empty/minimal: STOP → warn: "Scout found minimal code. Verify project has source files or adjust scope with `--scope`."
6. **Monorepo detection:** Check for `workspaces` in package.json, `lerna.json`, `pnpm-workspace.yaml`, `Cargo.toml` with `[workspace]`. If detected → note workspace structure in context.
7. Merge scout reports. Estimate token count: `total_report_lines × 5`. If >100K estimated tokens → summarize merged reports before passing downstream.

**Incremental scouting (planned):**
- If `learn/` output directory exists from a previous run, read `scout-context.md` for cached context
- Compare `git log --oneline` since the cached scout's commit hash
- If <20 files changed: use cached scout + targeted re-scout of changed dirs only
- If >20 files changed or no cache: full scout as normal
- **Note:** This is optimization scaffolding — full scout is always the fallback

**Update mode optimization — git-diff scoping:**
- Run `git diff --name-only HEAD~10 -- '*.ts' '*.js' '*.py' '*.go' '*.rs' '*.java' '*.rb' 2>/dev/null | head -30`
- If changes concentrated in <3 directories → hint scouts to prioritize those areas
- Additive: scouts still cover full codebase, but changed areas get extra attention

Output: `✓ Phase 1: Scouted — [N] files, [M] directories, [K] LOC analyzed`

## Phase 2: Analyze — Structure Detection + Classification

1. Detect **project type** from scout reports: library, web app, CLI tool, API server, infrastructure, monorepo
2. Detect **tech stack**: languages, frameworks, build tools, test runners
3. Detect **existing doc structure:** `ls docs/*.md 2>/dev/null`
4. Calculate **staleness gap:**
   - Last code commit: `git log -1 --format='%ci' -- $(git ls-files '*.ts' '*.js' '*.py' '*.go' '*.rs' '*.java' '*.rb' | head -1) 2>/dev/null`
   - Last docs commit: `git log -1 --format='%ci' -- docs/ 2>/dev/null`
   - Gap in days between the two

**Mode-specific behavior:**
- **Init:** Project type determines which docs to create (Phase 3)
- **Update:** Staleness + changed areas determine update priority
- **Check:** Staleness + validation = health report (Phase 5 outputs report, then STOP)
- **Summarize:** Project type shapes summary sections

Output: `✓ Phase 2: Analyzed — [type] project, [N] existing docs, staleness: [X] days`

## Phase 3: Map — Dynamic Doc Discovery + Gap Analysis

### Init Mode — Determine Docs to Create

**Always create:**
- `docs/project-overview-pdr.md` — Project overview and PDR
- `docs/codebase-summary.md` — Codebase summary with file inventory
- `docs/code-standards.md` — Codebase structure and code standards
- `docs/system-architecture.md` — System architecture
- `README.md` at root (create or update, max 300 lines)

**Conditional creation (based on project signals from Phase 2):**
- `docs/deployment-guide.md` — if Dockerfile, CI config (`.github/workflows`, `.gitlab-ci.yml`), deploy scripts, or cloud config detected
- `docs/design-guidelines.md` — if UI components, CSS/style files, or frontend framework detected
- `docs/project-roadmap.md` — if project has milestones, issues, or TODO tracking
- `docs/api-reference.md` — if API routes, controllers, resolvers, or OpenAPI/Swagger specs detected. Include endpoint catalog with method, path, description, request/response shapes
- `docs/testing-guide.md` — if test directories (`tests/`, `__tests__/`, `spec/`), test config (jest.config, vitest.config, pytest.ini), or CI test steps detected. Document test strategy, how to run tests, coverage expectations, fixture patterns
- `docs/configuration-guide.md` — if `.env.example`, `config/` directory, feature flags, or environment-specific configs detected. Document all env vars, config keys, and their purpose
- `docs/changelog.md` — generate from `git log --oneline --no-merges -50` using conventional commit parsing. Group by type (feat, fix, docs, refactor). Only on init; update mode appends new entries

### Update Mode — Read Existing Docs in Parallel

**You (main agent) must spawn readers** — subagents cannot spawn subagents.

1. Discover docs dynamically: `ls docs/*.md 2>/dev/null`
2. **Filter:** `*.md` files only — skip binary files (.pdf, .png, .drawio)
3. Count + LOC: `wc -l docs/*.md 2>/dev/null | sort -rn`
4. **Strategy by count:**
   - **0 files:** Warn via direct prompting: "No docs found. Switch to init mode? [yes/cancel]". If yes → restart as init. If cancel → STOP.
   - **1-3 files:** Skip parallel reading, docs-manager reads directly
   - **4-6 files:** Spawn 2-3 `Explore` agents
   - **7+ files:** Spawn 4-5 `Explore` agents (max 5)
5. **Context budget:** If total docs LOC >5000 → warn in docs-manager prompt about summarization
6. Distribute by LOC (larger files get dedicated agent)
7. **Explore agent output contract:**
   ```
   "Read these markdown docs. For each file return EXACTLY this format:
   ## {filename}
   **Purpose:** one-line summary
   **Key sections:** bullet list of main headings
   **Needs update:** areas likely stale or incomplete based on content

   Files: {list}"
   ```
8. Merge Explore results into context

**Selective update:** If `--file <name>` provided → scope to that single file only, skip parallel reading.

**Diff-based doc targeting (update mode optimization):**
- After git-diff scoping identifies changed source files, map them to affected docs:
  - `src/api/**` changes → prioritize `api-reference.md`, `system-architecture.md`
  - `src/components/**` changes → prioritize `design-guidelines.md`
  - `tests/**` changes → prioritize `testing-guide.md`
  - `package.json` / dependency changes → prioritize `codebase-summary.md` (dependency section)
  - Config file changes → prioritize `configuration-guide.md`
  - New files in `src/` → prioritize `code-standards.md`, `system-architecture.md`
- Instruct docs-manager to focus regeneration effort on mapped docs, light-touch others
- This is advisory, not exclusive — all docs still get reviewed, mapped ones get deeper updates

### Check Mode — Inventory Only

1. List all docs with LOC: `wc -l docs/*.md 2>/dev/null | sort -rn`
2. Get last modified date per file: `stat -f '%Sm' -t '%Y-%m-%d' docs/*.md 2>/dev/null` (macOS) or `stat -c '%y' docs/*.md 2>/dev/null` (Linux)
3. Report which standard doc types exist vs missing (informational, not prescriptive)
4. → Proceed directly to Phase 5 for validation (skip Phase 4)

### Summarize Mode — Read Summary Context

1. Read `docs/codebase-summary.md` if exists (will be created if missing)
2. If `--scan` flag: use merged scout reports from Phase 1
3. If no `--scan`: read existing `docs/*.md` for cross-reference context only
4. If `--topics <list>` provided: focus on those topics

Output: `✓ Phase 3: Mapped — [N] docs to create/update, [M] gaps identified`

## Phase 4: Generate — Spawn docs-manager Agent

**CRITICAL:** Spawn `docs-manager` agent via Task tool with all gathered context. Do not wait for user input.

**Mode-specific:**
- **Init:** Create all docs determined in Phase 3
- **Update:** Update all discovered `docs/*.md` + user's custom docs
- **Check:** SKIP (read-only — jump to Phase 5)
- **Summarize:** Create/update `docs/codebase-summary.md` only

### Pre-generation

Ensure target directory exists: `mkdir -p docs/`

### docs-manager Prompt Template

Include ALL of the following in the agent prompt:

1. **Merged scout reports** (summarized if >100K est. tokens)
2. **Doc reading results** (from Phase 3 Explore agents — Update mode only)
3. **Git-diff hints** (from Phase 1 — Update mode only)
4. **Project type + tech stack** (from Phase 2)
5. **Monorepo structure** (if detected in Phase 1)
6. **File list:** Explicit list of all docs to create/update
7. **Constraint:** Each doc file must stay under `{docs.maxLoc}` lines (default: 800)
8. **Constraint:** README must stay under 300 lines
9. **Instruction (Init):** "Adapt doc content to the detected project type. Do not generate generic boilerplate."
10. **Instruction (Update):** "Preserve the user's custom doc structure and content. Update information, don't reorganize."
11. **Instruction (Mermaid):** "Include Mermaid diagrams in `system-architecture.md` — at minimum: component relationship diagram, data flow diagram, and service dependency graph. Use ```mermaid code blocks. For API projects, add request flow diagrams. For frontends, add component hierarchy."
12. **Instruction (Dependencies):** "In `codebase-summary.md`, include a **Key Dependencies** section listing the top 10-15 dependencies with: package name, version, purpose (one line), and whether it's a runtime or dev dependency. Parse from package.json/requirements.txt/Cargo.toml."
13. **Instruction (Cross-references):** "Add 'See also' links between related docs. Example: system-architecture.md should link to api-reference.md for endpoint details, code-standards.md should link to testing-guide.md for test patterns. Use relative markdown links: `[API Reference](api-reference.md)`."
14. **Instruction (Format):** If `--format` flag is set, output in the specified format instead of Markdown. Currently supported: `markdown` (default). Planned: `confluence`, `rst`, `html`.

### Additional Requests Passthrough

```
<additional_requests>
  $ARGUMENTS (with flags stripped)
</additional_requests>
```

Output: `✓ Phase 4: Generated — [N] docs created/updated`

## Phase 5: Validate — Mechanical Verification

### Post-generation Inventory

1. List files: `ls docs/*.md 2>/dev/null`
2. Compare against expected files (from Phase 3 mapping)
3. Flag: missing expected files, unexpected new files (informational)

### Script Validation

1. Check script exists: `[ -f "$HOME/.claude/scripts/validate-docs.cjs" ]`
2. If exists: run `node $HOME/.claude/scripts/validate-docs.cjs docs/`
3. Checks performed: code references exist, internal links resolve, config keys are real, markdown syntax valid
4. Display validation report (warnings listed)
5. If script missing: skip with note "Validation script not found — skipping script validation"

### Size Check

1. `wc -l docs/*.md README.md 2>/dev/null | sort -rn`
2. Use `docs.maxLoc` from session context (default: 800)
3. Flag files exceeding limit with delta (e.g., "system-architecture.md: 923 lines, 123 over limit")

### Calculate Metric

```
validation_score = (docs_passing_all_checks / total_docs) × 100
```

**Decision:**
- 100% → Skip Phase 6, proceed to Phase 7
- <100% → Proceed to Phase 6 (fix loop)
- `--no-fix` flag set → Accept current state, proceed to Phase 7

### Check Mode: Health Report (then STOP)

If mode is `check`, output health report and stop:

```
=== Documentation Health Report ===
Status: [Healthy | Needs attention | Stale]

Files: [N] docs found, [M] total LOC
Staleness: [Fresh (<7d) | Stale (7-30d) | Very stale (>30d)] — [X] days behind code

| File | LOC | Last Modified | Over Limit? | Valid? |
|------|-----|--------------|-------------|--------|
| ... | ... | ... | ... | ... |

Validation: [N] warnings
[list warnings if any]

Coverage: [list present vs missing standard doc types]

Recommendation: [action to take]
```

**STOP after check report.** Do not proceed to Phase 6-8.

Output: `✓ Phase 5: Validated — [N]% pass rate, [M] warnings`

## Phase 6: Fix — Validation-Fix Loop (AUTORESEARCH CORE)

**Only entered if `validation_score < 100%` AND `--no-fix` is NOT set.**

This is the core autoresearch iteration pattern applied to documentation.

### Fix Loop

```
FIX_ITERATION = 0
MAX_FIX_ITERATIONS = 3

LOOP:
  1. Collect validation failures: (file, issue_type, severity, details)
  2. Re-spawn docs-manager with:
     - Original generation context (from Phase 4)
     - Validation report with SPECIFIC issues to fix
     - Instruction: "Fix ONLY the flagged issues below. Do not rewrite entire documents."
  3. Re-run Phase 5 validation checks
  4. FIX_ITERATION += 1
  5. DECIDE:
     - validation_score = 100% → KEEP, proceed to Phase 7
     - validation_score improved AND FIX_ITERATION < MAX → RETRY (loop)
     - validation_score NOT improved OR FIX_ITERATION >= MAX → ACCEPT with warnings, proceed to Phase 7
  6. Log fix attempt to results
```

### Fix Strategies by Issue Type

| Issue | Fix Strategy |
|-------|-------------|
| Broken code reference | Grep codebase for correct path/name, update ref |
| Broken internal link | Check docs/ for correct filename, fix link |
| Invalid config key | Search project config files, correct key name |
| Oversized file | Split into focused sub-docs or trim redundant sections |
| Missing required section | Generate section from scout context |

Output: `✓ Phase 6: Fixed — [N] issues resolved in [M] iterations` or `⚠ Phase 6: [N] warnings remaining after 3 attempts`

## Phase 7: Finalize — Inventory + Summary

1. **Git diff summary:** `git diff --stat docs/ README.md 2>/dev/null`
2. **Report:**
   - Files created (new)
   - Files updated (changed)
   - Files unchanged
   - Total docs count + LOC
3. **Size compliance:** List any files still over limit
4. **Summarize mode special:** If `codebase-summary.md` exceeds `maxLoc` → trim to essential sections

Output: `✓ Phase 7: Finalized — [N] files ready`

## Phase 8: Log — Record Results

### Results File

Append to `learn-results.tsv` in the output directory:

```tsv
iteration	mode	docs_generated	docs_updated	validation_score	fix_iterations	learn_score	duration_s
1	init	7	0	100	1	95	45
2	update	0	5	85	2	78	62
```

### Progress Report (every 5 iterations if bounded)

```
=== Learn Progress (iteration N) ===
Docs generated: [X] | Docs updated: [Y]
Validation score: [Z]% (target: 100%)
Fix iterations used: [A]/[B]
Coverage: [C]/[D] core docs present
Learn score: [S]
```

### Final Summary (on completion or iteration limit)

Write `summary.md` to output directory:
- Mode used, scope, depth
- Baseline state → final state
- Docs created/updated with one-line descriptions
- Validation score trajectory
- Learn score
- Remaining warnings (if any)
- Recommended next steps

## Flags

| Flag | Purpose | Default |
|------|---------|---------|
| `--mode <mode>` | Operation: init, update, check, summarize | Auto-detect from docs/ state |
| `--scope <glob>` | Limit codebase learning to specific dirs/files | Everything |
| `--depth <level>` | Doc comprehensiveness: quick, standard, deep | standard |
| `--scan` | Force fresh codebase scout (summarize mode) | false |
| `--topics <list>` | Focus summarize on specific topics | all |
| `--file <name>` | Selective update — target single doc file | all docs |
| `--no-fix` | Skip validation-fix loop (accept first-pass) | false |
| `--format <fmt>` | Output format: `markdown` (default). Planned: `confluence`, `rst`, `html` | markdown |
| `--chain <targets>` | Chain to downstream tool(s) after completion. Comma-separated for multi-chain. Spaces after commas tolerated. `--chain debug` or `--chain scenario,debug,fix` | none |

## Composite Metric

```
learn_score = (validation_score% × 0.5)
            + (docs_coverage% × 0.3)
            + (size_compliance% × 0.2)

Where:
  validation_score = passing_docs / total_docs × 100
  docs_coverage = existing_core_docs / expected_core_docs × 100
  size_compliance = docs_under_limit / total_docs × 100
```

| Score | Rating |
|-------|--------|
| 90-100 | Excellent — docs are comprehensive and valid |
| 70-89 | Good — minor gaps or warnings |
| <70 | Needs work — significant gaps or validation failures |

## What NOT to Do — Anti-Patterns

| Anti-Pattern | Why Wrong | Do This Instead |
|---|---|---|
| Generate docs without scouting first | Produces hallucinated content disconnected from reality | Always scout → learn actual structure → then generate |
| Hardcode expected doc file list | Misses user's custom docs, breaks when files renamed | Dynamic discovery: scan `docs/*.md` at runtime |
| Skip validation on freshly generated docs | "New docs can't have errors" is wrong — LLMs hallucinate references | Always validate. Init and update both run Phase 5 |
| Retry validation-fix loop indefinitely | Diminishing returns after 3 attempts, wastes tokens | Cap at 3 retries, accept with warnings |
| Scout entire monorepo without scoping | Context overflow, massive token waste | Detect monorepo early, suggest `--scope` to user |
| Generate deployment-guide.md for a library | Irrelevant docs erode trust in all generated content | Create conditional docs only when project signals detected |
| Overwrite user's custom docs on update | Destroys manual work, violates trust | Discover custom docs, preserve their structure, update content only |
| Run check mode then modify files | Check is strictly read-only diagnostic | Use update mode for modifications |

## Chain Conversion

When `--chain` is specified, learn passes results forward after Phase 8 completes. Output includes: documentation files, scout context, validation results.

#### `--chain plan`

Documentation gaps or improvement areas revealed by learning — plan implementation to address them.

```
$autoresearch plan
Goal: Address documentation-revealed gaps — {top gap from validation report}
Context: Learn run completed, validation score: {validation_score}%, coverage: {docs_coverage}%
Scope: {source files related to documentation gaps}
```

#### `--chain debug`

Documentation gaps reveal potential bug areas — investigate before they surface in production.

```
$autoresearch debug
Scope: {source files with undocumented or stale-doc areas}
Symptom: Documentation gaps indicate untested or undocumented behavior in {area}
Context: Learn validation flagged: {validation_warnings}
```

#### `--chain scenario`

Architecture knowledge from learning → explore edge cases in the documented system.

```
$autoresearch scenario
Scenario: {key architectural pattern discovered during learn} — explore edge cases
Domain: software
Depth: standard
```

#### `--chain predict`

Codebase patterns discovered during learning → predict issues before they emerge.

```
$autoresearch predict
Scope: {scope from learn run}
Goal: Predict issues based on patterns discovered during documentation: {top patterns}
Depth: standard
```

#### `--chain security`

Architecture knowledge from learning → audit security implications of documented patterns.

```
$autoresearch security
Scope: {scope from learn run}
Focus: Security audit informed by documentation: {auth, data handling, and API patterns documented}
```

#### `--chain fix`

Documentation validation failures point to real issues — fix them directly.

```
$autoresearch fix
Target: {top validation failure description}
Scope: {files flagged in validation report}
Context: Learn validation identified: {specific broken references or invalid links}
```

#### `--chain reason`

Complex patterns discovered in documentation → adversarial refinement of improvement approach.

```
$autoresearch reason
Task: Reason about best approach to address: {top documentation finding}
Domain: software
Context: Learn run completed with validation score {validation_score}%
```

#### `--chain ship`

Documentation complete and validated → ship docs as a PR or publish them.

```
$autoresearch ship
Type: code-pr
Target: docs/
Context: Learn run produced {N} docs, validation score: {validation_score}%
```

#### `--chain probe`

Knowledge gaps surfaced during learning → interrogate requirements before the next implementation cycle.

```
$autoresearch probe
Topic: Requirements and constraints behind: {top undocumented or ambiguous area}
Context: Learn discovered gaps in: {areas from validation report}
```

### Multi-Chain Execution

`--chain plan,scenario,fix` executes sequentially:
1. Write `summary.md` after Phase 8 completes
2. Launch first chain target with learn results as context
3. Each stage's output feeds the next via handoff
4. All targets receive: mode used, validation score, docs created/updated, scout context

**Empirical evidence rule:** Downstream loop results ALWAYS override upstream findings. If a fix or debug loop disproves a documentation claim, log: `Learn finding [X] REVISED by empirical [tool] loop — [evidence]`. Do NOT revert to pre-loop documentation.

## Output Directory

```
learn/{YYMMDD}-{HHMM}-{slug}/
├── learn-results.tsv     # iteration log (tsv)
├── summary.md            # executive summary
├── validation-report.md  # last validation output
└── scout-context.md      # merged scout reports (reference)
```

**Generated/updated docs go to `docs/` directly** — not the learn/ output folder.
**learn/ is the audit trail** — records what was learned, validated, and fixed.

## Chaining Patterns

```bash
# Learn codebase, then security audit
$autoresearch learn --mode init
$autoresearch security

# Learn changes, then predict issues
$autoresearch learn --mode update
$autoresearch predict --scope src/**

# Check health, update if stale
$autoresearch learn --mode check
# If report says "Stale" →
$autoresearch learn --mode update

# Learn then ship docs as PR
$autoresearch learn --mode update
$autoresearch ship --type code-pr

# Full quality pipeline
$autoresearch learn --mode init
$autoresearch scenario --domain software
$autoresearch security
$autoresearch ship
```
