# Chains & Combinations — Multi-Command Pipelines

The real power of autoresearch comes from chaining commands together. Each command's output feeds the next. A single `debug` run finds bugs; chaining it with `fix` repairs them automatically. Adding `ship` deploys the result. The context is preserved throughout — no copy-pasting findings between steps.

---

## Quick Reference Table

| Chain | When to Use |
|-------|-------------|
| `plan → loop` | Starting a new metric improvement |
| `debug → fix` | Bug is known, needs finding and fixing |
| `predict → debug` | Intermittent failures, compound issues |
| `predict → security` | Pre-deployment security review |
| `scenario → debug` | Feature works but want edge case coverage |
| `security → fix → security` | Harden, fix, verify fixes |
| `loop → ship` | Optimization complete, time to deploy |
| `scenario → loop` | Discover use cases, then optimize |
| `debug → fix → ship` | Production issue: find, fix, deploy |
| `plan → loop → security → ship` | Full feature lifecycle |
| `scenario → security` | Threat modeling from user scenarios |
| `fix → loop → ship` | Fix blockers, then improve, then deploy |
| `predict → scenario,debug,fix,ship` | Full quality pipeline |
| `learn → security` | New codebase: document it, then audit it |
| `learn → predict` | Document, then get multi-expert analysis |
| `learn:check → learn:update` | Check health first, update if stale |
| `learn → scenario` | Document, then stress-test edge cases |
| `reason → predict` | Converge on design, then get multi-expert validation |
| `reason → plan,fix` | Debate approach, then plan and implement |
| `reason → scenario` | Converge on design, then stress-test edge cases |
| `predict → reason` | Identify issues, then debate solutions |
| `scenario → reason` | Discover edge cases, then debate how to handle them |
| `reason → debug,fix,ship` | Full subjective pipeline: debate → validate → fix → deploy |

---

## Detailed Pipeline Guides

### The Debug → Fix Pipeline

**When to use:** Something is broken and you want it found AND fixed.

**Full config:**

```
# Step 1: Find all bugs (15 iterations of investigation)
/autoresearch:debug
Scope: src/**/*.ts
Symptom: Multiple test failures after dependency upgrade
Iterations: 15

# Step 2: Fix everything found (30 iterations of repairs)
/autoresearch:fix --from-debug
Guard: npm test
Iterations: 30
```

**Shortcut (auto-transitions from debug to fix):**

```
/autoresearch:debug --fix
Scope: src/**/*.ts
Iterations: 30
```

**What happens:**
1. Debug phase scans the codebase, runs tests/lint/typecheck, investigates each failure with the scientific method
2. Each iteration tests one hypothesis — confirmed bugs are logged to findings
3. Fix phase reads the findings, orders repairs by severity and cascade impact
4. Each fix iteration applies one repair, runs the guard, keeps or reverts
5. Continues until all findings are resolved or iterations exhausted

**Time estimate:** 15 debug + 30 fix iterations ~ 45 minutes for a typical project

---

### The Scenario → Debug → Fix Pipeline

**When to use:** You want to discover edge cases, then find bugs in them, then fix them.

**Full config:**

```
# Step 1: Discover edge cases (25 iterations)
/autoresearch:scenario --domain software --focus edge-cases
Scenario: User uploads files through the drag-and-drop interface
Iterations: 25

# Step 2: Hunt bugs in discovered scenarios (15 iterations)
/autoresearch:debug
Scope: src/upload/**/*.ts
Symptom: Edge cases from scenario exploration — concurrent uploads, large files, network interruptions
Iterations: 15

# Step 3: Fix what was found (20 iterations)
/autoresearch:fix --from-debug
Guard: npm test
Iterations: 20
```

**What happens:**
1. Scenario explorer maps the feature space — happy paths, failure modes, edge cases, abuse cases
2. Findings surface specific risk areas (e.g., "no timeout on stalled uploads")
3. Debug phase uses scenario findings as targeted symptom hints, skipping generic scans
4. Fix phase repairs in cascade-safe order

**Time estimate:** 25 + 15 + 20 iterations ~ 60 minutes

