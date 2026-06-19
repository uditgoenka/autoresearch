# Development Roadmap

Strategic milestones and feature development phases for autoresearch.

## Completed Phases

### Phase 1: Core Skill Framework
- Base skill architecture with SKILL.md pattern
- Multi-agent orchestration capabilities
- Reference documentation system
- Scenario-based workflow definitions

### Phase 2: Multi-Subcommand Pattern
- debug, fix, security, ship, scenario subcommands
- Chain integration between subcommands via handoff.json
- Interactive AskUserQuestion setup gates

### Phase 3: Advanced Analysis Capabilities
- Codebase analysis engine
- Dependency mapping and component clustering
- Git integration for staleness detection

### Phase 4: Predict Swarm Intelligence — 2026-03-18
- Multi-persona swarm prediction (5 default personas)
- Sequential debate protocol with anti-herd detection
- Adversarial Red/Blue team mode
- Budget enforcement and git-hash stamping

### Phase 5: Learn + Probe Subcommands — 2026-03-21 / 2026-04-16
- `/autoresearch:learn` autonomous documentation engine (v1.8.0)
- 4 modes: init, update, check, summarize
- Diff-based targeting for update mode
- `/autoresearch:probe` requirement interrogation engine (v1.10.0)
- 8 personas, saturation-based termination

### Phase 6: Multi-Platform GA — 2026-04-28
- OpenCode + Codex distributions (v2.0.0)
- YAML strict compliance across all SKILL.md files
- Security-hardened install and sync scripts
- 11 subcommands, unified version references

### Phase 7: Modular Rebuild + Evals — 2026-05-22 (v2.1.0) — COMPLETED
- Thin SKILL.md routing table (41 lines, was 813 lines)
- 12 self-contained command files (94–120 lines each)
- 3 focused reference files (was 13)
- `/autoresearch:evals` new subcommand for TSV analysis
- `scripts/transform.sh` replaces sync-opencode.sh + sync-codex.sh
- Removed Python wrapper CLI and autoresearch-command-spec.json
- TSV `# metric_direction` comment for auto-detection
- 8 TSV status values (added `keep (reworked)`, `hook-blocked`, `metric-error`)
- `--evals` / `--evals-interval` flags on all looping commands
- ~95% token reduction per invocation

## Current Phase

### Phase 8: Hook System + Product Improvement — 2026-05-22 (v2.1.1 / v2.2.0)
- 9-hook safety system (v2.1.1)
- `/autoresearch:improve` — product improvement research + PRD generation (v2.2.0)
  - 5 research categories with saturation-based termination
  - ICP-aligned tiered ranking (Must-have / Nice-to-have / Moonshot)
  - Per-feature PRD generation with evidence chains
  - Conditional auto-discover for zero-context codebases
  - Terminal emitter — outputs PRDs for external tools, not autoresearch re-entry
- Subcommand count: 12 → 13

## Current Phase

### Phase 9: Regression Stability Gate + Stabilization — 2026-06-19 (v2.2.0)
- `/autoresearch:regression` — layered stability gate, 14th family member
  - 8 dimensions, tiered HARD/SCORE verdict, green→red classification invariant
  - git-worktree baseline cache (SHA-keyed), statistical perf gate (Mann–Whitney U), hard-guarded forward-only data-migration
  - `scripts/score-regression.sh` (rubric + verdict) + `tests/test-regression.sh` (43 assertions, 9 golden fixtures)
  - Subcommand count: 13 → 14
- Guide updates reflecting v2.2.0 command file structure
- Scenario guide coverage for evals, improve, and chain workflows
- Community contributions and bug reports

## Future Phases

### Phase 10: Extended Integration
- GitHub Actions workflow templates
- CI/CD pipeline integration examples
- Web dashboard for TSV result visualization

### Phase 11: Advanced Features
- Custom persona templates for predict and probe
- Domain-specific analysis profiles
- Multi-repo analysis support
- Historical trend analysis across runs

## Success Metrics

- Token cost per invocation: <10K (achieved in v2.1.0 for typical use)
- Zero external runtime dependencies (achieved)
- All platforms supported from single canonical source (achieved in v2.1.0)
- Graceful degradation under bounded iteration limits (achieved)
