# Chains & Combinations — Multi-Command Pipelines

The real power of autoresearch comes from chaining commands. Each command's output feeds the next via `handoff.json` — zero copy-pasting, zero context loss.

> **Autonomous orchestrator:** If you don't know which chain to use, type a plain-language goal to `/autoresearch` (e.g., `/autoresearch help me fix this bug`) and the orchestrator selects and runs the right chain for you automatically. The manual chains documented here still work exactly as before — the orchestrator picks them on your behalf when you prefer not to. See [/autoresearch — Orchestrator](autoresearch-orchestrator.md).

---

## Quick Reference

| Chain | When to Use |
|-------|-------------|
| `plan → loop` | Starting a new metric improvement |
| `probe → plan → loop` | Requirements unclear before starting |
| `debug → fix` | Bug known, needs finding and fixing |
| `predict → debug` | Intermittent failures, compound issues |
| `predict → security` | Pre-deployment security review |
| `scenario → debug → fix` | Feature works but needs edge case coverage |
| `security → fix → security` | Harden, fix, verify fixes |
| `loop → ship` | Optimization complete, time to deploy |
| `debug → fix → ship` | Production issue: find, fix, deploy |
| `plan → loop → security → ship` | Full feature lifecycle |
| `predict → scenario,debug,fix,ship` | Full quality pipeline |
| `learn → security` | Document first, then audit |
| `reason → predict` | Converge on design, stress-test with experts |
| `reason → plan,fix` | Debate approach, then plan and implement |
| `probe → scenario,debug,fix` | Surface constraints, then full quality pipeline |
| `probe → improve` | Surface constraints, then research improvements + PRDs |
| `predict → improve` | Expert analysis, then product improvement research |
| `loop → evals → ship` | Optimize, analyze results, then ship |
| `predict → regression → fix → ship` | Pre-empt risks, gate against regressions, fix, then ship |

---

## The handoff.json Protocol

Every command that supports `--chain` writes `handoff.json` before invoking the next target. Structure:

```json
{
  "source_command": "predict",
  "timestamp": "2026-05-22T14:30:00Z",
  "scope": ["src/auth/**", "src/api/**"],
  "goal": "Investigate intermittent 500 errors",
  "findings": [...],
  "hypothesis_queue": [...],
  "summary": {...}
}
```

Downstream commands read this file to initialize — never reconstructing context from scratch.

---

## Inline Chain Syntax

```
/autoresearch:predict --chain debug
/autoresearch:predict --chain scenario,debug,fix,ship
/autoresearch:reason --chain predict,scenario
/autoresearch:probe --chain plan
```

Comma-separated targets execute sequentially. Each stage's output feeds directly into the next.

---

## Detailed Pipeline Guides

### probe → plan → loop

**When to use:** Requirements are fuzzy before starting.

```
/autoresearch:probe
Topic: Reduce p95 latency on /search to under 50ms

# Saturates after ~12 rounds, emits autoresearch-config.yml

/autoresearch:plan
Goal: (from probe output)

/autoresearch
Iterations: 25
Goal: Reduce p95 search latency below 50ms
Scope: src/search/**/*.ts
Metric: p95 latency in ms (lower is better)
Verify: npm run bench:search | grep "p95"
Guard: npm test
```

---

### debug → fix

**When to use:** Something is broken and you want it found AND fixed.

```
/autoresearch:debug
Scope: src/**/*.ts
Symptom: Multiple test failures after dependency upgrade
Iterations: 15

/autoresearch:fix --from-debug
Guard: npm test
Iterations: 30
```

**Shortcut:**

```
/autoresearch:debug --fix
Scope: src/**/*.ts
Iterations: 30
```

---

### predict → debug

**When to use:** Intermittent failures, "works on my machine" bugs.

```
/autoresearch:predict --chain debug
Scope: src/auth/**
Goal: Investigate intermittent 500 errors on POST /login
```

Without predict: Claude guesses → tests → wrong → 10 iterations to root cause.
With predict: 5 experts debate → ranked hypotheses → debug tests in order → 2–3 iterations.

---

### scenario → debug → fix

**When to use:** Feature works but you want edge case coverage.

```
/autoresearch:scenario --domain software --focus edge-cases
Scenario: User uploads files through drag-and-drop
Iterations: 20

/autoresearch:debug
Scope: src/upload/**/*.ts
Symptom: edge cases from scenario — concurrent uploads, large files, network drops
Iterations: 15

/autoresearch:fix --from-debug
Guard: npm test
Iterations: 20
```

---

### security → fix → re-audit → ship

**When to use:** Pre-release security hardening.

```
/autoresearch:security --fail-on high
Iterations: 15

/autoresearch:fix --from-debug
Guard: npm test
Iterations: 20

/autoresearch:security --diff
Iterations: 10

/autoresearch:ship --type code-release
```

**Shortcut:**

```
/autoresearch:security --fix --fail-on critical
Iterations: 25
```

