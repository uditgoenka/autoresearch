<div align="center">

# Autoresearch

**Turn [Claude Code](https://docs.anthropic.com/en/docs/claude-code), [OpenCode](https://opencode.ai), or [OpenAI Codex](https://developers.openai.com/codex) into a relentless improvement engine.**

Based on [Karpathy's autoresearch](https://github.com/karpathy/autoresearch) — constraint + mechanical metric + autonomous iteration = compounding gains.

[![Claude Code Skill](https://img.shields.io/badge/Claude_Code-Skill-blue?logo=anthropic&logoColor=white)](https://docs.anthropic.com/en/docs/claude-code)
[![OpenCode](https://img.shields.io/badge/OpenCode-Skill-purple)](https://opencode.ai)
[![Codex](https://img.shields.io/badge/Codex-Skill-green?logo=openai&logoColor=white)](https://developers.openai.com/codex)
[![Version](https://img.shields.io/badge/version-2.2.1-blue.svg)](https://github.com/uditgoenka/autoresearch/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

[![Based on](https://img.shields.io/badge/Based_on-Karpathy's_Autoresearch-orange)](https://github.com/karpathy/autoresearch)
[![Follow @iuditg](https://img.shields.io/badge/Follow-@iuditg-000000?style=flat&logo=x&logoColor=white)](https://x.com/intent/follow?screen_name=iuditg)
[![Support](https://img.shields.io/badge/Support-PayPal-00457C?style=flat&logo=paypal&logoColor=white)](https://paypal.me/uditgoenka)

<br>

*"Set the GOAL → The agent runs the LOOP → You wake up to results"*

*You don't need AGI. You need a goal, a metric, and a loop that never quits.*

**Supports Claude Code, OpenCode, and OpenAI Codex. 14 commands. 9 safety hooks. 95% fewer tokens per invocation.**

> **v2.2.0 — Autonomous Orchestrator:** Type a plain-language goal to `/autoresearch` and it classifies your goal, derives a Success predicate, confirms it once, then loops across subcommands until done. No manual chaining required. `Metric:`/`Verify:` invocations run the classic loop unchanged. See [guide/autoresearch-orchestrator.md](guide/autoresearch-orchestrator.md).

<br>

[How It Works](#how-it-works) · [Commands](#commands) · [Quick Start](#quick-start) · [Guides](guide/) · [FAQ](#faq)

</div>

---

```
     PLAN             LOOP            DEBUG             FIX             SECURE            SHIP
 ┌──────────┐     ┌──────────┐     ┌──────────┐     ┌──────────┐     ┌──────────┐     ┌──────────┐
 │   Goal   │     │  Modify  │     │   Find   │     │   Fix    │     │  STRIDE  │     │  Stage   │
 │  Metric  │────▶│  Verify  │────▶│   Bugs   │────▶│  Errors  │────▶│  OWASP   │────▶│  Deploy  │
 │  Scope   │     │Keep/Drop │     │  Trace   │     │  Repair  │     │ Red Team │     │ Release  │
 └──────────┘     └──────────┘     └──────────┘     └──────────┘     └──────────┘     └──────────┘
 /autoresearch:   /autoresearch    /autoresearch:   /autoresearch:   /autoresearch:   /autoresearch:
   plan                              debug            fix              security         ship

 ┌──────────┐     ┌──────────┐     ┌──────────┐     ┌──────────┐
 │  Probe   │     │ Scenario │     │ Predict  │     │  Reason  │
 │ Require- │     │   Edge   │     │ 5-Expert │     │  Debate  │
 │  ments   │     │  Cases   │     │  Swarm   │     │ Converge │
 └──────────┘     └──────────┘     └──────────┘     └──────────┘
 /autoresearch:   /autoresearch:   /autoresearch:   /autoresearch:
   probe            scenario         predict          reason

 ┌──────────┐     ┌──────────┐     ┌──────────┐     ┌──────────┐
 │  Learn   │     │ Improve  │     │   Eval   │     │ Baseline │
 │   Docs   │     │ Research │     │ Analyze  │     │   Diff   │
 │   Gen    │     │   PRDs   │     │ Results  │     │ Verdict  │
 └──────────┘     └──────────┘     └──────────┘     └──────────┘
 /autoresearch:   /autoresearch:   /autoresearch:   /autoresearch:
   learn            improve          evals            regression
```

---

## Why This Exists

[Karpathy's autoresearch](https://github.com/karpathy/autoresearch) demonstrated that a 630-line Python script could autonomously improve ML models overnight — **100 experiments per night** — by following simple principles: one metric, constrained scope, fast verification, automatic rollback, git as memory.

**Claude Autoresearch generalizes these principles to ANY domain.** Not just ML — code, content, marketing, sales, HR, DevOps, or anything with a number you can measure.

**v2.1.0 is a major architecture rebuild.** The monolithic SKILL.md (813 lines, ~100K tokens per invocation) is replaced with a thin 41-line routing file and 12 self-contained command files (94–120 lines each, ~5–8K tokens per invocation). That is a **95% token reduction** with the same capability surface.

---

## How It Works

```
LOOP (N iterations or until done):
  1. Review current state + git history + results log
  2. Pick the next change (based on what worked, what failed, what's untried)
  3. Make ONE focused change
  4. Git commit (before verification)
  5. Run mechanical verification (tests, benchmarks, scores)
  6. If improved → keep. If worse → git revert. If crashed → fix or skip.
  7. Log the result
  8. Repeat until N iterations complete or goal is met.
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
| 1 | **Bounded by default** — every command has a default iteration count; unlimited is opt-in via `Iterations: unlimited` |
| 2 | **Read before write** — understand full context before modifying |
| 3 | **One change per iteration** — atomic changes; if it breaks, you know why |
| 4 | **Mechanical verification only** — no subjective "looks good"; use metrics |
| 5 | **Automatic rollback** — failed changes revert instantly |
| 6 | **Simplicity wins** — equal results + less code = keep |
| 7 | **Git is memory** — experiments committed with `experiment:` prefix; agent reads `git log` + `git diff` before each iteration |
| 8 | **When stuck, think harder** — re-read, combine near-misses, try radical changes |

---

## Hooks & Safety

v2.1.1 ships a 9-hook safety system that protects your sessions automatically. Hooks fire on every session — not just during autoresearch commands.

### What's Protected

| Hook | What it does | Event |
|------|-------------|-------|
| **scout-block** | Blocks node_modules/, .git/, __pycache__/, etc. from filling your context | PreToolUse |
| **privacy-block** | Blocks .env, SSH keys, credentials from being read in sessions | PreToolUse |
| **dangerous-cmd-block** | Blocks force-push, `rm -rf`, `git reset --hard` | PreToolUse |
| **iteration-context** | Injects recent TSV iteration data after context compaction | UserPromptSubmit |
| **subagent-context** | Gives subagents awareness of active loop state | SubagentStart |
| **dev-rules-reminder** | Re-injects plan path and code standards after compaction | UserPromptSubmit |
| **simplify-gate** | Warns at 400 LOC, blocks at 800 LOC before shipping | UserPromptSubmit |
| **session-init** | Sets up project context at session start | SessionStart |
| **stop-notify** | Terminal notification + optional webhook on session end | SessionEnd |

### Configuration

All hooks are **on by default**. Disable individually:

```bash
# Disable a specific hook
export AR_DISABLE_SCOUT_BLOCK=1
export AR_DISABLE_PRIVACY_BLOCK=1
export AR_DISABLE_DANGEROUS_CMD_BLOCK=1
# ... etc for each hook name
```

Optional webhook for session completion notifications:

```bash
export AR_NOTIFY_WEBHOOK=https://hooks.slack.com/services/...
```

Customize blocked directories with a `.ckignore` file (gitignore syntax) at your project root.

See [guide/hooks.md](guide/hooks.md) for full reference.

---

## Commands

| Command | What it does | Default Iterations |
|---------|--------------|--------------------|
| `/autoresearch` | **Classic:** Core iterate loop: modify → verify → keep/discard · **Orchestrator:** free-form goal → auto-select pipeline → loop until predicate met | 25 / goal-bounded |
| `/autoresearch:plan` | Convert goal into validated config | one-shot |
| `/autoresearch:debug` | Hunt bugs via hypothesis iteration | 15 |
| `/autoresearch:fix` | Crush errors one-by-one to zero | 20 |
| `/autoresearch:security` | STRIDE + OWASP audit with red-team | 15 |
| `/autoresearch:ship` | Ship through 8 phases | linear |
| `/autoresearch:scenario` | Generate edge cases across 12 dimensions | 20 |
| `/autoresearch:predict` | 5 expert personas debate | one-shot |
| `/autoresearch:learn` | Scout → generate docs → validate → fix | 10 |
| `/autoresearch:reason` | Adversarial debate with blind judges | 8 |
| `/autoresearch:probe` | 8 personas interrogate requirements | 15 |
| `/autoresearch:improve` | Research ICP, discover improvements, generate PRDs | 15 |
| `/autoresearch:evals` | Analyze iteration results: trends, plateaus | one-shot |
| `/autoresearch:regression` | Stability gate: baseline vs candidate, verdict STABLE/UNSTABLE | one-shot |

**Universal flags:** `Iterations: N`, `Iterations: unlimited`, `--evals`, `--evals-interval N`, `--chain <targets>`, `--<subcommand>` shorthand.

**All commands use interactive setup when invoked without arguments.** Just type the command — the agent asks for what it needs with smart defaults based on your codebase.

> **OpenCode users:** Commands use underscore naming (`/autoresearch_debug`, `/autoresearch_fix`, etc.). All 14 commands available.
>
> **Codex users:** Invoke via `$autoresearch` mention syntax. Subcommands are keywords: `$autoresearch debug`, `$autoresearch plan`, etc.

### Quick Decision Guide

| I want to... | Use |
|--------------|-----|
| Give a plain-language goal, let it self-orchestrate | `/autoresearch <goal>` (bare, no Metric/Verify) |
| Improve test coverage / reduce bundle size / any metric | `/autoresearch` |
| Run bounded iterations | Add `Iterations: N` to any command |
| Don't know what metric to use | `/autoresearch:plan` |
| Run a security audit | `/autoresearch:security` |
| Ship a PR / deployment / release | `/autoresearch:ship` |
| Optimize without breaking existing tests | Add `Guard: npm test` |
| Hunt all bugs in a codebase | `/autoresearch:debug` |
| Fix all errors (tests, types, lint) | `/autoresearch:fix` |
| Debug then auto-fix | `/autoresearch:debug --fix` |
| Check if something is ready to ship | `/autoresearch:ship --checklist-only` |
| Explore edge cases for a feature | `/autoresearch:scenario` |
| Generate test scenarios | `/autoresearch:scenario --format test-scenarios` |
| Get expert opinions before starting | `/autoresearch:predict` |
| Analyze from multiple angles then debug | `/autoresearch:predict --chain debug` |
| Generate docs for a new codebase | `/autoresearch:learn --mode init` |
| Update existing docs after changes | `/autoresearch:learn --mode update` |
| Debate an architecture decision | `/autoresearch:reason --domain software` |
| Surface hidden constraints before starting | `/autoresearch:probe` |
| Pre-flight a fuzzy goal then loop | `/autoresearch:probe --chain plan,autoresearch` |
| Discover what to build next for your ICP | `/autoresearch:improve` |
| Research competitors and generate PRDs | `/autoresearch:improve --depth deep` |
| Probe requirements then research improvements | `/autoresearch:probe --improve` |
| Analyze trends and plateaus across past runs | `/autoresearch:evals` |
| Check if a run has stalled | `/autoresearch:evals --file *-results.tsv` |
| Verify a change won't regress before pushing | `/autoresearch:regression` |
| Gate a PR: predict, fix, re-gate, then ship | `/autoresearch:regression --predict --fix --ship` |

---

## Quick Start

### Claude Code

**Option A — npx install (recommended):**

```bash
npx skills add uditgoenka/autoresearch
```

All 14 commands are available after restarting Claude Code.

**Option B — Plugin install:**

```
/plugin marketplace add uditgoenka/autoresearch
/plugin install autoresearch@autoresearch
```

> **Note:** Start a new Claude Code session after installing. Reference files aren't resolvable in the same session where installation happened — this is a Claude Code platform limitation.

**Updating (no reinstall needed):**
```
/plugin update autoresearch
```

Run `/reload-plugins` to activate. No need to uninstall or re-clone.

**Option C — Manual copy:**
```bash
git clone https://github.com/uditgoenka/autoresearch.git

# Copy skill + subcommands to your project
cp -r autoresearch/.claude/skills/autoresearch .claude/skills/autoresearch
cp -r autoresearch/.claude/commands/autoresearch .claude/commands/autoresearch
cp autoresearch/.claude/commands/autoresearch.md .claude/commands/autoresearch.md
```

Or install globally:
```bash
cp -r autoresearch/.claude/skills/autoresearch ~/.claude/skills/autoresearch
cp -r autoresearch/.claude/commands/autoresearch ~/.claude/commands/autoresearch
cp autoresearch/.claude/commands/autoresearch.md ~/.claude/commands/autoresearch.md
```

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

cp -r autoresearch/.opencode/skills/autoresearch .opencode/skills/autoresearch
cp autoresearch/.opencode/commands/autoresearch*.md .opencode/commands/
```

Or globally:
```bash
cp -r autoresearch/.opencode/skills/autoresearch ~/.config/opencode/skills/autoresearch
cp autoresearch/.opencode/commands/autoresearch*.md ~/.config/opencode/commands/
```

> All 14 commands available as `/autoresearch_debug`, `/autoresearch_fix`, `/autoresearch_improve`, etc.

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
cp -r autoresearch/.agents/skills/autoresearch ~/.codex/skills/autoresearch
```

> Invoke via `$autoresearch` mention syntax. Subcommands are keywords: `$autoresearch plan`, `$autoresearch debug`, `$autoresearch evals`, etc.

### Run It

```
/autoresearch
Goal: Increase test coverage from 72% to 90%
Scope: src/**/*.test.ts, src/**/*.ts
Metric: coverage % (higher is better)
Verify: npm test -- --coverage | grep "All files"
Iterations: 25
```

Claude reads all files, establishes a baseline, and starts iterating — one change at a time. Keeps improvements, auto-reverts failures, logs everything. Stops after N iterations or when you interrupt.

---

## /autoresearch:plan — Goal to Config

The hardest part isn't the loop — it's defining Scope, Metric, and Verify correctly. `/autoresearch:plan` converts your plain-language goal into a validated, ready-to-execute configuration.

```
/autoresearch:plan
Goal: Make the API respond faster
```

Walks through 5 steps: capture goal → define scope → define metric → define direction → validate verify command (dry-run). Every gate is mechanical — scope must resolve to files, metric must output a number, verify must pass a dry-run. Emits a `handoff.json` for chaining.

---

## /autoresearch:debug — Autonomous Bug Hunter

Scientific method meets autoresearch loop. Doesn't stop at one bug — iteratively hunts ALL bugs using falsifiable hypotheses, evidence-based investigation, and 7 investigation techniques.

```
/autoresearch:debug
Scope: src/api/**/*.ts
Symptom: API returns 500 on POST /users
Iterations: 15
```

**How it works:** Gather symptoms → Recon → Hypothesize (specific, testable) → Test (one experiment per iteration) → Classify (confirmed/disproven/inconclusive) → Log → Repeat.

Every finding requires code evidence (file:line + reproduction steps). Every disproven hypothesis is logged — equally valuable.

| Flag | Purpose |
|------|---------|
| `--fix` | After hunting, auto-switch to `/autoresearch:fix` |
| `--scope <glob>` | Limit investigation scope |
| `--symptom "<text>"` | Pre-fill symptom |
| `--severity <level>` | Minimum severity to report |

---

## /autoresearch:fix — Autonomous Error Crusher

Takes a broken state and iteratively repairs it until everything passes. ONE fix per iteration. Atomic, committed, verified, auto-reverted on failure.

```
/autoresearch:fix
Iterations: 20
```

Auto-detects what's broken (tests, types, lint, build) → Prioritizes (blockers first) → Fixes ONE thing → Commits → Verifies error count decreased → Guard check → Keep/Revert → Repeat. **Stops automatically when error count hits zero.**

| Flag | Purpose |
|------|---------|
| `--target <command>` | Explicit verify command |
| `--guard <command>` | Safety command that must always pass |
| `--category <type>` | Only fix specific type (test, type, lint, build) |
| `--from-debug` | Read findings from latest debug session |

**Chain them:** `/autoresearch:debug` → `/autoresearch:fix --from-debug`

---

## /autoresearch:security — Autonomous Security Audit

Read-only security audit using STRIDE threat modeling, OWASP Top 10 sweeps, and red-team adversarial analysis with 4 hostile personas.

```
/autoresearch:security
Iterations: 15
```

Codebase recon → asset inventory → trust boundaries → STRIDE threat model → attack surface map → autonomous testing loop → structured report. Every finding requires code evidence (file:line + attack scenario).

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
| `--checklist-only` | Just check readiness |

**9 supported types:** code-pr, code-release, deployment, content, marketing-email, marketing-campaign, sales, research, design.

---

## /autoresearch:scenario — Scenario Explorer

Autonomous scenario exploration engine. Takes a seed scenario and iteratively generates situations across 12 dimensions — happy paths, errors, edge cases, abuse, scale, concurrency, temporal, data variation, permissions, integrations, recovery, and state transitions.

```
/autoresearch:scenario
Scenario: User attempts to checkout with multiple payment methods
Iterations: 20
```

Seed analysis → Decompose into 12 dimensions → Generate ONE situation per iteration → Classify (new/variant/duplicate) → Expand edge cases → Log → Repeat.

| Flag | Purpose |
|------|---------|
| `--domain <type>` | software, product, business, security, marketing |
| `--depth <level>` | shallow (10), standard (20), deep (50+) |
| `--format <type>` | use-cases, user-stories, test-scenarios, threat-scenarios |
| `--focus <area>` | edge-cases, failures, security, scale |

---

## /autoresearch:predict — Multi-Persona Prediction

Before you debug, fix, or ship — get 5 expert perspectives in 2 minutes.

Simulates a team (Architect, Security Analyst, Performance Engineer, Reliability Engineer, Devil's Advocate) who independently analyze your code, debate findings, and reach consensus.

```
/autoresearch:predict --chain debug
```

- `--chain debug` — pre-ranked hypotheses before debugging
- `--chain security` — multi-persona red team analysis
- `--chain scenario,debug,fix` — full quality pipeline

---

## /autoresearch:learn — Autonomous Documentation Engine

Scout codebase → generate docs → validate → fix → repeat. 4 modes: init (create from scratch), update (refresh existing), check (read-only health report), summarize (quick overview).

```
/autoresearch:learn --mode init --depth deep
Iterations: 10
```

Dynamic doc discovery, project-type detection, validation-fix loop, git-diff scoping for updates, selective single-doc update with `--file`. Auto-generates Mermaid architecture diagrams, API reference, testing guide, config guide, and cross-reference links.

---

## /autoresearch:reason — Adversarial Refinement

Extends autoresearch to **subjective domains** where no objective metric exists. The blind judge panel is the fitness function.

```
/autoresearch:reason
Task: Should we use event sourcing for our order management system?
Domain: software
Iterations: 8
```

**How it works:** Generate-A → Critic attacks → Author-B responds → Synthesizer merges → Blind judge panel (randomized labels) picks winner → Winner becomes new A → Repeat until convergence. Every agent is a cold-start fresh invocation — no history bleed.

| Flag | Purpose |
|------|---------|
| `--judges N` | Judge count (3-7, odd preferred) |
| `--convergence N` | Consecutive wins to converge (default 3) |
| `--mode <mode>` | convergent (default), creative, debate |
| `--domain <type>` | software, product, business, security, research, content |
| `--chain <targets>` | Chain converged output to any autoresearch command |

**Output:** Creates `reason/{date}-{slug}/` with lineage.md, candidates.md, judge-transcripts.md, reason-results.tsv, handoff.json.

---

## /autoresearch:probe — Adversarial Requirement Interrogation

Eight adversarial personas interrogate user and codebase together until net-new constraints saturate. Output is the 5 autoresearch primitives (Goal/Scope/Metric/Direction/Verify) plus a `handoff.json` ready to feed any downstream command.

```
/autoresearch:probe --chain plan,autoresearch
Topic: Add multi-tenant isolation to the database layer
```

**The 8 personas:** Skeptic, Edge-Case Hunter, Scope Sentinel, Ambiguity Detective, Contradiction Finder, Prior-Art Investigator, Success-Criteria Auditor, Constraint Excavator.

| Flag | Purpose |
|------|---------|
| `--depth <level>` | shallow (5 rounds), standard (15), deep (30) |
| `--adversarial` | Rotate Skeptic + Contradiction Finder + Edge-Case Hunter to front |
| `--mode <mode>` | interactive (default) or autonomous |
| `--chain <targets>` | plan, predict, debug, scenario, reason, fix, ship, learn |

**Output:** Creates `probe/{date}-{slug}/` with probe-spec.md, constraints.tsv, autoresearch-config.yml, handoff.json.

---

## /autoresearch:improve — Product Improvement Engine

Research what to build next. Discovers ICP challenges via deep multi-source research, scores and ranks improvements, generates per-feature PRDs with evidence chains.

```
/autoresearch:improve
Goal: Improve onboarding conversion
ICP: B2B SaaS product managers at 50-500 person companies
```

**How it works:** Resolve product context → Research across 5 categories (ICP challenges, competitor gaps, market trends, UX & experience, revenue & growth) → Saturate → ICP binary gate → Tiered ranking (Must-have / Nice-to-have / Moonshot) → User selects features → Generate PRDs.

| Flag | Purpose |
|------|---------|
| `--icp "<text>"` | Ideal customer profile |
| `--discover` | Force codebase scan even with existing context |
| `--no-discover` | Skip auto-discover |
| `--depth <level>` | shallow (5), standard (15), deep (30+) |
| `--seeds <categories>` | Override default research categories |

**Output:** Creates `improve/{date}-{slug}/` with research-findings.md, improvement-plan.md, per-feature PRDs, summary.md, improve-results.tsv, handoff.json.

**Terminal emitter** — improve is the last link in any autoresearch chain. PRDs are consumed by external tools (`/ck:plan`, `/ck:cook`), not by other autoresearch commands.

**Chain into improve:** `/autoresearch:probe --improve`, `/autoresearch:predict --improve`, `/autoresearch:debug --improve`.

---

## /autoresearch:evals — Results Analyzer

Analyzes `*-results.tsv` files from any autoresearch run. Surfaces trends, plateau detection, convergence signals, and iteration efficiency. Backward compatible with v2.0.x TSV format.

```
/autoresearch:evals
/autoresearch:evals --file coverage-results.tsv
```

**Adaptive checkpoints:** floor(max_iterations/3), minimum 1 checkpoint. Reports per-checkpoint delta, stall detection, best iteration, and a recommendation (continue / stop / change strategy).

**Inline evals during a run:**
```
/autoresearch
Goal: Reduce bundle size below 200kb
Iterations: 30
--evals-interval 10
```

Prints a checkpoint report every 10 iterations without interrupting the loop.

---

## /autoresearch:regression — Stability Gate

Before you push, prove the change didn't break what already worked. Captures baseline behavior from a `git worktree` of the base ref, diffs the candidate across **8 dimensions**, and emits a single **STABLE / UNSTABLE** verdict.

```
/autoresearch:regression --predict --evals --fix --ship
```

**Core invariant:** a regression is a **green→red transition only**. Pre-existing failures (red→red), new tests (absent→red), and flaky tests (flake→red) are classified and excluded — never counted as regressions.

**Tiered verdict:**
- **HARD gate** (any green→red = UNSTABLE): `functional`, `api-contract`, `data-migration`, `integration-e2e`
- **SCORE** (0–100, noise-tolerant, weighted; UNSTABLE below threshold 95): `flakiness` .30, `performance` .30, `resource` .20, `visual-ui` .20

| Flag | Purpose |
|------|---------|
| `--select auto` | Use detected affected-test mapper (jest `--findRelatedTests`, nx affected) else FULL suite — never a silent subset |
| `--samples N` / `--noise-band %` | Tune the perf statistical gate (default 7 samples/side, Mann–Whitney U) |
| `--fix` / `--fix-cycles N` | Re-gate after fixing; each cycle must strictly shrink the blocking-set (max 3) |
| `--predict` | Pre-empt likely regressions before the gate runs |
| `--reason` | Adversarial root-cause when a regression's cause is ambiguous |
| `--debug` | Force the bisect Hunter (HARD dims passing 3/3 reproduction) |
| `--max-runs N` | Ceiling on dims×axes×samples×cells (warn+confirm past 200) |

**Output:** Creates `regression/{date}-{slug}/` with regression-results.tsv, stability-report.md, dimensions/<dim>.md, baseline/, evals-summary.md, handoff.json.

> **data-migration is hard-guarded:** opt-in, and refuses any DB URL that isn't ephemeral/allowlisted (`*test*`, `*ci*`, container). Migrations are forward-only by default.

---

## Guard — Prevent Regressions

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

Run `/autoresearch:evals` at any time to analyze trends across any TSV file. Adaptive checkpoints fire at floor(max_iterations/3) intervals.

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
├── COMPARISON.md                                  ← Karpathy's vs Claude Autoresearch
├── guide/                                         ← Guides — one per command + advanced patterns
├── scripts/
│   ├── install.sh                                 ← Guided installer (Claude Code + OpenCode + Codex)
│   ├── transform.sh                               ← Single transform: .claude/ → .opencode/ + .agents/
│   ├── release.sh                                 ← Release automation
│   └── release.md                                 ← Release checklist
├── .claude/
│   ├── skills/autoresearch/
│   │   ├── SKILL.md                               ← Thin routing table (41 lines)
│   │   └── references/                            ← 3 focused reference files
│   │       ├── security-checklist.md              ← STRIDE + OWASP
│   │       ├── predict-personas.md                ← 5 personas + adversarial set
│   │       └── reason-judge-protocol.md           ← Adversarial refinement loop
│   └── commands/
│       ├── autoresearch.md                        ← Core loop (self-contained, ~100 lines)
│       └── autoresearch/                          ← 13 subcommand files (self-contained)
│           ├── plan.md
│           ├── debug.md
│           ├── fix.md
│           ├── security.md
│           ├── ship.md
│           ├── scenario.md
│           ├── predict.md
│           ├── learn.md
│           ├── reason.md
│           ├── improve.md
│           ├── probe.md
│           ├── evals.md
│           └── regression.md
├── .opencode/                                     ← OpenCode port (via transform.sh)
│   ├── skills/autoresearch/
│   └── commands/                                  ← 14 command files (autoresearch_*.md)
├── .agents/                                       ← Codex port (via transform.sh)
│   └── skills/autoresearch/
├── plugins/                                       ← Codex plugin metadata
│   └── openai.yaml
└── LICENSE
```

---

## FAQ

**Q: I don't know what metric to use.**
A: Run `/autoresearch:plan` — it analyzes your codebase, suggests metrics, and dry-runs the verify command before you launch.

**Q: What changed in v2.2.0?**
A: The root `/autoresearch` command now supports an autonomous orchestrator mode. Type a plain-language goal (e.g., `/autoresearch help me fix the login bug`) instead of `Metric:`/`Verify:` and the orchestrator classifies your goal, derives a verifiable Success predicate, confirms it once, then loops across subcommands until done. Classic metric-loop behavior is unchanged when `Metric:` or `Verify:` are present.

**Q: What changed in v2.1.0?**
A: Architecture rebuild. The monolithic SKILL.md (813 lines, ~100K tokens) is replaced with a thin routing file + 12 self-contained command files (~5–8K tokens each). 95% token reduction. A new `/autoresearch:evals` command analyzes iteration results. Every looping command now has a bounded default instead of running unlimited.

**Q: How do bounded defaults work?**
A: Every looping command ships with a sensible default (e.g., `/autoresearch` defaults to 25 iterations). Override inline: `Iterations: 50` for more, `Iterations: unlimited` for the old unbounded behavior.

**Q: How does /autoresearch:evals work?**
A: Point it at any `*-results.tsv` file from a previous run. It reports trends, plateau detection, and a recommendation. Use `--evals-interval N` during a live run to get checkpoint reports without interrupting the loop.

**Q: Does this work with any project?**
A: Yes. Any language, framework, or domain. Install via plugin (Claude Code), installer script, or manual copy.

**Q: Does this work with OpenCode?**
A: Yes. Run `./scripts/install.sh --opencode --global` or manually copy `.opencode/` files. Commands use underscore naming (`/autoresearch_debug`, `/autoresearch_evals`, etc.). All 14 commands available.

**Q: Does this work with OpenAI Codex?**
A: Yes. Run `./scripts/install.sh --codex --global` or copy `.agents/skills/autoresearch/` to `~/.codex/skills/autoresearch`. Invoke via `$autoresearch` mention syntax.

**Q: How do I stop the loop?**
A: `Ctrl+C` or add `Iterations: N` to your inline config. Claude commits before verifying, so your last successful state is always in git.

**Q: Can I use this for non-code tasks?**
A: Absolutely. Sales emails, marketing copy, HR policies, runbooks — anything with a measurable metric. See [Examples by Domain](guide/examples-by-domain.md).

**Q: Does /autoresearch:security modify my code?**
A: No. Read-only by default. Use `--fix` to opt into auto-remediation of confirmed Critical/High findings.

**Q: What's the difference between /autoresearch:predict and /autoresearch:reason?**
A: Predict is a one-shot analysis — 5 experts debate your existing code. Reason is an iterative refinement loop — competing candidates are generated, critiqued, synthesized, and blind-judged over multiple rounds until convergence. Use predict for analysis before acting; use reason for decisions where no objective metric exists.

**Q: What is handoff.json?**
A: A structured file emitted by plan, probe, reason, and other commands that carries Goal/Scope/Metric/Verify config for downstream commands. When you `--chain plan,autoresearch`, the chain reads handoff.json automatically.

---

## Contributing

Contributions welcome. See [CONTRIBUTING.md](CONTRIBUTING.md).

Areas of interest: new domain examples, verification script templates, CI/CD integrations, real-world benchmarks. All guides are in [guide/](guide/).

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
