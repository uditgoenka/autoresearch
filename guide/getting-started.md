# Getting Started with Autoresearch

**By [Udit Goenka](https://udit.co)**

Autoresearch turns [Claude Code](https://docs.anthropic.com/en/docs/claude-code), [OpenCode](https://opencode.ai), or [OpenAI Codex](https://developers.openai.com/codex) into an autonomous improvement engine. Based on [Karpathy's autoresearch](https://github.com/karpathy/autoresearch):

**Set a goal. Define a metric. Let Claude loop until it's done.**

Each iteration: make ONE change → measure → keep if better → revert if worse → repeat. Every improvement stacks. Every failure auto-reverts. Everything is logged.

Works on anything with a measurable outcome — code coverage, bundle size, API performance, sales emails, SEO content, security posture, and more.

---

## Installation

### Claude Code (Recommended)

```bash
npx skills add uditgoenka/autoresearch
```

All 14 commands are immediately available. No restart needed.

### Manual — Project-Level

```bash
git clone https://github.com/uditgoenka/autoresearch.git
cp -r autoresearch/.claude/skills/autoresearch .claude/skills/autoresearch
cp -r autoresearch/.claude/commands/autoresearch .claude/commands/autoresearch
```

### Manual — Global

```bash
git clone https://github.com/uditgoenka/autoresearch.git
cp -r autoresearch/.claude/skills/autoresearch ~/.claude/skills/autoresearch
cp -r autoresearch/.claude/commands/autoresearch ~/.claude/commands/autoresearch
```

### OpenCode

```bash
git clone https://github.com/uditgoenka/autoresearch.git
cd autoresearch
./scripts/transform.sh --opencode --global
```

> **OpenCode commands use underscores:** `/autoresearch_debug`, `/autoresearch_fix`, etc.

### Codex

```bash
git clone https://github.com/uditgoenka/autoresearch.git
cd autoresearch
./scripts/transform.sh --codex --global
```

> **Codex uses `$` mention syntax:** `$autoresearch`, `$autoresearch debug`, `$autoresearch fix`, etc.

### Verify Installation

- **Claude Code:** Type `/autoresearch` — if the setup wizard appears, you are ready.
- **OpenCode:** Type `/autoresearch` — same wizard, underscore subcommands.
- **Codex:** Type `$autoresearch` or run `/skills` to confirm it is listed.

---

## The 14 Commands

| Command | Does | Default Iterations |
|---------|------|--------------------|
| `/autoresearch` | Iterate against metric | 25 |
| `/autoresearch:plan` | Goal → config wizard | one-shot |
| `/autoresearch:debug` | Hunt bugs scientifically | 15 |
| `/autoresearch:fix` | Crush errors to zero | 20 |
| `/autoresearch:security` | STRIDE + OWASP audit | 15 |
| `/autoresearch:ship` | 8-phase shipping | linear |
| `/autoresearch:scenario` | Edge cases × 12 dimensions | 20 |
| `/autoresearch:predict` | 5 expert personas debate | one-shot |
| `/autoresearch:learn` | Scout → generate → validate docs | 10 |
| `/autoresearch:reason` | Adversarial debate + blind judges | 8 |
| `/autoresearch:probe` | 8 personas interrogate requirements | 15 |
| `/autoresearch:improve` | Research ICP, discover improvements, PRDs | 15 |
| `/autoresearch:evals` | Analyze results TSV | one-shot |
| `/autoresearch:regression` | Stability gate — baseline diff, ship/no-ship | gate |

---

## Your First Run

```
/autoresearch
Goal: Increase test coverage from 72% to 90%
Scope: src/**/*.test.ts, src/**/*.ts
Metric: coverage % (higher is better)
Verify: npm test -- --coverage | grep "All files"
```

That's it. Claude reads all files, establishes a baseline, and starts iterating.

### Bounded Run (Recommended to Start)

```
/autoresearch
Iterations: 10
Goal: Increase test coverage from 72% to 90%
Scope: src/**/*.test.ts, src/**/*.ts
Metric: coverage % (higher is better)
Verify: npm test -- --coverage | grep "All files"
```

Run 10 iterations first. Review the TSV log. If the approach looks right, remove the limit.

### Don't Know What Metric to Use?

```
/autoresearch:plan
Goal: Make the API respond faster
```

The wizard scans your stack, suggests Scope/Metric/Verify, dry-runs the command, and hands you a ready-to-paste config.

---

## Core Concepts

### The Loop

```
LOOP (each iteration):
  1. Review   — read codebase + git history + results log
  2. Ideate   — pick next change based on past results
  3. Modify   — make ONE focused change
  4. Commit   — git commit (before verification)
  5. Verify   — run mechanical metric
  6. Guard    — run safety command (if set)
  7. Decide   — keep / discard / rework
  8. Log      — append to TSV
  9. Repeat
```

### Bounded Defaults

Every looping command has a default iteration count. Override inline:

```
Iterations: N          # run exactly N iterations
Iterations: unlimited  # run forever (or until Ctrl+C)
```

| Default | Command |
|---------|---------|
| 25 | `/autoresearch` |
| 15 | `/autoresearch:debug`, `/autoresearch:security`, `/autoresearch:probe` |
| 20 | `/autoresearch:fix`, `/autoresearch:scenario` |
| 10 | `/autoresearch:learn` |
| 8 | `/autoresearch:reason` |

### Metric vs Guard

| | Metric (Verify) | Guard |
|--|-----------------|-------|
| **Purpose** | "Did we improve?" | "Did we break anything?" |
| **Required** | Yes | No (optional) |
| **Example** | `coverage %`, `bundle size KB` | `npm test`, `tsc --noEmit` |
| **On failure** | Revert change | Rework (max 2 attempts), then discard |

Use Guard when your metric is not your test suite. Optimizing bundle size? Set `Guard: npm test`.

### Chain Handoff

Commands pass context forward via `handoff.json`. No copy-pasting between stages:

```
/autoresearch:probe --chain plan
/autoresearch:predict --chain scenario,debug,fix,ship
/autoresearch:reason --chain predict,fix
```

### Evals Checkpoints

Add `--evals` to any looping command to analyze results mid-loop, or run `/autoresearch:evals` after any run to inspect the TSV:

```
/autoresearch
Iterations: 25
Goal: Reduce bundle size below 200KB
--evals
--evals-interval 5
```

### Results Log

Every iteration is tracked in TSV format:

```tsv
iteration  commit   metric  delta   guard  status    description
0          a1b2c3d  85.2    0.0     -      baseline  initial state
1          b2c3d4e  87.1    +1.9    pass   keep      add auth edge case tests
2          -        86.5    -0.6    -      discard   refactor helpers
3          c3d4e5f  88.3    +1.2    pass   keep      add error handling tests
```

---

## Platform Syntax Reference

| Platform | Subcommand syntax | Example |
|----------|-------------------|---------|
| Claude Code | `/autoresearch:debug` | `/autoresearch:fix --category type` |
| OpenCode | `/autoresearch_debug` | `/autoresearch_fix --category type` |
| Codex | `$autoresearch debug` | `$autoresearch fix --category type` |

---

## FAQ

**Q: How do I stop the loop?**
`Ctrl+C` or add `Iterations: N`. Claude commits before verifying, so your last good state is always in git.

**Q: Does this work with any language?**
Yes. The loop is language-agnostic. The verify command adapts to your tooling.

**Q: Can I use this for non-code tasks?**
Yes. Sales emails, SEO content, HR policies — anything with a measurable metric.

**Q: What if Claude makes things worse?**
Every change is committed before verification. If worse, it is instantly `git revert`ed.

**Q: Can I chain commands?**
Yes. See [Chains & Combinations](chains-and-combinations.md).

**Q: Does `/autoresearch:security` modify my code?**
No. Read-only by default. Use `--fix` to opt into auto-remediation.

---

<div align="center">

**Built by [Udit Goenka](https://udit.co)** | [GitHub](https://github.com/uditgoenka/autoresearch) | [Follow @iuditg](https://x.com/iuditg)

*"Set the GOAL → Claude runs the LOOP → You wake up to results"*

</div>
