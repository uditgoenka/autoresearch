<div align="center">

# Autoresearch

**Turn [Claude Code](https://docs.anthropic.com/en/docs/claude-code), [OpenCode](https://opencode.ai), or [OpenAI Codex](https://developers.openai.com/codex) into a relentless improvement engine.**

Based on [Karpathy's autoresearch](https://github.com/karpathy/autoresearch) — constraint + mechanical metric + autonomous iteration = compounding gains.

[![Claude Code Skill](https://img.shields.io/badge/Claude_Code-Skill-blue?logo=anthropic&logoColor=white)](https://docs.anthropic.com/en/docs/claude-code)
[![OpenCode](https://img.shields.io/badge/OpenCode-Skill-purple)](https://opencode.ai)
[![Codex](https://img.shields.io/badge/Codex-Skill-green?logo=openai&logoColor=white)](https://developers.openai.com/codex)
[![Version](https://img.shields.io/badge/version-2.0.03-blue.svg)](https://github.com/uditgoenka/autoresearch/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

[![Based on](https://img.shields.io/badge/Based_on-Karpathy's_Autoresearch-orange)](https://github.com/karpathy/autoresearch)
[![Follow @iuditg](https://img.shields.io/badge/Follow-@iuditg-000000?style=flat&logo=x&logoColor=white)](https://x.com/intent/follow?screen_name=iuditg)
[![Support](https://img.shields.io/badge/Support-PayPal-00457C?style=flat&logo=paypal&logoColor=white)](https://paypal.me/uditgoenka)

<br>

*"Set the GOAL → The agent runs the LOOP → You wake up to results"*

*You don't need AGI. You need a goal, a metric, and a loop that never quits.*

**Now supports Claude Code, OpenCode, and OpenAI Codex.**

<br>

[How It Works](#how-it-works) · [Commands](#commands) · [Quick Start](#quick-start) · [Guides](guide/) · [FAQ](#faq)

</div>

---

```
      PLAN              LOOP             DEBUG              FIX            SECURE            SHIP
 ┌──────────┐     ┌──────────┐     ┌──────────┐     ┌──────────┐     ┌──────────┐     ┌──────────┐
 │   Goal   │     │  Modify  │     │   Find   │     │   Fix    │     │  STRIDE  │     │  Stage   │
 │  Metric  │────▶│  Verify  │────▶│   Bugs   │────▶│  Errors  │────▶│  OWASP   │────▶│  Deploy  │
 │  Scope   │     │  Keep/   │     │  Trace   │     │  Repair  │     │  Red     │     │ Release  │
 └──────────┘     │  Discard │     └──────────┘     └──────────┘     │  Team    │     └──────────┘
/autoresearch:    └──────────┘    /autoresearch:    /autoresearch:   └──────────┘    /autoresearch:
  plan            /autoresearch     debug              fix          /autoresearch:      ship
                                                                     security

 ┌──────────┐     ┌──────────┐     ┌──────────┐     ┌──────────┐     ┌──────────┐
 │  Probe   │     │ Scenario │     │ Predict  │     │  Learn   │     │  Reason  │
 │ Require- │     │   Edge   │     │ 5-Expert │     │   Docs   │     │  Debate  │
 │  ments   │     │   Cases  │     │  Swarm   │     │   Gen    │     │ Converge │
 └──────────┘     └──────────┘     └──────────┘     └──────────┘     └──────────┘
/autoresearch:   /autoresearch:   /autoresearch:   /autoresearch:   /autoresearch:
  probe            scenario         predict           learn           reason
```

---

## Why This Exists

[Karpathy's autoresearch](https://github.com/karpathy/autoresearch) demonstrated that a 630-line Python script could autonomously improve ML models overnight — **100 experiments per night** — by following simple principles: one metric, constrained scope, fast verification, automatic rollback, git as memory.

**Claude Autoresearch generalizes these principles to ANY domain.** Not just ML — code, content, marketing, sales, HR, DevOps, or anything with a number you can measure.

---

## How It Works

```
LOOP (FOREVER or N times):
  1. Review current state + git history + results log
  2. Pick the next change (based on what worked, what failed, what's untried)
  3. Make ONE focused change
  4. Git commit (before verification)
  5. Run mechanical verification (tests, benchmarks, scores)
  6. If improved → keep. If worse → git revert. If crashed → fix or skip.
  7. Log the result
  8. Repeat. Never stop until you interrupt (or N iterations complete).
```

Every improvement stacks. Every failure auto-reverts. Progress is logged in TSV format.

### The Setup Phase

Before looping, Claude performs a one-time setup:

1. **Read context** — reads all in-scope files
2. **Define goal** — extracts or asks for a mechanical metric
3. **Define scope** — which files can be modified vs read-only
4. **Establish baseline** — runs verification on current state (iteration #0)
5. **Confirm and go** — shows setup, then begins the loop

### 8 Critical Rules

| # | Rule |
|---|------|
| 1 | **Loop until done** — unbounded: forever. Bounded: N times then summarize |
| 2 | **Read before write** — understand full context before modifying |
| 3 | **One change per iteration** — atomic changes. If it breaks, you know why |
| 4 | **Mechanical verification only** — no subjective "looks good." Use metrics |
| 5 | **Automatic rollback** — failed changes revert instantly |
| 6 | **Simplicity wins** — equal results + less code = KEEP |
| 7 | **Git is memory** — experiments committed with `experiment:` prefix, `git revert` preserves failed experiments in history, agent MUST read `git log` + `git diff` before each iteration |
| 8 | **When stuck, think harder** — re-read, combine near-misses, try radical changes |

---

## Commands

| Command | What it does |
|---------|--------------|
| `/autoresearch` | Run the autonomous iteration loop (unlimited) |
| `Iterations: N` | Add to inline config to run exactly N iterations then stop |
| `/autoresearch:plan` | Interactive wizard: Goal → Scope, Metric, Verify config |
| `/autoresearch:security` | Autonomous STRIDE + OWASP + red-team security audit |
| `/autoresearch:ship` | Universal shipping workflow (code, content, marketing, sales, research, design) |
| `/autoresearch:debug` | Autonomous bug-hunting loop — scientific method + iterative investigation |
| `/autoresearch:fix` | Autonomous fix loop — iteratively repair errors until zero remain |
| `/autoresearch:scenario` | Scenario-driven use case generator — explore situations, edge cases, derivative scenarios |
| `/autoresearch:predict` | Multi-persona prediction | Pre-analyze code from 5 expert perspectives before acting |
| `/autoresearch:learn` | Autonomous documentation engine — scout codebase, generate/update docs, validate, fix loop |
| `/autoresearch:reason` | Adversarial refinement — blind judge panel converges subjective content through isolated multi-agent debate |
| `/autoresearch:probe` | Adversarial requirement / assumption interrogation — 8 personas probe user + codebase until net-new constraints saturate, emits ready-to-run autoresearch config |
| `Guard: <command>` | Optional safety net — must pass for changes to be kept |

**All commands use interactive setup when invoked without arguments.** Just type the command — the agent will ask you what you need step by step with smart defaults based on your codebase. Power users can skip the wizard by providing flags inline.

> **OpenCode users:** Commands use underscore naming (`/autoresearch_debug`, `/autoresearch_fix`, etc.) instead of colons. See [OpenCode Quick Start](#opencode-quick-start) below.
>
> **Codex users:** Invoke the skill via `$autoresearch` mention syntax. Subcommands are keywords: `$autoresearch plan`, `$autoresearch debug`, etc. See [Codex Quick Start](#codex-quick-start) below.

### Quick Decision Guide

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
| Check if docs are stale | `/autoresearch:learn --mode check` |
| Debate an architecture decision | `/autoresearch:reason --domain software` |
| Refine a pitch or proposal adversarially | `/autoresearch:reason --domain business` |
| Converge on best design then validate | `/autoresearch:reason --chain predict` |
| Surface hidden constraints before starting | `/autoresearch:probe` |
| Pre-flight a fuzzy goal then loop | `/autoresearch:probe --chain plan,autoresearch` |
| Stress-test requirements adversarially | `/autoresearch:probe --adversarial --depth deep` |

---

## Quick Start

### Claude Code

**Option A — npx install (recommended):**

```bash
npx skills add uditgoenka/autoresearch
```

That's it. All 11 commands are available after restarting Claude Code.

**Option B — Plugin install:**

In Claude Code, run:
```
/plugin marketplace add uditgoenka/autoresearch
/plugin install autoresearch@autoresearch
```

> **Note:** Start a new Claude Code session after installing. Reference files aren't resolvable in the same session where installation happened — this is a Claude Code platform limitation.

**Updating (no reinstall needed):**
```
/plugin update autoresearch
```

That pulls the latest version. Run `/reload-plugins` to activate. No need to uninstall or re-clone.

**Option C — Manual copy:**
```bash
git clone https://github.com/uditgoenka/autoresearch.git

# Copy skill + subcommands to your project
cp -r autoresearch/claude-plugin/skills/autoresearch .claude/skills/autoresearch
cp -r autoresearch/claude-plugin/commands/autoresearch .claude/commands/autoresearch
cp autoresearch/claude-plugin/commands/autoresearch.md .claude/commands/autoresearch.md
```

Or install globally:
```bash
cp -r autoresearch/claude-plugin/skills/autoresearch ~/.claude/skills/autoresearch
cp -r autoresearch/claude-plugin/commands/autoresearch ~/.claude/commands/autoresearch
cp autoresearch/claude-plugin/commands/autoresearch.md ~/.claude/commands/autoresearch.md
```

> **Note:** The `commands/` directory is required for subcommands (`/autoresearch:ship`, `/autoresearch:plan`, `/autoresearch:security`) to work.

**Option D — Guided installer:**
```bash
git clone https://github.com/uditgoenka/autoresearch.git
cd autoresearch
./scripts/install.sh --claude --global
```

### OpenCode Quick Start

**Option A — Guided installer (recommended):**
```bash
git clone https://github.com/uditgoenka/autoresearch.git
cd autoresearch
./scripts/install.sh --opencode --global
```

**Option B — Manual copy:**
```bash
git clone https://github.com/uditgoenka/autoresearch.git

# Copy to your project
cp -r autoresearch/.opencode/skills/autoresearch .opencode/skills/autoresearch
cp autoresearch/.opencode/commands/autoresearch*.md .opencode/commands/
cp autoresearch/.opencode/agents/docs-manager.md .opencode/agents/docs-manager.md
```

Or install globally:
```bash
cp -r autoresearch/.opencode/skills/autoresearch ~/.config/opencode/skills/autoresearch
cp autoresearch/.opencode/commands/autoresearch*.md ~/.config/opencode/commands/
cp autoresearch/.opencode/agents/docs-manager.md ~/.config/opencode/agents/docs-manager.md
```

> **OpenCode command names:** Use underscores instead of colons — `/autoresearch_debug`, `/autoresearch_fix`, `/autoresearch_plan`, etc. All 11 commands are available.

### Codex Quick Start

**Option A — Guided installer (recommended):**
```bash
git clone https://github.com/uditgoenka/autoresearch.git
cd autoresearch
./scripts/install.sh --codex --global
```

**Option B — Manual copy:**
```bash
git clone https://github.com/uditgoenka/autoresearch.git

# Copy to your project
cp -r autoresearch/.agents/skills/autoresearch .codex/skills/autoresearch
```

Or install globally:
```bash
cp -r autoresearch/.agents/skills/autoresearch ~/.codex/skills/autoresearch
```

> **Codex invocation:** Use `$autoresearch` mention syntax in your prompt. Subcommands are keywords — `$autoresearch plan`, `$autoresearch debug`, `$autoresearch security`, etc. Codex discovers installed skills from `${CODEX_HOME:-~/.codex}/skills` and project-local `.codex/skills/` directories.

### 2. Run It

```
/autoresearch
Goal: Increase test coverage from 72% to 90%
Scope: src/**/*.test.ts, src/**/*.ts
Metric: coverage % (higher is better)
Verify: npm test -- --coverage | grep "All files"
```

### 3. Walk Away

Claude reads all files, establishes a baseline, and starts iterating — one change at a time. Keep improvements, auto-revert failures, log everything. **Never stops until you interrupt** (or N iterations complete).

---

## /autoresearch:plan — Goal → Config Wizard

The hardest part isn't the loop — it's defining Scope, Metric, and Verify correctly. `/autoresearch:plan` converts your plain-language goal into a validated, ready-to-execute configuration.

```
/autoresearch:plan
Goal: Make the API respond faster
```

The wizard walks you through 5 steps: capture goal → define scope → define metric → define direction → validate verify command (dry-run). Every gate is mechanical — scope must resolve to files, metric must output a number, verify must pass a dry-run.

---

## /autoresearch:security — Autonomous Security Audit

Read-only security audit using STRIDE threat modeling, OWASP Top 10 sweeps, and red-team adversarial analysis with 4 hostile personas.

```
/autoresearch:security
Iterations: 10
```

**What it does:** Codebase recon → asset inventory → trust boundaries → STRIDE threat model → attack surface map → autonomous testing loop → structured report.

Every finding requires **code evidence** (file:line + attack scenario). No theoretical fluff.

| Flag | Purpose |
|------|---------|
| `--diff` | Only audit files changed since last audit |
| `--fix` | Auto-fix confirmed Critical/High findings |
| `--fail-on <severity>` | Exit non-zero for CI/CD gating |

**Output:** Creates `security/{date}-{slug}/` with 7 structured report files.

---

## /autoresearch:ship — Universal Shipping Workflow

Ship anything through 8 phases: **Identify → Inventory → Checklist → Prepare → Dry-run → Ship → Verify → Log.**

```
/autoresearch:ship --auto
```

Auto-detects what you're shipping (code PR, deployment, blog post, email campaign, sales deck, research paper, design assets) and generates domain-specific checklists — every item mechanically verifiable.

| Flag | Purpose |
|------|---------|
| `--dry-run` | Validate everything but don't ship |
| `--auto` | Auto-approve if checklist passes |
| `--force` | Skip non-critical items (blockers still enforced) |
| `--rollback` | Undo last ship action |
| `--monitor N` | Post-ship monitoring for N minutes |
| `--type <type>` | Override auto-detection |
| `--checklist-only` | Just check readiness |

**9 supported types:** code-pr, code-release, deployment, content, marketing-email, marketing-campaign, sales, research, design.

---

## /autoresearch:debug — Autonomous Bug Hunter (v1.3.0)

Scientific method meets autoresearch loop. Doesn't stop at one bug — iteratively hunts ALL bugs using falsifiable hypotheses, evidence-based investigation, and 7 investigation techniques.

```
/autoresearch:debug
Scope: src/api/**/*.ts
Symptom: API returns 500 on POST /users
Iterations: 20
```

**How it works:** Gather symptoms → Recon (map error surface) → Hypothesize (specific, testable) → Test (one experiment per iteration) → Classify (confirmed/disproven/inconclusive) → Log → Repeat.

Every finding requires **code evidence** (file:line + reproduction steps). Every disproven hypothesis is logged — equally valuable. Uses 7 techniques: binary search, differential debugging, minimal reproduction, trace execution, pattern search, working backwards, rubber duck.

| Flag | Purpose |
|------|---------|
| `--fix` | After hunting, auto-switch to `/autoresearch:fix` |
| `--scope <glob>` | Limit investigation scope |
| `--symptom "<text>"` | Pre-fill symptom |
| `--severity <level>` | Minimum severity to report |

---

## /autoresearch:fix — Autonomous Error Crusher (v1.3.0)

Takes a broken state and iteratively repairs it until everything passes. ONE fix per iteration. Atomic, committed, verified, auto-reverted on failure.

```
/autoresearch:fix
```

**How it works:** Auto-detects what's broken (tests, types, lint, build) → Prioritizes (blockers first) → Fixes ONE thing → Commits → Verifies error count decreased → Guard check (no regressions) → Keep/Revert → Repeat until zero errors.

**Stops automatically when error count hits zero** — even in unbounded mode.

| Flag | Purpose |
|------|---------|
| `--target <command>` | Explicit verify command |
| `--guard <command>` | Safety command that must always pass |
| `--category <type>` | Only fix specific type (test, type, lint, build) |
| `--from-debug` | Read findings from latest debug session |

**Chain them:** Run `/autoresearch:debug` with `Iterations: 15`, then `/autoresearch:fix --from-debug` with `Iterations: 30`

---

## /autoresearch:learn — Autonomous Documentation Engine

Scout codebase → generate docs → validate → fix → repeat. 4 modes: init (create from scratch), update (refresh existing), check (read-only health report), summarize (quick overview).

```
/autoresearch:learn --mode init --depth deep
```

Dynamic doc discovery (scans `docs/*.md`), project-type detection, validation-fix loop (max 3 retries), scale-aware scouting, git-diff scoping for updates, selective single-doc update with `--file`. Auto-generates Mermaid architecture diagrams, conditional docs (API reference, testing guide, config guide, changelog), cross-reference links between docs, and dependency documentation. Supports `--format` for alternative output formats.

---

## /autoresearch:predict — Multi-Persona Prediction (v1.7.0)

Before you debug, fix, or ship — get 5 expert perspectives in 2 minutes.

`/autoresearch:predict` simulates a team of experts (Architect, Security Analyst, Performance Engineer, Reliability Engineer, Devil's Advocate) who independently analyze your code, debate findings, and reach consensus. Chain the output directly to any other command:

- `/autoresearch:predict --chain debug` — pre-ranked hypotheses before debugging
- `/autoresearch:predict --chain security` — multi-persona red team analysis
- `/autoresearch:predict --chain scenario,debug,fix` — full quality pipeline

---

## /autoresearch:reason — Adversarial Refinement (v1.9.0)

Extends autoresearch to **subjective domains** where no objective metric exists. The blind judge panel IS the fitness function — it's val_bpb for architecture decisions, product strategy, content quality, and design debates.

```
/autoresearch:reason
Task: Should we use event sourcing for our order management system?
Domain: software
Iterations: 8
```

**How it works:** Generate-A → Critic attacks (strawman) → Author-B responds → Synthesizer merges → Blind judge panel (randomized labels) picks winner → Winner becomes new A → Repeat until convergence.

**Key invariant:** Every agent is a cold-start fresh invocation — no shared session, no history bleed. Judges never see A/B/AB labels, only X/Y/Z.

| Flag | Purpose |
|------|---------|
| `--iterations N` | Bounded mode — run exactly N rounds |
| `--judges N` | Judge count (3-7, odd preferred) |
| `--convergence N` | Consecutive wins to converge (default: 3) |
| `--mode <mode>` | convergent (default), creative, debate |
| `--domain <type>` | software, product, business, security, research, content |
| `--chain <targets>` | Chain converged output to any autoresearch command |

**Chain patterns:** `reason → predict` (converge then stress-test), `reason → plan,fix` (converge then implement), `reason → scenario` (converge then explore edge cases).

**Output:** Creates `reason/{date}-{slug}/` with lineage.md, candidates.md, judge-transcripts.md, reason-results.tsv, handoff.json.

---

## /autoresearch:probe — Adversarial Requirement Interrogation (v1.10.0)

The requirement-clarification layer for autoresearch. Eight adversarial personas interrogate user and codebase together until net-new constraints per round drop below a threshold (mechanical saturation). Output is the 5 autoresearch primitives (Goal/Scope/Metric/Direction/Verify) plus a `handoff.json` ready to feed any other autoresearch command.

```
/autoresearch:probe
Topic: Reduce p99 latency below 200ms for /search

# Pre-flight pipeline — probe → plan → loop
/autoresearch:probe --chain plan,autoresearch
Topic: Add multi-tenant isolation to the database layer
```

**How it works:** Seed Capture → Persona Activation → Codebase Grounding → Round Generation (each persona drafts cold-start questions) → Synthesis (dedupe, cap ≤5) → Answer Capture (single batched `AskUserQuestion`) → Constraint Extraction (7 atom types) → Cross-Check → Saturation Check → Synthesize & Handoff.

**The 8 personas:** Skeptic, Edge-Case Hunter, Scope Sentinel, Ambiguity Detective, Contradiction Finder, Prior-Art Investigator, Success-Criteria Auditor, Constraint Excavator. Each is cold-start within a round — no persona sees others' candidate questions until synthesis. `--adversarial` rotates Skeptic + Contradiction Finder + Edge-Case Hunter to the front.

| Flag | Purpose |
|------|---------|
| `--depth <level>` | shallow (5 rounds), standard (15), deep (30) |
| `--personas N` | active persona count (3-8, default 6) |
| `--saturation-threshold N` | net-new atoms threshold (default 2, window K=3) |
| `--scope <glob>` | codebase glob for grounding |
| `--chain <targets>` | downstream commands: plan, predict, debug, scenario, reason, fix, ship, learn |
| `--mode <mode>` | interactive (default) or autonomous (self-answer with confidence labels) |
| `--adversarial` | rotate the 3 most adversarial personas to the front |
| `--iterations N` | hard cap on rounds, overrides `--depth` |

**Mechanical saturation:** probe stops when net-new constraints fall below the threshold for K consecutive rounds — not when it "feels done." Other terminations: `BOUNDED` (Iterations exhausted), `USER_INTERRUPT` (Ctrl+C), `SCOPE_LOCKED` (all atoms classified out-of-scope for 2 rounds).

**Output:** Creates `probe/{date}-{slug}/` with probe-spec.md, constraints.tsv, questions-asked.tsv, contradictions.md, hidden-assumptions.md, autoresearch-config.yml, summary.md, handoff.json.

---

## /autoresearch:scenario — Scenario Explorer (v1.6.0)

Autonomous scenario exploration engine. Takes a seed scenario and iteratively generates situations across 12 dimensions — happy paths, errors, edge cases, abuse, scale, concurrency, temporal, data variation, permissions, integrations, recovery, and state transitions.

```
/autoresearch:scenario
Scenario: User attempts to checkout with multiple payment methods
Iterations: 25
```

**How it works:** Seed analysis → Decompose into 12 dimensions → Generate ONE situation per iteration → Classify (new/variant/duplicate) → Expand edge cases → Log → Repeat until all dimensions explored.

Adaptive setup: provides 4-8 questions based on how much context you give. Just type `/autoresearch:scenario` with nothing else and it walks you through everything.

| Flag | Purpose |
|------|---------|
| `--domain <type>` | Domain: software, product, business, security, marketing |
| `--depth <level>` | Depth: shallow (10), standard (25), deep (50+) |
| `--format <type>` | Output: use-cases, user-stories, test-scenarios, threat-scenarios |
| `--focus <area>` | Prioritize: edge-cases, failures, security, scale |
| `--scope <glob>` | Limit to specific files/features |

**5 domains supported** with tailored dimension priorities and output formats. **Chain with** `/autoresearch:debug` to hunt bugs in discovered edge cases, or `/autoresearch:security` to audit discovered threat scenarios.

---

## Guard — Prevent Regressions (v1.0.4)

When optimizing a metric, the loop might break existing behavior. **Guard** is an optional safety net.

```
/autoresearch
Goal: Reduce API response time to under 100ms
Verify: npm run bench:api | grep "p95"
Guard: npm test
```

- **Verify** = "Did the metric improve?" (the goal)
- **Guard** = "Did anything else break?" (the safety net)

If the metric improves but the guard fails, Claude reworks the optimization (up to 2 attempts). Guard/test files are never modified.

> **Credit:** Guard was contributed by [@pronskiy](https://github.com/pronskiy) (JetBrains) in [PR #7](https://github.com/uditgoenka/autoresearch/pull/7).

---

## Results Tracking

Every iteration is logged in TSV format:

```tsv
iteration  commit   metric  delta   status    description
0          a1b2c3d  85.2    0.0     baseline  initial state
1          b2c3d4e  87.1    +1.9    keep      add tests for auth edge cases
2          -        86.5    -0.6    discard   refactor test helpers (broke 2 tests)
3          c3d4e5f  88.3    +1.2    keep      add error handling tests
```

Every 10 iterations, Claude prints a progress summary. Bounded loops print a final summary with baseline → current best.

---

## Crash Recovery

| Failure | Response |
|---------|----------|
| Syntax error | Fix immediately, don't count as iteration |
| Runtime error | Attempt fix (max 3 tries), then move on |
| Resource exhaustion | Revert, try smaller variant |
| Infinite loop / hang | Kill after timeout, revert |
| External dependency | Skip, log, try different approach |

---

## Repository Structure

```
autoresearch/
├── README.md
├── COMPARISON.md                                  ← Karpathy's Autoresearch vs Claude Autoresearch
├── guide/                                         ← Comprehensive guides — one per command + advanced patterns
├── scripts/
│   ├── install.sh                                 ← Guided installer (Claude Code + OpenCode + Codex)
│   ├── sync-opencode.sh                           ← Sync .claude/ → .opencode/ with adaptations
│   ├── sync-codex.sh                              ← Sync .claude/ → .agents/ with Codex adaptations
│   ├── release.sh                                 ← Release automation
│   └── release.md                                 ← Release checklist
├── .claude/skills/autoresearch/                   ← Claude Code source (canonical)
│   ├── SKILL.md                                   ← Main skill
│   └── references/                                ← 13 workflow protocol files
├── .opencode/                                     ← OpenCode port (generated via sync-opencode.sh)
│   ├── skills/autoresearch/                       ← Adapted SKILL.md + references
│   ├── commands/                                  ← 11 command files (autoresearch_*.md)
│   └── agents/docs-manager.md                     ← Subagent for learn workflow
├── .agents/skills/autoresearch/                   ← Codex port (generated via sync-codex.sh)
│   ├── SKILL.md                                   ← Adapted SKILL.md + references
│   ├── references/                                ← 12 workflow protocol files
│   └── agents/openai.yaml                         ← UI metadata for Codex
├── claude-plugin/                                 ← Distribution package (Claude Code plugin install)
│   ├── .claude-plugin/plugin.json                 ← Plugin metadata + version
│   ├── commands/                                  ← Command registrations
│   └── skills/autoresearch/                       ← Skill + references
└── LICENSE
```

---

## FAQ

**Q: I don't know what metric to use.**
A: Run `/autoresearch:plan` — it analyzes your codebase, suggests metrics, and dry-runs the verify command before you launch.

**Q: Does this work with any project?**
A: Yes. Any language, framework, or domain. Install via `/plugin marketplace add uditgoenka/autoresearch` (Claude Code), `./scripts/install.sh --opencode --global` (OpenCode), `./scripts/install.sh --codex --global` (Codex), or manually copy files.

**Q: Does this work with OpenCode?**
A: Yes, as of v2.0.0. Run `./scripts/install.sh --opencode --global` or manually copy `.opencode/` files. Commands use underscore naming (`/autoresearch_debug` instead of `/autoresearch:debug`).

**Q: Does this work with OpenAI Codex?**
A: Yes, as of v2.0.0. Run `./scripts/install.sh --codex --global` or copy `.agents/skills/autoresearch/` to `${CODEX_HOME:-~/.codex}/skills/autoresearch`. Invoke via `$autoresearch` mention syntax in Codex.

**Q: How do I stop the loop?**
A: `Ctrl+C` or add `Iterations: N` to your inline config to run exactly N iterations. Claude commits before verifying, so your last successful state is always in git.

**Q: Can I use this for non-code tasks?**
A: Absolutely. Sales emails, marketing copy, HR policies, runbooks — anything with a measurable metric. See [Examples by Domain](guide/examples-by-domain.md).

**Q: Does /autoresearch:security modify my code?**
A: No. It's read-only — analyzes code and produces a structured report. Use `--fix` to opt into auto-remediation of confirmed Critical/High findings.

**Q: Can I use MCP servers?**
A: Yes. Any MCP server configured in Claude Code is available during the loop for database queries, API calls, analytics, etc. See [Advanced Patterns](guide/advanced-patterns.md#using-with-mcp-servers).

**Q: What's the difference between /autoresearch:predict and /autoresearch:reason?**
A: Predict is a one-shot analysis — 5 experts debate your existing code. Reason is an iterative refinement loop — competing candidates are generated, critiqued, synthesized, and blind-judged over multiple rounds until convergence. Use predict for analysis before acting; use reason for decisions where no objective metric exists.

---

## Contributing

Contributions welcome! See [CONTRIBUTING.md](CONTRIBUTING.md).

Areas of interest: new domain examples, verification script templates, CI/CD integrations, real-world benchmarks. All guides are in the [guide/](guide/) folder.

---

## Star History

<a href="https://www.star-history.com/?repos=uditgoenka%2Fautoresearch&type=timeline&legend=top-left">
 <picture>
   <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/image?repos=uditgoenka/autoresearch&type=timeline&theme=dark&legend=bottom-right&v=20260319" />
   <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/image?repos=uditgoenka/autoresearch&type=timeline&legend=bottom-right&v=20260319" />
   <img alt="Star History Chart" src="https://api.star-history.com/image?repos=uditgoenka/autoresearch&type=timeline&legend=bottom-right&v=20260319" />
 </picture>
</a>

---

## License

MIT — see [LICENSE](LICENSE).

---

## Credits

- **[Andrej Karpathy](https://github.com/karpathy)** — for [autoresearch](https://github.com/karpathy/autoresearch)
- **[Anthropic](https://anthropic.com)** — for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) and the skills system
- **[OpenCode](https://opencode.ai)** — for the OpenCode terminal agent
- **[OpenAI](https://openai.com)** — for [Codex](https://developers.openai.com/codex) and the agent skills standard

---

<div align="center">

## About the Author

<a href="https://udit.co">
  <img src="https://avatars.githubusercontent.com/uditgoenka" width="80" style="border-radius: 50%;" alt="Udit Goenka" />
</a>

**[Udit Goenka](https://udit.co)** — AI Product Expert, Founder & Angel Investor

Self-taught builder who went from a slow internet connection in India to founding multiple companies and helping 700+ startups generate over ~$25m in revenue.

**Building:** [TinyCheque](https://tinycheque.com) (India's first agentic AI venture studio) · [Firstsales.io](https://firstsales.io) (sales automation)

**Investing:** 38 startups backed, 6 exits. Focused on early-stage AI and SaaS.

**Connect:** [udit.co](https://udit.co) · [@iuditg](https://x.com/iuditg) · [@uditgoenka](https://github.com/uditgoenka) · [Newsletter](https://udit.co/blog)

> *"Autonomy scales when you constrain scope, clarify success, mechanize verification, and let agents optimize tactics while humans optimize strategy."*

</div>
