# AGENTS.md — Autoresearch

> Drop this file into your project root. Any AI agent (Claude Code, Codex, OpenCode, Gemini CLI, etc.) can then use Autoresearch immediately.

## What is Autoresearch?

Autonomous goal-directed iteration based on [Karpathy's autoresearch](https://github.com/karpathy/autoresearch). One metric, constrained scope, fast verification, automatic rollback, git as memory. Works on ANY domain — code, content, marketing, sales, DevOps — anything with a measurable metric.

**Core loop:** Modify → Verify → Keep/Discard → Repeat.

---

## Installation

### Claude Code (plugin)

```
/plugin marketplace add uditgoenka/autoresearch
/plugin install autoresearch@autoresearch
```

Restart session after install. All 11 commands become available as `/autoresearch` and `/autoresearch:<subcommand>`.

### Codex (plugin)

```bash
git clone https://github.com/uditgoenka/autoresearch.git
cd autoresearch
python3 plugins/autoresearch/scripts/install_local_plugin.py
```

Use the wrapper CLI: `bin/autoresearch <subcommand> [flags]`

### Manual (any agent)

Copy the skill files into your agent's skill directory:

```bash
git clone https://github.com/uditgoenka/autoresearch.git

# Claude Code
cp -r autoresearch/claude-plugin/skills/autoresearch .claude/skills/autoresearch
cp -r autoresearch/claude-plugin/commands/autoresearch .claude/commands/autoresearch
cp autoresearch/claude-plugin/commands/autoresearch.md .claude/commands/autoresearch.md

# Codex
cp -r autoresearch/plugins/autoresearch ~/.agents/plugins/autoresearch
```

---

## Commands

| Command | Purpose |
|---------|---------|
| `autoresearch` | Autonomous iteration loop (unlimited or bounded with `Iterations: N`) |
| `autoresearch:plan` | Interactive wizard: Goal → Scope, Metric, Direction, Verify config |
| `autoresearch:debug` | Autonomous bug-hunting — scientific method + iterative investigation |
| `autoresearch:fix` | Autonomous error repair — one fix per iteration until zero errors |
| `autoresearch:security` | STRIDE + OWASP + red-team security audit (read-only unless `--fix`) |
| `autoresearch:ship` | Universal shipping workflow — 8 phases, 9 shipment types |
| `autoresearch:scenario` | Scenario exploration — 12 dimensions, edge cases, derivative scenarios |
| `autoresearch:predict` | Multi-persona swarm — 5 expert perspectives before acting |
| `autoresearch:learn` | Autonomous documentation engine — scout, generate, validate, fix |
| `autoresearch:reason` | Adversarial refinement — blind judge panel for subjective domains |
| `autoresearch:probe` | Adversarial requirement / assumption interrogation — 8 personas probe to mechanical saturation, emits ready-to-run autoresearch config |

---

## Quick Start

### Basic autonomous loop

```
autoresearch
Goal: Increase test coverage from 72% to 90%
Scope: src/**/*.test.ts, src/**/*.ts
Metric: coverage % (higher is better)
Verify: npm test -- --coverage | grep "All files"
Iterations: 50
```

### Don't know what metric to use?

```
autoresearch:plan
Goal: Make the API respond faster
```

The wizard walks you through scope, metric, direction, and verify — with dry-run validation.

### Hunt all bugs

```
autoresearch:debug
Scope: src/api/**/*.ts
Symptom: API returns 500 on POST /users
Iterations: 20
```

### Fix all errors

```
autoresearch:fix
```

Auto-detects broken tests/types/lint/build, fixes one at a time, stops at zero errors.

### Security audit

```
autoresearch:security
Scope: src/**/*.ts
Iterations: 10
```

### Ship a PR

```
autoresearch:ship --auto
```

### Explore edge cases

```
autoresearch:scenario
Scenario: User attempts checkout with expired card
Iterations: 25
```

### Get expert opinions before acting

```
autoresearch:predict --chain debug
Scope: src/auth/**/*.ts
```

### Refine a subjective decision

```
autoresearch:reason
Task: Should we use event sourcing for order management?
Domain: software
Iterations: 8
```

---

## Configuration Fields

| Field | Required | Description |
|-------|----------|-------------|
| `Goal` | Yes | What you want to achieve (plain language) |
| `Scope` | Yes | Glob patterns for files the agent can modify |
| `Metric` | Yes | What number to optimize (higher/lower + unit) |
| `Verify` | Yes | Shell command that outputs the metric value |
| `Guard` | No | Safety command that must always pass (prevents regressions) |
| `Iterations` | No | Bounded run — stop after N iterations (default: unlimited) |
| `Direction` | No | `higher` or `lower` — which direction is better |

---

## Flags

### Core loop (`autoresearch`)

| Flag | Purpose |
|------|---------|
| `--scope <glob>` | Override scope |
| `--iterations <N>` | Bounded iteration count |

### Security (`autoresearch:security`)

| Flag | Purpose |
|------|---------|
| `--diff` | Only audit changed files |
| `--fix` | Auto-fix Critical/High findings |
| `--fail-on <severity>` | Non-zero exit for CI/CD gating |

### Ship (`autoresearch:ship`)

| Flag | Purpose |
|------|---------|
| `--auto` | Auto-approve if checklist passes |
| `--dry-run` | Validate without shipping |
| `--checklist-only` | Just check readiness |
| `--rollback` | Undo last ship |
| `--monitor <N>` | Post-ship monitoring (minutes) |

### Debug (`autoresearch:debug`)

| Flag | Purpose |
|------|---------|
| `--fix` | After hunting, auto-switch to fix mode |
| `--scope <glob>` | Limit investigation scope |
| `--symptom "<text>"` | Pre-fill symptom |

### Fix (`autoresearch:fix`)

| Flag | Purpose |
|------|---------|
| `--target <command>` | Explicit verify command |
| `--guard <command>` | Safety command |
| `--category <type>` | Only fix: test, type, lint, or build |
| `--from-debug` | Read findings from latest debug session |

### Predict (`autoresearch:predict`)

| Flag | Purpose |
|------|---------|
| `--chain <commands>` | Chain output to other commands |

### Reason (`autoresearch:reason`)

| Flag | Purpose |
|------|---------|
| `--iterations <N>` | Bounded rounds |
| `--judges <N>` | Judge count (3-7, odd preferred) |
| `--convergence <N>` | Consecutive wins to converge (default: 3) |
| `--mode <mode>` | convergent, creative, debate |
| `--domain <type>` | software, product, business, security, research, content |
| `--chain <targets>` | Chain converged output to other commands |

### Learn (`autoresearch:learn`)

| Flag | Purpose |
|------|---------|
| `--mode <mode>` | init, update, check, summarize |
| `--depth <level>` | shallow, standard, deep |
| `--file <path>` | Update single doc |

### Scenario (`autoresearch:scenario`)

| Flag | Purpose |
|------|---------|
| `--domain <type>` | software, product, business, security, marketing |
| `--depth <level>` | shallow, standard, deep |
| `--format <type>` | use-cases, user-stories, test-scenarios, threat-scenarios |
| `--focus <area>` | edge-cases, failures, security, scale |

---

## Chaining Commands

Commands can be chained with `--chain`:

```
autoresearch:debug --fix                      # debug → auto-fix
autoresearch:predict --chain debug            # predict → debug
autoresearch:predict --chain scenario,debug,fix  # full quality pipeline
autoresearch:reason --chain predict           # converge → stress-test
autoresearch:reason --chain plan,fix          # converge → implement
autoresearch:probe --chain plan,autoresearch  # interrogate → config → loop
autoresearch:probe --chain reason             # interrogate → debate → converge
```

---

## 8 Critical Rules

1. **Loop until done** — unbounded: forever. Bounded: N times then summarize.
2. **Read before write** — understand full context before modifying.
3. **One change per iteration** — atomic changes. If it breaks, you know why.
4. **Mechanical verification only** — no subjective "looks good." Use metrics.
5. **Automatic rollback** — failed changes revert instantly via `git revert`.
6. **Simplicity wins** — equal results + less code = KEEP.
7. **Git is memory** — experiments committed with `experiment:` prefix, agent reads `git log` + `git diff` before each iteration.
8. **When stuck, think harder** — re-read, combine near-misses, try radical changes.

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

---

## Agent-Specific Notes

### Claude Code

- Commands are invoked as `/autoresearch` and `/autoresearch:<subcommand>`
- Interactive setup uses `AskUserQuestion` when context is missing
- Skill files: `.claude/skills/autoresearch/SKILL.md` + `references/*.md`

### Codex

- Commands are invoked as plain text: `autoresearch` and `autoresearch:<subcommand>`
- Interactive setup uses `request_user_input` or direct question batches
- Plugin files: `plugins/autoresearch/` with `skills/`, `resources/`, `scripts/`
- Wrapper CLI: `bin/autoresearch <subcommand> [flags]`
- Canonical command spec: `plugins/autoresearch/resources/autoresearch-command-spec.json`

### Other Agents (OpenCode, Gemini CLI, etc.)

- Read this file for the command surface and configuration contract
- Use the core loop protocol: review → change → commit → verify → keep/revert → log
- Git is required — the loop uses `git commit`, `git revert`, `git log`, `git diff`
- Each iteration must be atomic (one change, one commit, one verification)
- For detailed workflow references, see: `claude-plugin/skills/autoresearch/references/*.md`

---

## Repository Structure

```
autoresearch/
├── AGENTS.md                          ← You are here
├── README.md                          ← Full documentation
├── COMPARISON.md                      ← Karpathy's vs Claude Autoresearch
├── guide/                             ← Comprehensive guides per command
├── claude-plugin/                     ← Claude Code distribution package
│   ├── skills/autoresearch/SKILL.md   ← Main skill + references/
│   └── commands/autoresearch/         ← Subcommand registrations
├── plugins/autoresearch/              ← Codex distribution package
│   ├── skills/autoresearch/SKILL.md   ← Codex skill router + references/
│   ├── resources/                     ← Command spec JSON
│   └── scripts/                       ← Wrapper CLI
└── bin/autoresearch                   ← Convenience wrapper
```

---

## License

MIT — see [LICENSE](LICENSE).

## Credits

- [Andrej Karpathy](https://github.com/karpathy) — [autoresearch](https://github.com/karpathy/autoresearch)
- [Anthropic](https://anthropic.com) — Claude Code
- [OpenAI](https://openai.com) — Codex
