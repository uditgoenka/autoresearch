# Project Overview — Claude Autoresearch

## Summary

Claude Autoresearch is a Claude Code skill/plugin that turns Claude Code into an autonomous improvement engine. Inspired by [Karpathy's autoresearch](https://github.com/karpathy/autoresearch), it generalizes the constraint-driven autonomous iteration pattern to any domain -- code, content, marketing, sales, security, and more.

**Core idea:** Set a goal with a mechanical metric, define scope, and let Claude autonomously iterate -- modify, verify, keep/discard, repeat -- until the goal is achieved or iteration limit reached.

## Project Identity

| Field | Value |
|-------|-------|
| **Name** | Claude Autoresearch |
| **Type** | Claude Code Skill/Plugin |
| **Version** | 1.8.0 |
| **License** | MIT |
| **Author** | [Udit Goenka](https://github.com/uditgoenka) |
| **Repository** | [github.com/uditgoenka/autoresearch](https://github.com/uditgoenka/autoresearch) |

## Problem Statement

Developers and knowledge workers spend significant time on repetitive improvement cycles -- fixing errors, increasing coverage, optimizing performance, writing docs. Each cycle requires: understand state, make change, verify, decide keep/revert, repeat.

Autoresearch automates this entire loop with mechanical verification, automatic rollback, and git-based memory.

## Key Features

- **9 subcommands**: `/autoresearch` (core loop), `:plan`, `:debug`, `:fix`, `:security`, `:ship`, `:scenario`, `:predict`, `:learn`
- **Bounded or unbounded** iteration -- run forever or exactly N times
- **Guard system** -- optional safety net preventing regressions
- **Git as memory** -- every experiment committed, agent reads history to avoid repeating failures
- **Interactive setup** -- batched AskUserQuestion when invoked without full config
- **Domain-agnostic** -- works for any task with a measurable metric
- **Chain integration** -- pipe output between subcommands (e.g., predict -> debug -> fix)
- **Autonomous documentation** -- `:learn` subcommand scouts, generates, validates, and iteratively fixes project docs

## Target Users

- Developers using Claude Code who want autonomous iteration on metrics
- Teams seeking automated security audits, bug hunting, or documentation generation
- Anyone with a measurable goal and files that can be iteratively improved

## Design Principles

1. **Constraint = Enabler** -- bounded scope enables agent confidence
2. **Separate Strategy from Tactics** -- humans set direction, agents execute
3. **Metrics Must Be Mechanical** -- no subjective "looks good"
4. **Verification Must Be Fast** -- cheap iteration enables bold exploration
5. **Git as Memory** -- commit before verify, revert on failure
6. **One Change Per Iteration** -- atomic changes for clear causality
7. **Honest Limitations** -- state what the system cannot do

See also: [System Architecture](system-architecture.md) | [Codebase Summary](codebase-summary.md) | [Code Standards](code-standards.md)