---

### The Plan → Loop → Ship Pipeline

**When to use:** Starting a new improvement initiative from scratch.

**Full config:**

```
# Step 1: Figure out the right config
/autoresearch:plan
Goal: Improve API response times across all endpoints

# Step 2: Run the loop (plan wizard gives you the exact config)
/autoresearch
Iterations: 50
Goal: Reduce p95 API response time to under 100ms
Scope: src/api/**/*.ts
Metric: p95 latency in ms (lower is better)
Verify: npm run bench:api | grep "p95"
Guard: npm test

# Step 3: Ship the improvements
/autoresearch:ship --type code-pr --auto
```

**What happens:**
1. Plan wizard detects your tech stack, suggests scope/metric/verify command, runs a dry-run to confirm baseline
2. Loop iterates — each experiment tries one change, measures the metric, keeps if improved, reverts if not
3. Ship workflow verifies readiness (tests, types, lint, build), creates a PR with context from loop history

**Time estimate:** Plan (interactive, ~5 min) + 50 iterations (varies) + Ship (5 min)

---

### The Security → Fix → Ship Pipeline

**When to use:** Pre-release security hardening.

**Full config:**

```
# Step 1: Find vulnerabilities (15 iterations)
/autoresearch:security
Scope: src/**/*.ts
Iterations: 15

# Step 2: Auto-fix Critical and High findings (20 iterations)
/autoresearch:fix --from-debug
Guard: npm test
Iterations: 20

# Step 3: Re-audit to confirm fixes (10 iterations)
/autoresearch:security --diff
Iterations: 10

# Step 4: Ship when clean
/autoresearch:ship --type code-release
```

**Shortcut (combined: audit + auto-fix + CI gate):**

```
/autoresearch:security --fix --fail-on critical
Iterations: 25
```

**What happens:**
1. Security audit builds a STRIDE threat model, walks OWASP Top 10, logs every finding with code evidence
2. Fix phase reads security findings, orders by severity (Critical first), repairs each
3. Re-audit (`--diff`) only checks files touched since last audit — confirms patches landed
4. Ship workflow runs final readiness check before deploy

**Time estimate:** 15 + 20 + 10 iterations + ship ~ 75 minutes

---

### The Full Development Lifecycle

**When to use:** Building a feature from conception to shipping.

**Full config:**

```
# 1. Explore scenarios and edge cases
/autoresearch:scenario --domain software --depth deep
Scenario: New payment processing feature with multiple providers
Iterations: 30

# 2. Plan the improvement approach
/autoresearch:plan
Goal: Implement payment processing with 95%+ test coverage

# 3. Build iteratively with test coverage as metric
/autoresearch
Iterations: 50
Goal: Increase payment module test coverage to 95%
Scope: src/payments/**/*.ts, src/payments/**/*.test.ts
Metric: coverage % (higher is better)
Verify: npm test -- --coverage --collectCoverageFrom='src/payments/**' | grep "All files"

# 4. Security audit the payment code
/autoresearch:security
Scope: src/payments/**/*.ts
Focus: Payment processing, PCI DSS, data encryption
Iterations: 15

# 5. Fix any security findings
/autoresearch:fix --from-debug
Guard: npm test
Iterations: 20

# 6. Ship it
/autoresearch:ship --type code-pr
```

**What happens:**
1. Scenario explorer maps the full feature space before a line of code is written
2. Plan wizard generates the exact loop config based on scenario findings
3. Loop builds the feature iteratively, each commit improving coverage
4. Security audit validates the implementation against payment-specific threats (PCI DSS, encryption, injection)
5. Fix resolves any findings with tests-as-guard to prevent regressions
6. Ship packages everything into a PR with full context

**Time estimate:** 30 + 50 + 15 + 20 iterations + plan/ship overhead ~ 3-4 hours

---

### The Predict → Debug Pipeline (NEW in v1.7.0)

**When to use:** Intermittent failures, "works on my machine" bugs, compound issues.

**Full config:**

```
/autoresearch:predict --chain debug
Scope: src/auth/**
Goal: Investigate intermittent 500 errors
```

