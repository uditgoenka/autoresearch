# Project Changelog

All notable changes to the autoresearch project are documented here.

## v2.2.0 — Regression Stability Gate (2026-06-19)

**Theme:** A 14th family member — a heavy, layered regression-testing gate that proves a change is safe to push.

### Added
- `/autoresearch:regression` — stability gate that captures baseline behavior from a `git worktree` of the base ref, diffs the candidate across 8 dimensions, and emits a single STABLE / UNSTABLE verdict
  - **Classification phase** enforces the core invariant: a regression is a green→red transition only. red→red (pre-existing), absent→red (new coverage), and flake→red (flaky) are classified out, never counted. Tests matched by test-id then path.
  - **Tiered verdict:** HARD gate (`functional`, `api-contract`, `data-migration`, `integration-e2e`) — any green→red = UNSTABLE; SCORE 0–100 noise-tolerant weighted (`flakiness` .30, `performance` .30, `resource` .20, `visual-ui` .20), UNSTABLE below threshold 95
  - **4 input axes:** diff (default), repeat N×, full, matrix (opt-in)
  - **Baseline cache** keyed by full SHA (`baseline/<full-sha>/`), per-dim setup tiers; `--baseline-cache` on by default
  - **Statistical perf gate:** 7 independent-process samples/side, Mann–Whitney U, flagged only beyond `max(noise-band%, k·stdev)`; visual via pixel-ratio / SSIM ignoring anti-aliasing
  - **data-migration hard-guarded:** opt-in, forward-only by default, refuses any DB URL not matching the ephemeral/allowlisted set (`*test*`, `*ci*`, container)
  - **Hunter reproducibility gate:** bisect only for HARD dims passing 3/3 reproduction; SCORE / non-deterministic → differential root-cause
  - **`--fix` re-gate:** max 3 cycles, each must strictly shrink the blocking-set or STOP "not converging"; no HARD-gate bypass
  - Composable: `--predict`, `--reason`, `--probe`, `--debug`, `--fix/--fix-cycles`, `--evals`, `--chain`, `--max-runs`. Canonical combo `--predict --evals --fix --ship`
- `scripts/score-regression.sh` — scoring backend: `rubric` (spec quality gate) + `verdict` (TSV → STABLE/UNSTABLE, CI exit codes)
- `tests/test-regression.sh` + 9 golden TSV fixtures under `tests/fixtures/regression/`

### Changed
- Command count 13 → 14 across `marketplace.json`, `plugin.json`, all 5 `SKILL.md` routing tables, README, and COMPARISON
- Version 2.1.3 → 2.2.0

## v2.1.3 — Wiki Knowledge Base + Distribution Parity (2026-06-16)

**Theme:** A navigable knowledge base from `learn`, plus a clean, fully-synced distribution across all platforms.

### Added
- `/autoresearch:learn --mode wiki` — generates a navigable `wiki/` knowledge base instead of prescriptive `docs/`
  - `index.md`, `architecture.md` (Mermaid diagrams), per-module deep dives (`modules/`, cap 10), `glossary.md`, `onboarding.md`
  - Write-ahead `wiki-manifest.json` (gitignored) for resume-after-interruption; `--force` regenerates from scratch
  - `--modules <list>` overrides automatic module detection
  - Two-layer secrets filter — prompt instruction (extract env var names, not values) + post-generation regex scan (AWS keys, `sk-`/`ghp_` tokens, DB URIs, password assignments), non-blocking warning
  - Won't overwrite user-authored pages (skipped when `generated_by: autoresearch` frontmatter is absent)

### Changed
- Wiki examples and output-structure reference added to `guide/autoresearch-learn.md` (now 5 modes)
- All distributions regenerated from `.claude/` source via `scripts/transform.sh` (OpenCode, Codex) and synced to `claude-plugin/` (install source)

### Fixed
- Distribution parity — `claude-plugin/` install source now carries the `improve` command row (had drifted out of the distribution `SKILL.md`)
- Removed v2.1.0 wrapper-CLI leftovers that broke a fresh-clone test run (dead `bin/autoresearch` entrypoint and orphaned Python test modules)
- Aligned command count to 13 across `AGENTS.md`, `marketplace.json`, and the Codex plugin manifest
- Synced version fields across `marketplace.json` (was 2.1.0), the Codex plugin (was 2.1.0-codex.0), and both `SKILL.md` files

## v2.1.2 — Product Improvement Engine (2026-05-23)

**Theme:** Outward-looking product strategy — "what should we build next?"