---

### loop → evals → ship

**When to use:** Optimize a metric, analyze results, then ship.

```
/autoresearch
Iterations: 25
Goal: Reduce bundle size below 200KB
Verify: npm run build 2>&1 | grep "First Load JS"
Guard: npm test
--evals

/autoresearch:ship --type code-pr --auto
```

---

### predict → scenario,debug,fix,ship

**When to use:** New feature launch, major release, zero context loss.

```
/autoresearch:predict --chain scenario,debug,security,fix,ship
Scope: src/**
Goal: Full quality pipeline for v2.0 release
```

What happens:
1. **Predict** — multi-perspective analysis, ranked findings, risk areas
2. **Scenario** — edge cases from predict's risk areas
3. **Debug** — hunt bugs in identified risk areas
4. **Security** — audit attack vectors from adversarial analysis
5. **Fix** — root-cause-first cascade-aware repairs
6. **Ship** — deploy with full confidence

---

### reason → predict → fix

**When to use:** Subjective design decision that needs empirical validation.

```
/autoresearch:reason --chain predict,fix
Task: Design the caching strategy for our high-traffic API
Domain: software
Iterations: 6
```

1. **Reason** (6 rounds) — generates, critiques, synthesizes. Blind judges converge on the strongest design.
2. **Predict** (auto) — 5 expert personas stress-test the converged design.
3. **Fix** (auto) — implements fixes for any issues predict confirmed.

---

### probe → scenario,debug,fix

**When to use:** Unknown requirements + unknown edge cases + bugs.

```
/autoresearch:probe --chain scenario,debug,fix --scope src/payments/**
Topic: Harden checkout against partial-failure modes
```

probe surfaces constraints → scenario enumerates situations → debug hunts bugs → fix repairs them.

---

### probe → improve

**When to use:** Requirements are fuzzy AND you need product direction.

```
/autoresearch:probe --improve
Topic: Improve checkout conversion for enterprise B2B SaaS
```

probe surfaces constraints → improve reads them as seeds → researches ICP challenges and competitor gaps → ranks improvements → generates PRDs. Improve is a terminal emitter — PRDs go to external tools like `/ck:plan`.

---

### predict → improve

**When to use:** Get expert perspectives, then research improvements.

```
/autoresearch:predict --improve
Scope: src/**
Goal: What should we build next for our enterprise customers?
```

predict identifies risk areas and opportunities → improve uses predictions to seed research categories → generates PRDs.

---

### learn pipeline

```
# Document first, then audit
/autoresearch:learn --mode init
/autoresearch:security

# Check → update (conditional)
/autoresearch:learn --mode check
# If report says "Stale":
/autoresearch:learn --mode update

# Document, then ship docs PR
/autoresearch:learn --mode update
/autoresearch:ship --type code-pr
```

---

## Shortcut Flags

| Flag | Effect |
|------|--------|
| `debug --fix` | Debug → fix auto-transition, no manual step |
| `security --fix` | Auto-fix Critical/High after audit |
| `fix --from-debug` | Fix reads previous debug findings |
| `predict --chain` | Auto-chains to specified next command(s) |
| `security --diff` | Only audit files changed since last security run |
| `security --fail-on critical` | Exit non-zero for CI/CD gating |
| `--evals` | Analyze results TSV after loop |
| `--evals-interval N` | Checkpoint analysis every N iterations |

---

## What Each Command Produces

```
improve  →  research-findings.md, improvement-plan.md, prd-*.md, handoff.json (terminal)
probe    →  constraints.tsv, autoresearch-config.yml, handoff.json
predict  →  ranked findings, hypothesis queue, handoff.json
scenario →  edge cases, failure modes, use case map
debug    →  bug list with file:line, severity ratings
security →  vulnerability list with OWASP/STRIDE tags
fix      →  repaired code, guard-verified
loop     →  metric improvements, committed changes, results TSV
evals    →  trend analysis, plateau detection, recommendation
regression → stability verdict (STABLE/UNSTABLE), per-dim score math, handoff.json
ship     →  PR / release / deployment artifact
```

**Design rule:** each stage's output sharpens the next stage's input. Vague debug findings mean security won't have enough context. Generic scenarios miss domain-specific risks.

---

## Context Preservation

Context flows forward automatically — you never summarize one stage and paste it into the next:

- `debug` writes findings to `debug-results.tsv` — `fix --from-debug` reads it
- `predict` writes analysis to `codebase-analysis.md` — downstream stages read it
- `security` writes audit to `security/` — `security --diff` diffs against it
- `ship` reads the full git history to understand what changed and why
- Every `--chain` command writes `handoff.json` — the universal bridge

---

## Related Guides

- [getting-started.md](getting-started.md) — platform syntax and installation
- [advanced-patterns.md](advanced-patterns.md) — CI/CD, MCP, evals in pipelines
- [examples-by-domain.md](examples-by-domain.md) — domain-specific chain examples
