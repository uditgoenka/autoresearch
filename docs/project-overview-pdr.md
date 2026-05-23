# Project Overview — Claude Autoresearch

## Summary

Claude Autoresearch is a Claude Code skill/plugin that turns Claude Code into an autonomous improvement engine. Inspired by [Karpathy's autoresearch](https://github.com/karpathy/autoresearch), it generalizes the constraint-driven autonomous iteration pattern to any domain — code, content, marketing, sales, security, and more.

**Core idea:** Set a goal with a mechanical metric, define scope, and let Claude autonomously iterate — modify, verify, keep/discard, repeat — until the goal is achieved or the iteration limit is reached.

## Project Identity

| Field | Value |
|-------|-------|
| **Name** | Claude Autoresearch |
| **Type** | Claude Code Skill/Plugin |
| **Version** | 2.1.0 |
| **License** | MIT |
| **Author** | [Udit Goenka](https://github.com/uditgoenka) |
| **Repository** | [github.com/uditgoenka/autoresearch](https://github.com/uditgoenka/autoresearch) |
| **Platforms** | Claude Code, OpenCode, Codex |

## Problem Statement

Developers and knowledge workers spend significant time on repetitive improvement cycles — fixing errors, increasing coverage, optimizing performance, writing docs. Each cycle requires: understand state, make change, verify, decide keep/revert, repeat.

Autoresearch automates this entire loop with mechanical verification, automatic rollback, and git-based memory.

## Key Features

- **13 subcommands** covering the full development lifecycle (see table below)
- **Bounded by default** — every looping command has a sane default iteration count; opt into unbounded with `Iterations: unlimited`
- **Guard system** — optional safety net that reverts commits when quality regresses
- **Git as memory** — every experiment committed; agent reads history to avoid repeating failures
- **Interactive setup** — batched AskUserQuestion when invoked without full config
- **Domain-agnostic** — works for any task with a measurable shell-accessible metric
- **Chain integration** — pipe output between subcommands via `handoff.json`
- **Evals** — built-in trend and plateau analysis for any `*-results.tsv` file
- **Multi-platform** — Claude Code, OpenCode, Codex via `scripts/transform.sh`
- **95% token reduction** — thin SKILL.md routing table loads only the needed command file (~5–8K tokens vs ~100K in v2.0.x)

## Subcommands

| Command | Purpose | Default Iterations |
|---------|---------|-------------------|
| `/autoresearch` | Core loop: modify → verify → keep/discard | 25 |
| `/autoresearch:plan` | Convert goal into validated Scope, Metric, Verify config | N/A |
| `/autoresearch:debug` | Scientific method bug hunting | 15 |
| `/autoresearch:fix` | Iterative error-count reduction | 20 |
| `/autoresearch:security` | STRIDE + OWASP red-team audit | 15 |
| `/autoresearch:ship` | Universal 8-phase shipping workflow | N/A |
| `/autoresearch:scenario` | 12-dimension edge case generation | 20 |
| `/autoresearch:predict` | 5-persona expert debate before implementation | N/A |
| `/autoresearch:learn` | Autonomous codebase documentation engine | 10 |
| `/autoresearch:reason` | Adversarial refinement with blind judges | 8 |
| `/autoresearch:probe` | Requirement interrogation until saturation | 15 |
| `/autoresearch:improve` | Research ICP challenges, discover improvements, generate PRDs | 15 |
| `/autoresearch:evals` | Analyze `*-results.tsv`: trends, plateaus, regressions | N/A |

## Target Users

- Developers using Claude Code who want autonomous iteration on measurable metrics
- Teams seeking automated security audits, bug hunting, or documentation generation
- Anyone with a measurable goal and files that can be iteratively improved

## Design Principles

1. **Constraint = Enabler** — bounded scope enables agent confidence
2. **Separate Strategy from Tactics** — humans set direction, agents execute
3. **Metrics Must Be Mechanical** — no subjective "looks good"
4. **Verification Must Be Fast** — cheap iteration enables bold exploration
5. **Git as Memory** — commit before verify, revert on failure
6. **One Change Per Iteration** — atomic changes for clear causality
7. **Honest Limitations** — state what the system cannot do

See also: [System Architecture](system-architecture.md) | [Codebase Summary](codebase-summary.md) | [Code Standards](code-standards.md)