**What happens:**
1. 5 personas analyze auth code independently (Architecture Reviewer, Security Analyst, Performance Engineer, Reliability Engineer, Devil's Advocate)
2. Debate phase: each persona presents their hypothesis with supporting evidence
3. Consensus: ranked hypothesis queue (e.g., connection pool 60%, race condition 25%, infra 15%)
4. Debug loop tests hypotheses in priority order — finds root cause in 2-4 iterations instead of 10+

**Without predict:** Claude guesses → tests → wrong → guesses again → 10 iterations to root cause.
**With predict:** 5 experts debate → ranked hypotheses → debug tests in order → 2-3 iterations to root cause.

**Time estimate:** Predict phase (~5 min) + 5-10 debug iterations ~ 20 minutes total

---

### The Predict → Security Pipeline (NEW in v1.7.0)

**When to use:** Pre-deployment security review, compliance audits.

**Full config:**

```
/autoresearch:predict --adversarial --chain security
Scope: src/api/**, src/auth/**
Goal: Security audit before production deploy
```

**What happens:**
1. Adversarial persona set: Red Team Attacker finds exploits, Blue Team Defender validates defenses, Insider Threat examines privilege escalation, Supply Chain Analyst audits dependencies, Judge evaluates evidence quality
2. Debate surfaces multi-step attack chains, not just individual vulnerabilities
3. Attack vectors ranked by exploitability
4. Security audit starts with pre-ranked vectors instead of walking the OWASP checklist sequentially

**Without predict:** Single agent walks OWASP checklist → finds individual vulnerabilities.
**With predict:** 5 adversarial personas find multi-step attack chains → security validates each with code evidence.

**Time estimate:** Predict phase (~5 min) + 15 security iterations ~ 35 minutes

---

### The Full Predict Pipeline (NEW in v1.7.0)

**When to use:** New feature launch, major release, zero-context-loss quality pipeline.

**Full config:**

```
/autoresearch:predict --chain scenario,debug,security,fix,ship
Scope: src/**
Goal: Full quality pipeline before release
```

**What happens:**
1. **Predict** — Multi-perspective analysis, ranked findings, risk areas identified
2. **Scenario** — Generate edge cases and failure modes from predict findings
3. **Debug** — Hunt bugs in identified risk areas using findings as targeted hints
4. **Security** — Audit attack vectors from predict's adversarial analysis
5. **Fix** — Fix everything found, cascade-aware ordering (root causes before downstream effects)
6. **Ship** — Deploy with confidence, informed by all prior stages

**Time estimate:** Full pipeline ~ 2-3 hours for a medium codebase

---

### The Learn Pipeline

Documentation is the foundation — learn the codebase first, then chain to specialized commands.

**Learn → Security:**

```
/autoresearch:learn --mode init --depth deep
/autoresearch:security
Iterations: 15
```

First pass: generate comprehensive docs. Second pass: security audit uses the docs as context to find blind spots faster.

**Learn → Predict → Debug:**

```
/autoresearch:learn --mode update
/autoresearch:predict --chain debug
```

Update docs, then predict issues from multiple expert angles, then debug the most likely ones.

**Check → Update (Conditional):**

```
/autoresearch:learn --mode check
# If report says "Stale" or "Needs attention":
/autoresearch:learn --mode update
```

Lightweight health check before committing to a full update cycle. Saves time when docs are already fresh.

---

### The Reason → Predict → Fix Pipeline

**When to use:** Subjective design decision that needs empirical validation.

**Full config:**

```
# Step 1: Adversarially refine the architecture proposal
/autoresearch:reason --chain predict,fix
Task: Design the caching strategy for our high-traffic API
Domain: software
Iterations: 6
```

**What happens:**
1. **Reason** (6 rounds): Generates, critiques, and synthesizes caching proposals. Blind judges converge on the strongest design.
2. **Predict** (auto): 5 expert personas independently stress-test the converged design. May find issues judges missed.
3. **Fix** (auto): Implements fixes for any issues predict confirmed.

**The key principle:** Reason's blind judges are a subjective fitness function — they determine what's "best" when no metric exists. Predict's expert personas then validate empirically. If predict disproves reason's consensus, the empirical evidence wins.

---

## Shortcut Flags

These flags collapse multi-step chains into a single command:

| Flag | Effect |
|------|--------|
| `debug --fix` | Debug phase auto-transitions to fix when done, no manual step needed |
| `security --fix` | Auto-fix Critical/High findings immediately after audit |
| `fix --from-debug` | Fix phase reads previous debug findings instead of re-scanning |
| `predict --chain` | Auto-chains predict output into the specified next command(s) |
| `security --diff` | Only audit files changed since last security run |
| `security --fail-on critical` | Exit non-zero for CI/CD gating on critical findings |

**Combining flags:**

```bash
# Delta security + auto-fix + CI gate in one command
/autoresearch:security --diff --fix --fail-on critical --iterations 15

# Quick overnight full pipeline
/autoresearch:predict --chain scenario,debug,security,fix,ship

# Controlled debug-then-fix sprint (45 iterations total)
/autoresearch:debug --fix
Iterations: 45
```

---

## Building Custom Chains

Think about chains in terms of **what each command produces** and **what the next command consumes**:

```
predict  →  ranked findings, risk areas, hypothesis queue
scenario →  edge cases, failure modes, use case map
debug    →  bug list with file:line evidence, severity ratings
security →  vulnerability list with OWASP/STRIDE tags
fix      →  repaired code, guard-verified
loop     →  metric improvement, committed changes
ship     →  PR/release/deployment artifact
```

**Design rule:** each stage's output should sharpen the next stage's input. If debug findings are vague, security won't have enough context to focus. If scenario only maps happy paths, debug won't know where to look.

**Common custom chains:**

```bash
# Scraper hardening: discover what breaks, then fix it
/autoresearch:scenario --domain software --focus edge-cases
Scenario: Web scraper hits anti-bot measures and rate limits

/autoresearch:debug
Scope: scrapers/**/*.py
Symptom: Edge cases from scenario — CAPTCHAs, IP blocking, infinite scroll

/autoresearch:fix --from-debug
Guard: python -m pytest tests/scrapers/

# Content pipeline: optimize then publish
/autoresearch
Iterations: 25
Goal: Maximize SEO score for blog post

/autoresearch:ship
Target: content/blog/my-post.md
Type: content
```

---

## Chain Decision Flowchart

```
                    START
                      |
          +-----------+-----------+
          |           |           |
    Something      Need edge    Starting
     broken?       cases?        fresh?
          |           |           |
        debug      scenario     plan
          |           |           |
         fix         debug      loop
          |           |           |
      (optional)     fix         |
         ship         |         ship
                     ship
                      |
          +-----------+-----------+
          |           |           |
    Need          Pre-deploy    Full
   security?       review?    pipeline?
          |           |           |
       security    predict    predict
          |      --adversarial    |
          fix         |       scenario,
          |        security    debug,
       security       |       security,
       --diff         fix       fix,
          |           |         ship
         ship        ship
```

**Quick decision guide:**

```
Something broken?          → debug → fix → ship
Need edge cases?           → scenario → debug → fix
Need security?             → predict --adversarial → security → fix → ship
Starting fresh?            → plan → loop → ship
Full pipeline?             → predict → scenario,debug,security,fix,ship
Production incident?       → predict --chain debug → fix → ship
Compliance audit?          → security → fix → security --diff → ship
Post-upgrade breakage?     → predict --chain fix → ship
```

---

## Context Preservation Across Stages

A key benefit of chaining: context flows forward automatically.

- `debug` writes findings to `debug-results.tsv` — `fix --from-debug` reads it
- `predict` writes analysis to `codebase-analysis.md` — downstream stages read it
- `security` writes audit to `security/` folder — `security --diff` diffs against it
- `ship` reads the full git history to understand what changed and why

You never need to summarize one stage's output and paste it into the next. The chain does it for you.

---

*Related: [getting-started.md](./getting-started.md) · [autoresearch.md](./autoresearch.md) · [autoresearch-debug.md](./autoresearch-debug.md)*
