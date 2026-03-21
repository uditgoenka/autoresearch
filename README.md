<div align="center">

# Claude Autoresearch

**Turn [Claude Code](https://docs.anthropic.com/en/docs/claude-code) into a relentless improvement engine.**

Based on [Karpathy's autoresearch](https://github.com/karpathy/autoresearch) — constraint + mechanical metric + autonomous iteration = compounding gains.

[![Claude Code Skill](https://img.shields.io/badge/Claude_Code-Skill-blue?logo=anthropic&logoColor=white)](https://docs.anthropic.com/en/docs/claude-code)
[![Version](https://img.shields.io/badge/version-1.8.2-blue.svg)](https://github.com/uditgoenka/autoresearch/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

[![Based on](https://img.shields.io/badge/Based_on-Karpathy's_Autoresearch-orange)](https://github.com/karpathy/autoresearch)
[![Follow @iuditg](https://img.shields.io/badge/Follow-@iuditg-000000?style=flat&logo=x&logoColor=white)](https://x.com/intent/follow?screen_name=iuditg)
[![Support](https://img.shields.io/badge/Support-PayPal-00457C?style=flat&logo=paypal&logoColor=white)](https://paypal.me/uditgoenka)

<br>

*"Set the GOAL → Claude runs the LOOP → You wake up to results"*

*You don't need AGI. You need a goal, a metric, and a loop that never quits.*

<br>

[How It Works](#how-it-works) · [Commands](#commands) · [Quick Start](#quick-start) · [Guides](guide/) · [FAQ](#faq)

</div>

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
| `Guard: <command>` | Optional safety net — must pass for changes to be kept |

**All commands use `AskUserQuestion` for interactive setup when invoked without arguments.** Just type the command — Claude will ask you what you need step by step with smart defaults based on your codebase. Power users can skip the wizard by providing flags inline.

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

---

## Quick Start

### 1. Install

**Option A — Plugin install (recommended):**

In Claude Code, run:
```
/plugin marketplace add uditgoenka/autoresearch
/plugin install autoresearch@autoresearch
```

That's it. All 9 commands are available after running `/reload-plugins` or restarting Claude Code.

**Updating (no reinstall needed):**
```
/plugin update autoresearch
```

That pulls the latest version. Run `/reload-plugins` to activate. No need to uninstall or re-clone.

**Option B — Manual copy:**
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
│   ├── README.md                                  ← Guide index
│   ├── getting-started.md                         ← Installation, core concepts, FAQ
│   ├── autoresearch.md                            ← The autonomous loop
│   ├── autoresearch-plan.md                       ← Setup wizard
│   ├── autoresearch-debug.md                      ← Bug hunter
│   ├── autoresearch-fix.md                        ← Error crusher
│   ├── autoresearch-security.md                   ← Security auditor
│   ├── autoresearch-ship.md                       ← Shipping workflow
│   ├── autoresearch-scenario.md                   ← Scenario explorer
│   ├── autoresearch-predict.md                    ← Multi-persona swarm prediction
│   ├── autoresearch-learn.md                      ← Documentation engine
│   ├── chains-and-combinations.md                 ← Multi-command pipelines
│   ├── examples-by-domain.md                      ← Real-world examples by domain
│   ├── advanced-patterns.md                       ← Guards, MCP, CI/CD, FAQ
│   └── scenario/                                  ← 10 real-world scenario walkthroughs
│       ├── README.md                              ← Scenario guide index
│       ├── real-time-chat-messaging.md
│       ├── multi-tenant-saas-onboarding.md
│       ├── cicd-pipeline-deployment.md
│       ├── healthcare-appointment-scheduling.md
│       ├── social-media-content-moderation.md
│       ├── iot-firmware-updates.md
│       ├── document-collaboration.md
│       ├── cross-border-wire-transfers.md
│       ├── search-autocomplete.md
│       └── mobile-push-notifications.md
├── LICENSE
├── .claude-plugin/
│   └── marketplace.json                           ← Plugin marketplace manifest (source: ./claude-plugin)
├── claude-plugin/                                 ← Distribution package (what users install)
│   ├── .claude-plugin/
│   │   └── plugin.json                            ← Plugin metadata + version
│   ├── commands/
│   │   ├── autoresearch.md                        ← Main /autoresearch command
│   │   └── autoresearch/
│   │       ├── ship.md                            ← /autoresearch:ship registration
│   │       ├── plan.md                            ← /autoresearch:plan registration
│   │       ├── security.md                        ← /autoresearch:security registration
│   │       ├── debug.md                           ← /autoresearch:debug registration
│   │       ├── fix.md                             ← /autoresearch:fix registration
│   │       ├── scenario.md                        ← /autoresearch:scenario registration
│   │       ├── predict.md                         ← /autoresearch:predict registration
│   │       └── learn.md                           ← /autoresearch:learn registration
│   └── skills/
│       └── autoresearch/
│           ├── SKILL.md                           ← Main skill (loaded by Claude Code)
│           └── references/
│               ├── autonomous-loop-protocol.md    ← 8-phase loop protocol
│               ├── core-principles.md             ← 7 universal principles
│               ├── plan-workflow.md               ← Plan wizard protocol
│               ├── security-workflow.md           ← Security audit protocol
│               ├── ship-workflow.md               ← Ship workflow protocol
│               ├── debug-workflow.md              ← Debug loop protocol
│               ├── fix-workflow.md                ← Fix loop protocol
│               ├── scenario-workflow.md           ← Scenario exploration protocol
│               ├── predict-workflow.md            ← Multi-persona swarm prediction workflow
│               ├── learn-workflow.md              ← Documentation engine protocol
│               └── results-logging.md             ← TSV tracking format
```

---

## FAQ

**Q: I don't know what metric to use.**
A: Run `/autoresearch:plan` — it analyzes your codebase, suggests metrics, and dry-runs the verify command before you launch.

**Q: Does this work with any project?**
A: Yes. Any language, framework, or domain. Install via `/plugin marketplace add uditgoenka/autoresearch` or manually copy from the `claude-plugin/` directory.

**Q: How do I stop the loop?**
A: `Ctrl+C` or add `Iterations: N` to your inline config to run exactly N iterations. Claude commits before verifying, so your last successful state is always in git.

**Q: Can I use this for non-code tasks?**
A: Absolutely. Sales emails, marketing copy, HR policies, runbooks — anything with a measurable metric. See [Examples by Domain](guide/examples-by-domain.md).

**Q: Does /autoresearch:security modify my code?**
A: No. It's read-only — analyzes code and produces a structured report. Use `--fix` to opt into auto-remediation of confirmed Critical/High findings.

**Q: Can I use MCP servers?**
A: Yes. Any MCP server configured in Claude Code is available during the loop for database queries, API calls, analytics, etc. See [Advanced Patterns](guide/advanced-patterns.md#using-with-mcp-servers).

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
