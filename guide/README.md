<div align="center">

# Autoresearch Guides

**By [Udit Goenka](https://udit.co)**

[![Version](https://img.shields.io/badge/version-2.2.0-blue.svg)](https://github.com/uditgoenka/autoresearch/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

</div>

---

Everything you need to master autonomous iteration — from first run to advanced multi-command chains. Each guide is self-contained with examples, flags, chains, and tips.

---

## Quick Start

```bash
npx skills add uditgoenka/autoresearch
/autoresearch
```

---

## Guide Index

| Guide | Description |
|-------|-------------|
| [Getting Started](getting-started.md) | Installation, first run, core concepts |
| [/autoresearch — Orchestrator](autoresearch-orchestrator.md) | Autonomous orchestrator — type a plain-language goal, the system selects and loops the pipeline |
| [/autoresearch](autoresearch.md) | Core autonomous loop — modify, verify, keep/discard, repeat |
| [/autoresearch:plan](autoresearch-plan.md) | One-shot wizard — Goal → Scope, Metric, Verify |
| [/autoresearch:debug](autoresearch-debug.md) | Autonomous bug-hunting with scientific method |
| [/autoresearch:fix](autoresearch-fix.md) | Error crusher — tests, types, lint, build |
| [/autoresearch:security](autoresearch-security.md) | STRIDE + OWASP + red-team security audit |
| [/autoresearch:ship](autoresearch-ship.md) | 8-phase shipping workflow |
| [/autoresearch:scenario](autoresearch-scenario.md) | Scenario explorer — 12 dimensions |
| [/autoresearch:predict](autoresearch-predict.md) | 5 expert personas debate before you act |
| [/autoresearch:learn](autoresearch-learn.md) | Autonomous documentation engine |
| [/autoresearch:reason](autoresearch-reason.md) | Adversarial refinement with blind judges |
| [/autoresearch:probe](autoresearch-probe.md) | 8 personas interrogate requirements to saturation |
| [/autoresearch:improve](autoresearch-improve.md) | Research ICP challenges, discover improvements, generate PRDs |
| [/autoresearch:evals](autoresearch-evals.md) | Analyze results TSV — trends, plateaus, checkpoints |
| [/autoresearch:regression](autoresearch-regression.md) | Stability gate — baseline diff, STABLE/UNSTABLE verdict before you push |
| [Chains & Combinations](chains-and-combinations.md) | Multi-command pipelines with all 14 commands |
| [Examples by Domain](examples-by-domain.md) | Real-world examples: software, sales, marketing, DevOps, ML, HR |
| [Advanced Patterns](advanced-patterns.md) | Guards, MCP, CI/CD, evals checkpoints, transform.sh |
| [Hooks Reference](hooks.md) | 9 auto-firing hooks: safety gates, context injection, notifications |
| **[Scenario Guides](scenario/)** | **Real-world scenario walkthroughs** |

---

## Quick Decision Guide

| I want to... | Use |
|--------------|-----|
| Give a plain-language goal, let it self-orchestrate | bare `/autoresearch <goal>` |
| Improve test coverage / reduce bundle size / any metric | `/autoresearch` |
| Don't know what metric to use | `/autoresearch:plan` |
| Requirements are unclear — surface hidden constraints | `/autoresearch:probe` |
| Run a security audit | `/autoresearch:security` |
| Ship a PR / deployment / release | `/autoresearch:ship` |
| Hunt all bugs in a codebase | `/autoresearch:debug` |
| Fix all errors (tests, types, lint) | `/autoresearch:fix` |
| Debug then auto-fix | `/autoresearch:debug --fix` |
| Check if something is ready to ship | `/autoresearch:ship --checklist-only` |
| Explore edge cases for a feature | `/autoresearch:scenario` |
| Generate test scenarios | `/autoresearch:scenario --format test-scenarios` |
| Get expert opinions before starting | `/autoresearch:predict` |
| Debate an architecture decision | `/autoresearch:reason --domain software` |
| Generate docs for a new codebase | `/autoresearch:learn --mode init` |
| Update existing docs after changes | `/autoresearch:learn --mode update` |
| Discover what to build next for your ICP | `/autoresearch:improve` |
| Analyze loop results, detect plateaus | `/autoresearch:evals` |
| Verify a change is safe to push (catch regressions) | `/autoresearch:regression` |
| Gate, auto-fix, then ship in one chain | `/autoresearch:regression --predict --evals --fix --ship` |
| Optimize without breaking existing tests | `/autoresearch` with `Guard: npm test` |
| Bound any looping command | Add `Iterations: N` inline |

---

<div align="center">

**Built by [Udit Goenka](https://udit.co)** | [GitHub](https://github.com/uditgoenka/autoresearch) | [Follow @iuditg](https://x.com/iuditg)

</div>
