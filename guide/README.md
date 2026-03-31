<div align="center">

# Autoresearch Guides

**By [Udit Goenka](https://udit.co)**

[![Version](https://img.shields.io/badge/version-1.9.0-blue.svg)](https://github.com/uditgoenka/autoresearch/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

</div>

---

Everything you need to master autonomous iteration — from first run to advanced multi-command chains. Each guide is self-contained with examples, flags, chains, and tips.

---

## Quick Start

```bash
/plugin marketplace add uditgoenka/autoresearch
/plugin install autoresearch@autoresearch
/autoresearch
```

---

## Guide Index

| Guide | Description |
|-------|-------------|
| [Getting Started](getting-started.md) | Installation, first run, core concepts, 7 principles |
| [/autoresearch](autoresearch.md) | The core autonomous loop — modify, verify, keep/discard, repeat |
| [/autoresearch:plan](autoresearch-plan.md) | Interactive wizard — Goal → Scope, Metric, Direction, Verify |
| [/autoresearch:debug](autoresearch-debug.md) | Autonomous bug-hunting with scientific method |
| [/autoresearch:fix](autoresearch-fix.md) | Autonomous error crusher — tests, types, lint, build |
| [/autoresearch:security](autoresearch-security.md) | STRIDE + OWASP + red-team security audit |
| [/autoresearch:ship](autoresearch-ship.md) | Universal shipping workflow — 9 ship types |
| [/autoresearch:scenario](autoresearch-scenario.md) | Scenario explorer — 12 dimensions, 5 domains |
| [/autoresearch:predict](autoresearch-predict.md) | Multi-persona swarm prediction — expert debate before action |
| [/autoresearch:learn](autoresearch-learn.md) | Autonomous documentation engine — scout, learn, generate, validate, fix |
| [/autoresearch:reason](autoresearch-reason.md) | Adversarial refinement — blind judge convergence for subjective decisions |
| [Chains & Combinations](chains-and-combinations.md) | Multi-command pipelines and chain patterns |
| [Examples by Domain](examples-by-domain.md) | Real-world examples: software, sales, marketing, DevOps, ML, HR |
| [Advanced Patterns](advanced-patterns.md) | Guards, MCP servers, CI/CD, custom scripts, FAQ |
| **[Scenario Guides](scenario/)** | **11 real-world scenario walkthroughs — chat, SaaS, CI/CD, healthcare, finance, IoT, and more** |

---

## Quick Decision Guide

| I want to... | Use |
|--------------|-----|
| Improve test coverage / reduce bundle size / any metric | `/autoresearch` (add `Iterations: N` for bounded runs) |
| Don't know what metric to use | `/autoresearch:plan` |
| Run a security audit | `/autoresearch:security` |
| Ship a PR / deployment / release | `/autoresearch:ship` |
| Optimize without breaking existing tests | Add `Guard: npm test` |
| Hunt all bugs in a codebase | `/autoresearch:debug` (add `Iterations: 20` for bounded runs) |
| Fix all errors (tests, types, lint) | `/autoresearch:fix` |
| Debug then auto-fix | `/autoresearch:debug --fix` |
| Check if something is ready to ship | `/autoresearch:ship --checklist-only` |
| Explore edge cases for a feature | `/autoresearch:scenario` |
| Generate test scenarios | `/autoresearch:scenario --domain software --format test-scenarios` |
| Stress test a user journey | `/autoresearch:scenario --depth deep` |
| I want expert opinions before I start | `/autoresearch:predict` |
| Analyze this from multiple angles | `/autoresearch:predict --chain debug` |
| Generate docs for a new codebase | `/autoresearch:learn --mode init` |
| Update existing docs after changes | `/autoresearch:learn --mode update` |
| Check if docs are stale or broken | `/autoresearch:learn --mode check` |
| Quick codebase summary | `/autoresearch:learn --mode summarize` |
| Debate an architecture decision | `/autoresearch:reason --domain software` |
| Refine a proposal adversarially | `/autoresearch:reason --domain business --iterations 8` |
| Converge then validate with experts | `/autoresearch:reason --chain predict` |
| Pure A vs B competition (no synthesis) | `/autoresearch:reason --mode debate` |

---

<div align="center">

**Built by [Udit Goenka](https://udit.co)** | [GitHub](https://github.com/uditgoenka/autoresearch) | [Follow @iuditg](https://x.com/iuditg)

</div>