### Added
- `/autoresearch:improve` — research ICP challenges, discover improvements, generate per-feature PRDs
  - 5 research categories: ICP challenges, competitor gaps, market trends, UX & experience, revenue & growth
  - Saturation-based termination (net-new < 2 for 3 consecutive non-reserved iterations)
  - Tiered ranking: ICP binary gate → Must-have / Nice-to-have / Moonshot → pairwise within Must-have
  - Conditional auto-discover when product context is zero (OR gate)
  - WebSearch triangulation with HIGH/MEDIUM/LOW confidence tags
  - Per-feature PRD generation with evidence chains, DECISION NEEDED markers, open questions
  - Terminal emitter — outputs PRDs for external tools, not autoresearch re-entry
- `CONTEXT.md` domain glossary with output types, loop shapes (+ Notes column), scoring systems, key concepts
- Upstream chain integration: `--improve` flag on probe, predict, debug, security

### Changed
- Subcommand count: 12 → 13
- SKILL.md updated with improve row
- `scripts/transform.sh` updated with improve sed rules for OpenCode + Codex
- `docs/system-architecture.md` updated with improve in directory listing
- `docs/project-overview-pdr.md` updated with improve in subcommands table
- `docs/development-roadmap.md` phases renumbered

### Design Decisions (11 locked via adversarial reasoning)
- D1: Opportunistic product context with conditional auto-discover
- D2: Structured insight schema with canonical normalization
- D3: 5 research categories with coverage guarantee
- D5: WebSearch as hypothesis generation with triangulation safeguards
- D8: Tiered ranking (not numeric scores)
- D10: 2 AskUserQuestion rounds (setup + feature selection)
- D11: Single-pass PRD with 5 guardrails

## v2.1.1 — Hook System (2026-05-22)

**Theme:** Safety, context injection, and session notifications.

### Added
- **9-hook safety system** — fires on every Claude Code session
  - `scout-block`: blocks node_modules/, .git/, __pycache__/ and other context-wasting directories (PreToolUse)
  - `privacy-block`: blocks .env, SSH keys, credentials with APPROVED: prefix override (PreToolUse)
  - `dangerous-cmd-block`: blocks force-push, rm -rf, git reset --hard (PreToolUse, regular git push allowed)
  - `iteration-context`: injects recent TSV data every 5th prompt after compaction (UserPromptSubmit)
  - `subagent-context`: gives spawned subagents ~150 tokens of loop awareness (SubagentStart)
  - `dev-rules-reminder`: re-injects plan path and code standards after compaction (UserPromptSubmit)
  - `simplify-gate`: warns at 400 LOC, blocks at 800 LOC when shipping verbs detected (UserPromptSubmit)
  - `session-init`: computes project root, branch, paths; persists session state (SessionStart)
  - `stop-notify`: terminal notification + optional webhook on session end (SessionEnd)
- **hooks.json** — auto-registers all hooks on plugin install
- **node-hook-runner.sh** — shell wrapper that silences profile noise for clean JSON output
- **lib/ar-hook-utils.cjs** — shared utilities (state management, TSV reading, logging)
- **lib/ignore.cjs** — vendored gitignore-spec pattern matcher (15KB, zero deps)
- **.ckignore** — baseline blocked patterns (gitignore syntax, customizable per project)
- **guide/hooks.md** — complete hook reference guide

### Changed
- `plugin.json` version bumped to 2.1.1
- `scripts/transform.sh` now copies hooks to `claude-plugin/hooks/`
- `.gitignore` updated with `!.claude/hooks/autoresearch/` exclusion
- `docs/system-architecture.md` updated with hook system architecture
- `CONTRIBUTING.md` updated with hook development guide

### Design Decisions
- SessionEnd event (not Stop) for notifications — Stop fires per-turn, SessionEnd fires once
- Force-push only blocking — regular `git push` allowed for `/autoresearch:ship` compatibility
- Smart Bash argument parsing — prevents false positives on string literals
- Session state via `/tmp/ar-session-{hash}.json` — hooks are subprocesses, can't share env vars
- Iteration-based throttling (every 5th) — matches loop cadence, not wall-clock time

## v2.1.0 — 2026-05-22

### Summary
Modular rebuild. Thin SKILL.md routing table replaces the 813-line monolith. Twelve self-contained command files replace the old minimal-registration + 13-reference-file pattern. Net result: ~95% token reduction per invocation (~5–8K tokens vs ~100K). New `/autoresearch:evals` subcommand added.

### Added
- `/autoresearch:evals` — one-shot analysis of any `*-results.tsv`: trends, plateaus, regressions, file hotspots, technique effectiveness, recommendations
- `--evals` flag on all looping commands — adaptive mid-loop checkpoints + final evals-summary.md
- `--evals-interval N` — override checkpoint frequency
- `# metric_direction: higher_is_better|lower_is_better` comment on TSV line 1 — enables evals auto-detection
- 3 new TSV status values: `keep (reworked)`, `hook-blocked`, `metric-error` (total: 8)
- `scripts/transform.sh` — single script generates OpenCode and Codex distributions from `.claude/` source
- `handoff.json` written by all subcommands for chain integration; `evals` reads `*-results.tsv` directly

