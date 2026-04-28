# Project Changelog

All notable changes to the autoresearch project are documented here.

## v2.0.0 — 2026-04-28

### Summary
Multi-platform GA release. Promotes v2.0.0-beta to stable. Claude Code + OpenCode + Codex all fully supported with strict YAML compliance, security-hardened scripts, and complete command metadata.

### Breaking
- Version jump from 1.10.0 to 2.0.0 — reflects multi-platform support (Claude Code, OpenCode, Codex), 11 subcommands, and maturity since v1.x

### Fixed
- SKILL.md YAML frontmatter now uses folded block scalars — strict parsers (Codex CLI, PyYAML) no longer reject the description field (#69, #71)
- `scripts/sync-codex.sh` and `scripts/sync-opencode.sh` pass paths via `sys.argv` instead of shell string interpolation — eliminates script corruption when paths contain quotes (#77)
- `scripts/install.sh` `sync_dir()` validates destination path depth before `rm -rf` — rejects empty, root, or shallow paths (#78)

### Added
- `name` field to `.opencode/agents/docs-manager.md` for explicit agent registration (#74)
- `name` field to all 11 `.opencode/commands/*.md` files for schema compliance (#75)
- `allowed-tools` declaration to all Claude Code and claude-plugin command files (#76)

### Changed
- All version references unified to 2.0.0 (SKILL.md ×4, plugin.json, marketplace.json, README badge)

### Contributors
- @xiaolai — NLPM audit (#79) surfacing 3 bugs + 2 security findings with PRs #74-#78
- @georgelichen — initial YAML frontmatter issue report (#69)
- @ch0udry — Codex loading error report (#71)
- @rexplx — YAML colon escape fix (#80)
- @haosenwang1018 — comprehensive YAML + sync script fix (#81)

## v1.10.0 — 2026-04-16

### Added
- `/autoresearch:probe` subcommand -- adversarial multi-persona requirement / assumption interrogation engine
- probe-workflow.md reference (449 lines) -- 10-phase probe protocol (Seed → Persona Activation → Codebase Grounding → Round Generation → Synthesis → Answer Capture → Constraint Extraction → Cross-Check → Saturation Check → Synthesize & Handoff)
- 8 personas (Skeptic, Edge-Case Hunter, Scope Sentinel, Ambiguity Detective, Contradiction Finder, Prior-Art Investigator, Success-Criteria Auditor, Constraint Excavator); cold-start question generation per round
- Mechanical saturation termination -- net-new constraints below threshold for K consecutive rounds (default threshold=2, K=3)
- `--depth`, `--personas`, `--saturation-threshold`, `--scope`, `--chain`, `--mode`, `--adversarial`, `--iterations` flags
- Output bundle: probe-spec.md, constraints.tsv, questions-asked.tsv, contradictions.md, hidden-assumptions.md, autoresearch-config.yml, summary.md, handoff.json
- Composite metric: `probe_score = constraints_extracted*10 + contradictions_resolved*25 + hidden_assumptions_surfaced*20 + ambiguities_clarified*15 + (dimensions_covered/total)*30 + (saturated?100:0) + (config_complete?50:0)`
- Chain handoff to plan, predict, debug, fix, scenario, reason, ship, learn
- guide/autoresearch-probe.md user-facing usage guide
- OpenCode mirror at `.opencode/commands/autoresearch_probe.md` and `.opencode/skills/autoresearch/references/probe-workflow.md`
- Codex mirror at `.agents/skills/autoresearch/references/probe-workflow.md` plus probe block in `plugins/autoresearch/resources/autoresearch-command-spec.json`
- Registered in 5 SKILL.md touchpoints (frontmatter description, prose list, Interactive Setup Gate table, Subcommands table, dedicated section + activation triggers)

### Changed
- Subcommand count: 10 -> 11 across README.md, COMPARISON.md, AGENTS.md
- Sync scripts (`scripts/sync-opencode.sh`, `scripts/sync-codex.sh`) extended with probe sed mapping
- Codex command spec version bumped: 1.9.0-codex.0 -> 1.10.0-codex.0

## v1.8.0 — 2026-03-21

### Added
- `/autoresearch:learn` subcommand -- autonomous codebase documentation engine
- learn-workflow.md reference file (480 lines) -- 8-phase workflow protocol
- 4 modes: init (from scratch), update (diff-based targeting), check (health assessment), summarize (quick inventory)
- Dynamic doc discovery via `docs/*.md` scanning -- no hardcoded file lists
- Validation-fix loop with mechanical verification (max 3 retries)
- Diff-based targeting for update mode: maps git changes to affected docs
- Scale-aware scouting with parallel reconnaissance
- Composite metric: `learn_score = validation%*0.5 + coverage%*0.3 + size_compliance%*0.2`

### Changed
- SKILL.md updated with learn subcommand entry, setup gates, and activation triggers
- Version bumped to 1.8.0 across plugin.json, SKILL.md, and README

## v1.7.6 — 2026-03-20

### Added
- COMPARISON.md -- Karpathy's autoresearch vs Claude Autoresearch comparison
- 10 scenario-based guide examples in guide/scenario/

## v1.7.0 — 2026-03-18

### Added
- `/autoresearch:predict` subcommand — multi-persona swarm prediction with file-based knowledge representation
- predict-workflow.md reference file (751 lines) — complete 8-phase workflow protocol
- File-based knowledge graph: codebase-analysis.md, dependency-map.md, component-clusters.md
- 5 default personas: Architecture Reviewer, Security Analyst, Performance Engineer, Reliability Engineer, Devil's Advocate
- Adversarial debate mode (--adversarial flag) with Red/Blue team personas
- Anti-herd detection: flip rate + entropy monitoring with groupthink warnings
- Chain integration: --chain debug/security/fix/ship/scenario with handoff.json
- Budget enforcement: pre-execution estimation + per-round caps + graceful degradation
- Git-hash stamping for report staleness detection
- Incremental updates via git diff

### Changed
- Enhanced SKILL.md subcommands table with predict entry and mandatory setup gates
- Updated activation triggers section to include predict workflow activation

### Technical Details
- Zero external dependencies (file-based knowledge replaces GraphRAG)
- Token budget under 50K per simulation (5 personas x 2 rounds)
- Lightweight mode default with optional full simulation
- Support for 3-10 personas, 1-5 debate rounds, shallow/standard/deep presets
- SARIF-inspired structured findings for chain handoff

## v1.6.2 — 2026-03-10

### Added
- Expanded examples in EXAMPLES.md with new domains, languages, and chains
- GUIDE.md comprehensive reference documentation
- CONTRIBUTING.md guidelines for project contributions

### Changed
- Updated release workflow documentation

## Previous Versions

See git history for earlier releases and changes.
