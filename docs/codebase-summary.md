# Codebase Summary

## Overview

The autoresearch codebase now ships two distributions: the original Claude Code plugin and a Codex plugin. The Claude side remains markdown-driven. The Codex side adds a small Python wrapper CLI plus a canonical JSON spec for the shared command contract.

## File Inventory

| Directory | Purpose | File Count | Primary Types |
|-----------|---------|------------|---------------|
| `claude-plugin/commands/` | Slash command registrations (main + 8 subcommands) | 10 | `.md` |
| `claude-plugin/skills/autoresearch/` | Skill definition + protocols | 13 | `.md` |
| `plugins/autoresearch/` | Codex plugin, skill router, spec, and wrapper CLI | 14 | `.json`, `.md`, `.py` |
| `guide/` | User-facing documentation and tutorials | 14 | `.md` |
| `guide/scenario/` | Real-world scenario walkthroughs (10 domains) | 11 | `.md` |
| `docs/` | Project documentation | 7 | `.md` |
| `scripts/` | Release and utility scripts | 3 | `.sh`, `.md` |
| Root | README, LICENSE, COMPARISON, CONTRIBUTING | 4 | `.md` |

## Key Files

| File | Purpose |
|------|---------|
| `claude-plugin/skills/autoresearch/SKILL.md` | Main entry point -- loaded by Claude Code, defines all 9 subcommands, setup gates, and activation triggers |
| `plugins/autoresearch/skills/autoresearch/SKILL.md` | Main entry point -- loaded by Codex, routes the Codex-native plain-text command surface |
| `plugins/autoresearch/resources/autoresearch-command-spec.json` | Canonical command and flag contract shared by the Codex skill and wrapper |
| `plugins/autoresearch/scripts/autoresearch_cli.py` | Wrapper CLI that converts autoresearch commands into `codex exec` prompts |
| `claude-plugin/.claude-plugin/plugin.json` | Plugin metadata: name, version 1.8.0, author, keywords |
| `claude-plugin/commands/autoresearch.md` | Main `/autoresearch` command registration |
| `claude-plugin/commands/autoresearch/*.md` | Subcommand registrations (plan, debug, fix, security, ship, scenario, predict, learn) |
| `claude-plugin/skills/autoresearch/references/autonomous-loop-protocol.md` | Core 8-phase loop protocol |
| `claude-plugin/skills/autoresearch/references/core-principles.md` | 7 universal principles from Karpathy's approach |
| `claude-plugin/skills/autoresearch/references/learn-workflow.md` | 8-phase learn documentation engine protocol (480 lines) |
| `scripts/release.sh` | Release automation script |
| `README.md` | Project README with installation, usage, FAQ |
| `COMPARISON.md` | Comparison: Karpathy's autoresearch vs Claude Autoresearch |
| `CONTRIBUTING.md` | Contribution guidelines |

## Key Dependencies

This project has **near-zero runtime dependencies**. The Claude distribution is pure markdown. The Codex distribution adds Python 3 for the wrapper CLI and JSON for the canonical command spec.

| Dependency | Type | Purpose |
|------------|------|---------|
| Claude Code CLI | Runtime (host) | Provides the plugin system, skill loading, and command registration |
| Codex CLI | Runtime (host) | Provides the Codex skill runtime and non-interactive `codex exec` path |
| Python 3 | Runtime (system) | Runs the Codex wrapper CLI |
| Git | Runtime (system) | State management, rollback, memory, changelog generation |
| Bash/Zsh | Runtime (system) | Shell scripts for release automation |
| GitHub CLI (`gh`) | Optional | Used by ship workflow for PR creation and release management |
| Node.js | Optional | Used by `validate-docs.cjs` script for documentation validation |

**No `package.json`, `requirements.txt`, `Cargo.toml`, or other dependency manifest exists.** The project stays dependency-light and uses only built-in markdown, JSON, shell, and Python runtime features.

## Subcommand Registry

| Command | Workflow Reference | Purpose |
|---------|-------------------|---------|
| `/autoresearch` | `autonomous-loop-protocol.md` | Core autonomous iteration loop |
| `/autoresearch:plan` | `plan-workflow.md` | Goal-to-config wizard |
| `/autoresearch:debug` | `debug-workflow.md` | Scientific method bug hunting |
| `/autoresearch:fix` | `fix-workflow.md` | Iterative error repair |
| `/autoresearch:security` | `security-workflow.md` | STRIDE + OWASP security audit |
| `/autoresearch:ship` | `ship-workflow.md` | Universal shipping workflow |
| `/autoresearch:scenario` | `scenario-workflow.md` | Scenario-driven use case generation |
| `/autoresearch:predict` | `predict-workflow.md` | Multi-persona swarm prediction |
| `/autoresearch:learn` | `learn-workflow.md` | Autonomous documentation engine |
| `/autoresearch:reason` | `reason-workflow.md` | Adversarial refinement loop |

## Output Directories

Each subcommand creates timestamped output directories:

- `security/{YYMMDD}-{HHMM}-{slug}/` -- security audit reports
- `ship/{YYMMDD}-{HHMM}-{slug}/` -- shipping logs and checklists
- `scenario/{YYMMDD}-{HHMM}-{slug}/` -- scenario exploration results
- `predict/{YYMMDD}-{HHMM}-{slug}/` -- prediction analysis and debates
- `learn/{YYMMDD}-{HHMM}-{slug}/` -- documentation generation logs (`learn-results.tsv`, `summary.md`, `validation-report.md`, `scout-context.md`)

All output uses TSV format for iteration tracking (`*-results.tsv`) and markdown for reports.

See also: [Project Overview](project-overview-pdr.md) | [System Architecture](system-architecture.md) | [Code Standards](code-standards.md)