### Changed
- `SKILL.md` reduced from 813 lines to 41 lines — routing table only, no protocol
- All 12 command files are now self-contained (94–120 lines each) — full protocol embedded, no reference file loading required for standard use
- Reference files reduced from 13 to 3: `predict-personas.md`, `reason-judge-protocol.md`, `security-checklist.md`
- Subcommand count: 11 → 12 (added evals)

### Removed
- `plugins/autoresearch/resources/autoresearch-command-spec.json` — command contracts now live in individual command files
- `scripts/sync-opencode.sh` and `scripts/sync-codex.sh` — replaced by `scripts/transform.sh`
- `plugins/autoresearch/scripts/autoresearch_cli.py` — Python wrapper CLI no longer needed
- 10 per-command workflow reference files (plan, debug, fix, security, ship, scenario, predict, learn, reason, probe workflows)

### Technical Details
- Per-invocation token cost: ~5–8K (down from ~100K in v2.0.x)
- All platform distributions generated from `.claude/` canonical source
- Codex plugin version: `2.1.0-codex.0`
- Backward compat: evals reads v2.0.03 TSV files (handles missing `timestamp` column)

## v2.0.0 — 2026-04-28

### Summary
Multi-platform GA release. Claude Code, OpenCode, and Codex all fully supported with strict YAML compliance, security-hardened scripts, and complete command metadata.

### Breaking
- Version jump from 1.10.0 to 2.0.0 — reflects multi-platform support, 11 subcommands, and maturity since v1.x

### Fixed
- SKILL.md YAML frontmatter uses folded block scalars — strict parsers (Codex CLI, PyYAML) no longer reject the description field (#69, #71)
- `scripts/sync-codex.sh` and `scripts/sync-opencode.sh` pass paths via `sys.argv` instead of shell string interpolation — eliminates script corruption when paths contain quotes (#77)
- `scripts/install.sh` `sync_dir()` validates destination path depth before `rm -rf` — rejects empty, root, or shallow paths (#78)

### Added
- `name` field to `.opencode/agents/docs-manager.md` for explicit agent registration (#74)
- `name` field to all 11 `.opencode/commands/*.md` files for schema compliance (#75)
- `allowed-tools` declaration to all Claude Code and claude-plugin command files (#76)

### Changed
- All version references unified to 2.0.0 across SKILL.md ×4, plugin.json, marketplace.json, README badge

### Contributors
- @xiaolai — NLPM audit (#79): 3 bugs + 2 security findings with PRs #74–#78
- @georgelichen — initial YAML frontmatter issue report (#69)
- @ch0udry — Codex loading error report (#71)
- @rexplx — YAML colon escape fix (#80)
- @haosenwang1018 — comprehensive YAML + sync script fix (#81)

## v1.10.0 — 2026-04-16

### Added
- `/autoresearch:probe` — adversarial multi-persona requirement interrogation engine
- probe-workflow.md reference (449 lines) — 10-phase protocol
- 8 personas: Skeptic, Edge-Case Hunter, Scope Sentinel, Ambiguity Detective, Contradiction Finder, Prior-Art Investigator, Success-Criteria Auditor, Constraint Excavator
- Mechanical saturation termination: net-new constraints below threshold for K consecutive rounds
- Output bundle: probe-spec.md, constraints.tsv, questions-asked.tsv, contradictions.md, hidden-assumptions.md, autoresearch-config.yml, summary.md, handoff.json

## v1.8.0 — 2026-03-21

### Added
- `/autoresearch:learn` — autonomous codebase documentation engine
- 4 modes: init, update, check, summarize
- Diff-based targeting for update mode: maps git changes to affected docs
- Validation-fix loop with mechanical verification (max 3 retries)
- Composite metric: `learn_score = validation%*0.5 + coverage%*0.3 + size_compliance%*0.2`

## v1.7.0 — 2026-03-18

### Added
- `/autoresearch:predict` — multi-persona swarm prediction
- 5 default personas: Architecture Reviewer, Security Analyst, Performance Engineer, Reliability Engineer, Devil's Advocate
- Adversarial debate mode (Red/Blue teams), anti-herd detection, budget enforcement
- Zero external dependencies — file-based knowledge representation

## v1.6.2 — 2026-03-10

### Added
- Expanded EXAMPLES.md, GUIDE.md, and CONTRIBUTING.md

## Previous Versions

See `docs/changelog.md` and git history for v1.3.0–v1.6.1 details.

See also: [Development Roadmap](development-roadmap.md) | [Project Overview](project-overview-pdr.md)
