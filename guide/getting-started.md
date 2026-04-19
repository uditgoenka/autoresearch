# Getting Started with Autoresearch

**By [Udit Goenka](https://udit.co)**

Autoresearch turns [Claude Code](https://docs.anthropic.com/en/docs/claude-code), [OpenCode](https://opencode.ai), or [OpenAI Codex](https://developers.openai.com/codex) into an autonomous improvement engine. Based on [Karpathy's autoresearch](https://github.com/karpathy/autoresearch), it follows one simple idea:

**Set a goal. Define a metric. Let Claude loop until it's done.**

Each iteration: make ONE change → measure → keep if better → revert if worse → repeat. Every improvement stacks. Every failure auto-reverts. Everything is logged.

This isn't limited to code. Autoresearch works on anything with a measurable outcome — sales emails, marketing copy, SEO content, test coverage, bundle size, API performance, security posture, and more.

---

## The 7 Principles

| # | Principle | What It Means |
|---|-----------|---------------|
| 1 | **Constraint = Enabler** | Bounded scope + single metric + time budget = autonomy |
| 2 | **Separate Strategy from Tactics** | You set the GOAL (what/why). Claude handles the HOW |
| 3 | **Metrics Must Be Mechanical** | Numbers only. No "looks good." Pass/fail, measurable, deterministic |
| 4 | **Verification Must Be Fast** | Fast checks = more experiments = better results |
| 5 | **Iteration Cost Shapes Behavior** | 5-min verify = 100 experiments/night. 10-sec verify = 360/hour |
| 6 | **Git as Memory** | Every experiment committed. Claude reads history to learn patterns |
| 7 | **Honest Limitations** | Know what the system can and cannot do |

**Meta-principle:** *Autonomy scales when you constrain scope, clarify success, mechanize verification, and let agents optimize tactics while humans optimize strategy.*

---

## Installation

### Option A — Plugin Install (Recommended)

In Claude Code, run:
```
/plugin marketplace add uditgoenka/autoresearch
/plugin install autoresearch@autoresearch
```

Then run `/reload-plugins` or restart Claude Code. All 9 commands are immediately available.

### Option B — Manual Install (Project-Level)

```bash
git clone https://github.com/uditgoenka/autoresearch.git

# Copy to your project
cp -r autoresearch/claude-plugin/skills/autoresearch .claude/skills/autoresearch
cp -r autoresearch/claude-plugin/commands/autoresearch .claude/commands/autoresearch
cp autoresearch/claude-plugin/commands/autoresearch.md .claude/commands/autoresearch.md
```

### Option C — Manual Install (Global)

```bash
git clone https://github.com/uditgoenka/autoresearch.git

# Copy globally (available in all projects)
cp -r autoresearch/claude-plugin/skills/autoresearch ~/.claude/skills/autoresearch
cp -r autoresearch/claude-plugin/commands/autoresearch ~/.claude/commands/autoresearch
cp autoresearch/claude-plugin/commands/autoresearch.md ~/.claude/commands/autoresearch.md
```

> **Important:** The `commands/` directory is required for subcommands (`/autoresearch:plan`, `/autoresearch:ship`, etc.) to work.

### Option D — Guided Installer

```bash
git clone https://github.com/uditgoenka/autoresearch.git
cd autoresearch
./scripts/install.sh  # interactive — choose Claude Code or OpenCode, global or local
```

### OpenCode Installation

```bash
git clone https://github.com/uditgoenka/autoresearch.git
cd autoresearch
./scripts/install.sh --opencode --global
```

Or manually:
```bash
cp -r autoresearch/.opencode/skills/autoresearch ~/.config/opencode/skills/autoresearch
cp autoresearch/.opencode/commands/autoresearch*.md ~/.config/opencode/commands/
cp autoresearch/.opencode/agents/docs-manager.md ~/.config/opencode/agents/docs-manager.md
```

> **OpenCode commands use underscores:** `/autoresearch_debug`, `/autoresearch_fix`, `/autoresearch_plan`, etc.

### Codex Installation

```bash
git clone https://github.com/uditgoenka/autoresearch.git
cd autoresearch
./scripts/install.sh --codex --global
```

Or manually:
```bash
cp -r autoresearch/.agents/skills/autoresearch ~/.agents/skills/autoresearch
```

> **Codex uses `$` mention syntax:** Type `$autoresearch` in your prompt, or `$autoresearch plan`, `$autoresearch debug`, etc. Codex discovers skills automatically from `.agents/skills/` directories.

### Kilo Installation

```bash
git clone https://github.com/uditgoenka/autoresearch.git
cd autoresearch
./scripts/install.sh --kilo --global
```

Or manually:
```bash
cp -r autoresearch/.opencode/skills/autoresearch ~/.config/kilo/skills/autoresearch
```

> **Kilo requires permission configuration:** The installer writes permissions to `~/.config/kilo/kilo.json`. Ensure Kilo can read the skills directory by adding permissions as needed.

### Verify Installation

- **Claude Code:** Type `/autoresearch` — if you see the interactive setup wizard, you're ready.
- **OpenCode:** Type `/autoresearch` — same wizard with underscore commands.
- **Codex:** Type `$autoresearch` or run `/skills` to see it listed.
- **Kilo:** Type `/autoresearch` — Kilo should auto-discover skills from `~/.config/kilo/skills/`.

### Complete Initialization (Iteration #0 — Baseline)

When you invoke `/autoresearch`, the agent automatically performs this initialization sequence before the first real iteration:

```bash
# Phase 0: Precondition Checks
git rev-parse --git-dir 2>/dev/null   # ✓ verify git repo exists
git status --porcelain                 # ✓ verify clean working tree
git symbolic-ref HEAD 2>/dev/null      # ✓ verify not in detached HEAD

# Phase 0: Establish Baseline Metric (Iteration #0)
# Agent runs the Verify command to get the starting value:
BASELINE=$(npx jest --coverage 2>&1 | grep 'All files' | awk '{print $4}')
echo "Baseline: ${BASELINE}%"

# Phase 0: Initialize Results Log
echo "# metric_direction: higher_is_better" > autoresearch-results.tsv
echo -e "iteration\tcommit\tmetric\tdelta\tguard\tstatus\tdescription" >> autoresearch-results.tsv
echo -e "0\t$(git rev-parse --short HEAD)\t${BASELINE}\t0.0\tpass\tbaseline\tinitial state — coverage ${BASELINE}%" >> autoresearch-results.tsv

# Phase 0: Protect log from git
echo "autoresearch-results.tsv" >> .gitignore
git add .gitignore && git commit -m "chore: add autoresearch results log to gitignore"

# ✓ Initialization complete — entering iteration loop
# Agent now proceeds to Phase 1 (Review) → Phase 2 (Ideate) → ...
```

This is all automatic — you just run `/autoresearch` with your goal, scope, and verify command. The agent handles Phase 0 internally.

---

## Your First Run

### The 60-Second Start

```
/autoresearch
Goal: Increase test coverage from 72% to 90%
Scope: src/**/*.test.ts, src/**/*.ts
Metric: coverage % (higher is better)
Verify: npm test -- --coverage | grep "All files"
```

That's it. Claude reads all files, establishes a baseline, and starts iterating. Walk away.

### The Guided Start (No Config Needed)

Just type:
```
/autoresearch
```

Claude will ask you smart questions based on your codebase:

1. **What's your goal?** — "Increase test coverage", "Reduce bundle size", etc.
2. **Which files can be modified?** — Suggests globs based on your project structure
3. **What metric tells you it's better?** — Suggests metrics from detected tooling
4. **Higher or lower is better?** — Direction of improvement
5. **What command produces the metric?** — Suggests commands, dry-runs to confirm
6. **Any guard command?** — Optional safety net to prevent regressions
7. **Ready to go?** — Launch unlimited, with iteration limit, or cancel

### Don't Know What Metric to Use?

```
/autoresearch:plan
Goal: Make the API respond faster
```

The plan wizard walks you through 5 steps, dry-runs your verify command, and hands you a ready-to-paste configuration.

---

## Core Concepts

### The Loop

Every autoresearch run follows the same cycle:

```
LOOP:
  1. Review — Read current state + git history + results log
  2. Ideate — Pick next change based on past results
  3. Modify — Make ONE focused change
  4. Commit — Git commit (before verification)
  5. Verify — Run mechanical metric
  6. Guard — Run safety command (if set)
  7. Decide — Keep / Discard / Rework
  8. Log — Record result in TSV
  9. Repeat
```

### Metric vs Guard

| | Metric (Verify) | Guard |
|--|-----------------|-------|
| **Purpose** | "Did we improve?" | "Did we break anything?" |
| **Required** | Yes | No (optional) |
| **Example** | `coverage %`, `bundle size KB` | `npm test`, `tsc --noEmit` |
| **On failure** | Revert change | Rework the change (max 2 attempts) |

**When to use Guard:** When your metric is NOT your test suite. If you're optimizing bundle size, performance, or Lighthouse score — set `Guard: npm test` to prevent regressions.

### Results Log

Every iteration is tracked in TSV format:

```tsv
iteration  commit   metric  delta   guard  status    description
0          a1b2c3d  85.2    0.0     -      baseline  initial state
1          b2c3d4e  87.1    +1.9    pass   keep      add auth edge case tests
2          -        86.5    -0.6    -      discard   refactor helpers (broke 2 tests)
3          c3d4e5f  88.3    +1.2    pass   keep      add error handling tests
```

Every 10 iterations, Claude prints a progress summary. Bounded loops print a final summary.

### Bounded vs Unbounded

| Mode | Syntax | Behavior |
|------|--------|----------|
| **Unbounded** | No `Iterations:` | Loops forever until you press `Ctrl+C` |
| **Bounded** | `Iterations: 25` | Loops exactly 25 times, then prints summary |

**When to use what:**

| Scenario | Mode |
|----------|------|
| Overnight improvement run | Unbounded |
| Quick 30-min session | `Iterations: 10` |
| Targeted fix, known scope | `Iterations: 5` |
| Exploratory — testing approach | `Iterations: 15` |
| CI/CD pipeline | `Iterations: N` (based on time budget) |

---

## Writing Great Metrics

The quality of your metric determines the quality of your results. Here's how to write metrics that work.

### The 4 Rules

1. **Mechanical** — Outputs a parseable number. No "looks good"
2. **Deterministic** — Same input = same output. No randomness
3. **Fast** — Under 30 seconds. Faster = more experiments
4. **Extractable** — Can be piped through grep/awk/jq to get the number

### Metric Cheat Sheet

| Domain | Metric | Direction | Verify Command |
|--------|--------|-----------|----------------|
| Testing | Coverage % | Higher | `npm test -- --coverage \| grep "All files"` |
| Testing | Passing tests count | Higher | `npm test 2>&1 \| grep "Tests:"` |
| Bundle | Size in KB | Lower | `npm run build 2>&1 \| grep "gzipped"` |
| Performance | p95 latency ms | Lower | `npm run bench \| grep "p95"` |
| Performance | Lighthouse score | Higher | `npx lighthouse URL --output=json \| jq '.categories.performance.score * 100'` |
| Code quality | `any` count | Lower | `grep -r "any" src/ --include="*.ts" \| wc -l` |
| Code quality | Lint errors | Lower | `npx eslint src/ 2>&1 \| grep "problems"` |
| Code quality | LOC | Lower | `wc -l src/**/*.ts \| tail -1` |
| Code quality | Complexity | Lower | `npx complexity-report src/ \| grep "avg"` |
| Build | Build time (s) | Lower | `time npm run build 2>&1 \| grep real` |
| Content | Readability score | Higher | `python scripts/readability.py \| grep "score"` |
| Content | Word count | Higher | `wc -w content/**/*.md \| tail -1` |
| SEO | Meta compliance count | Higher | `python scripts/meta-audit.py \| grep "compliant"` |
| Accessibility | Violations count | Lower | `npx axe-cli URL \| grep "violations"` |
| Docker | Image size MB | Lower | `docker images app:test --format '{{.Size}}'` |
| CI/CD | Pipeline duration min | Lower | Custom script via `gh` CLI |
| Security | OWASP coverage % | Higher | Composite (built-in to security command) |
| ML | Validation accuracy | Higher | `python train.py --eval \| grep "val_acc"` |
| ML | Inference time ms | Lower | `python benchmark.py \| grep "avg_ms"` |

### Bad Metrics (Avoid These)

| Bad Metric | Why It's Bad | Better Alternative |
|------------|--------------|-------------------|
| "Code looks cleaner" | Subjective, not mechanical | Lint error count (lower) |
| "Feels faster" | No number, not verifiable | p95 latency in ms |
| "Better test quality" | Can't measure quality directly | Coverage %, mutation score |
| "More readable" | Subjective | Readability score (Flesch-Kincaid) |
| Random test output | Non-deterministic | Retry 3x, take median |

---

## Crash Recovery

| Failure Type | Automatic Response |
|--------------|-------------------|
| Syntax error | Fix immediately, don't count as iteration |
| Runtime error | Attempt fix (max 3 tries), then move on |
| Resource exhaustion | Revert, try smaller variant |
| Infinite loop / hang | Kill after timeout, revert |
| External dependency failure | Skip, log, try different approach |

---

## Troubleshooting

### Common Issues

| Problem | Cause | Fix |
|---------|-------|-----|
| "Verify command failed" | Command doesn't work on current codebase | Run the command manually first. Use `/autoresearch:plan` to validate |
| Metric doesn't improve | Scope too narrow, or already near optimal | Expand scope, lower the goal, or try a different approach |
| Guard keeps failing | Changes are breaking existing behavior | Make scope more targeted, or add the broken tests to scope |
| "5+ consecutive discards" | Stuck in local minimum | Claude will automatically try radical changes. If still stuck, expand scope |
| Loop seems slow | Verify command takes too long | Optimize verify command (use `--quick-eval`, reduce test scope) |
| Wrong metric extracted | Verify output format changed | Check verify command output manually, adjust grep pattern |

### When Stuck

If Claude has 5+ consecutive discards, it automatically:
1. Re-reads ALL in-scope files
2. Re-reads original goal
3. Reviews entire results log for patterns
4. Tries combining 2-3 successful changes
5. Tries the OPPOSITE of what hasn't worked
6. Tries radical architectural change

---

## FAQ

**Q: I don't know what metric to use.**
A: Run `/autoresearch:plan` — it analyzes your codebase, suggests metrics, and dry-runs the verify command before you launch.

**Q: Does this work with any project?**
A: Yes. Any language, framework, or domain. If you can measure it with a command, autoresearch can optimize it.

**Q: How do I stop the loop?**
A: `Ctrl+C` or add `Iterations: N` for bounded runs. Claude commits before verifying, so your last successful state is always in git.

**Q: Can I use this for non-code tasks?**
A: Absolutely. Sales emails, marketing copy, HR policies, research papers — anything with a measurable metric.

**Q: Does /autoresearch:security modify my code?**
A: No. It's read-only. Use `--fix` to opt into auto-remediation of confirmed Critical/High findings.

**Q: Can I chain commands?**
A: Yes. Run `debug → fix → ship`, or `plan → loop → ship`, or `scenario → debug → fix`. Each command's output feeds the next. See [Chains & Combinations](chains-and-combinations.md).

**Q: What's the difference between Metric and Guard?**
A: Metric = "did we improve?" (the goal). Guard = "did we break anything?" (safety net). If metric improves but guard fails, Claude reworks the change.

**Q: Can I use MCP servers during the loop?**
A: Yes. Any MCP server configured in Claude Code is available — databases, analytics, APIs, etc.

**Q: How many iterations should I run?**
A: Depends on scope. 5-10 for targeted fixes. 15-25 for moderate improvements. 50+ for deep optimization. Unlimited for overnight runs.

**Q: Does it work with OpenAI Codex?**
A: Yes. Run `./scripts/install.sh --codex --global` or copy `.agents/skills/autoresearch/` to `~/.agents/skills/`. Use `$autoresearch` mention syntax to invoke.

**Q: Does it work in CI/CD?**
A: Yes. Use `--fail-on` (security) or bounded iterations. See [Advanced Patterns](advanced-patterns.md).

**Q: What if Claude makes things worse?**
A: Every change is committed before verification. If worse, it's instantly `git revert`ed. Your codebase is always in a known-good state.

**Q: Can I run it overnight?**
A: Yes. That's the intended use case for unbounded mode. Run `/autoresearch` without `Iterations:`, walk away, review results in the morning.

**Q: What languages are supported?**
A: All of them. The loop is language-agnostic. The verify command adapts to your tooling (npm, pytest, cargo, go test, etc.).

---

<div align="center">

**Built by [Udit Goenka](https://udit.co)** | [GitHub](https://github.com/uditgoenka/autoresearch) | [Follow @iuditg](https://x.com/iuditg)

*"Set the GOAL → Claude runs the LOOP → You wake up to results"*

</div>
