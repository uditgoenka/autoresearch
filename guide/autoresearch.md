# /autoresearch — The Autonomous Loop

## What It Does

`/autoresearch` is the core command. It runs an autonomous modify → verify → keep/discard loop for 25 iterations by default (override with `Iterations: N` or `Iterations: unlimited`). You give it a goal, a scope of files it can touch, a shell command that outputs a numeric metric, and an optional guard that must stay green. Claude picks the highest-impact change, commits it, measures the result, and either keeps the improvement or reverts the commit — repeating until iterations are exhausted or the goal is met. It learns from its own history: what worked in earlier iterations informs what it tries next.

---

## Full Syntax

```
/autoresearch
Goal:       <what you want to improve>
Scope:      <file globs Claude can modify>
Metric:     <what number to track> (<direction>)
Verify:     <shell command whose output contains the metric>
Guard:      <optional command that must always pass>
Iterations: <N | unlimited — default: 25>
```

### Universal Flags

| Flag | Purpose |
|------|---------|
| `Iterations: N` | Run exactly N iterations (default: 25) |
| `Iterations: unlimited` | Run forever until goal met or Ctrl+C |
| `--evals` | Run evals analysis at end of loop |
| `--evals-interval N` | Run evals every N iterations mid-loop |
| `--chain <targets>` | Hand off to next command(s) after loop |
| `--no-fork` | Disable fork-and-flush rounds |
| `Forks: K` | Branches per fork-and-flush round (default 4) |
| `Guided: R` | Fraction of fork branches given an Advisor-assigned experiment (default 0.5) |

### Config Fields

| Field | Required | Description |
|-------|----------|-------------|
| `Goal` | Yes | Plain-language target. Include a concrete number when possible. |
| `Scope` | Recommended | Glob patterns for files Claude may modify. |
| `Metric` | Recommended | Number being tracked. Always specify direction. |
| `Verify` | Recommended | Shell command whose stdout contains the metric value. |
| `Guard` | Optional | Must exit 0 after every kept change. |
| `Iterations` | Optional | Default: 25. Use `unlimited` for overnight runs. |

---

## What Happens Each Iteration

1. Read codebase, git history, and results log
2. Pick highest-impact change based on prior results
3. Make ONE atomic change — explainable in one sentence
4. Commit (so rollback is always clean)
5. Run `Verify`, extract the metric
6. Run `Guard` (if set)
7. Metric improved + guard passed → **keep** | Metric worse → `git revert` | Guard failed → rework (max 2 attempts)
8. Log result to TSV, move to next iteration

---

## Examples

### Increase test coverage (bounded)

```
/autoresearch
Iterations: 20
Goal: Increase test coverage from 72% to 90%
Scope: src/**/*.test.ts, src/**/*.ts
Metric: coverage % (higher is better)
Verify: npm test -- --coverage | grep "All files"
```

### Reduce bundle size

```
/autoresearch
Iterations: 15
Goal: Reduce production bundle size below 200KB
Scope: src/**/*.tsx, src/**/*.ts
Metric: bundle size in KB (lower is better)
Verify: npm run build 2>&1 | grep "First Load JS"
Guard: npm test
```

### Eliminate TypeScript `any` types

```
/autoresearch
Iterations: 25
Goal: Eliminate all TypeScript `any` types
Scope: src/**/*.ts
Metric: count of `any` occurrences (lower is better)
Verify: grep -r ":\s*any" src/ --include="*.ts" | wc -l
Guard: tsc --noEmit
```

### API performance (p95 latency)

```
/autoresearch
Iterations: 20
Goal: API response time under 100ms (p95)
Scope: src/api/**/*.ts, src/services/**/*.ts
Metric: p95 response time in ms (lower is better)
Verify: npm run bench:api | grep "p95"
Guard: npm test
```

### pytest coverage (Python)

```
/autoresearch
Iterations: 30
Goal: Increase pytest coverage from 68% to 90%
Scope: tests/**/*.py, app/**/*.py
Metric: coverage % (higher is better)
Verify: pytest --cov=app --cov-report=term-missing 2>&1 | grep "TOTAL" | awk '{print $4}'
```

### Go test coverage

```
/autoresearch
Iterations: 25
Goal: Increase test coverage to 85%
Scope: **/*.go
Metric: coverage % (higher is better)
Verify: go test ./... -coverprofile=cover.out && go tool cover -func=cover.out | grep "total:" | awk '{print $3}'
```

### ML training loss

```
/autoresearch
Iterations: unlimited
Goal: Reduce validation loss (val_bpb)
Scope: train.py, model.py
Metric: val_bpb (lower is better)
Verify: uv run train.py --epochs 1 2>&1 | grep "val_bpb" | tail -1 | awk '{print $NF}'
```

### SEO content optimization

```
/autoresearch
Iterations: 25
Goal: Maximize SEO score for target keywords
Scope: content/blog/*.md
Metric: SEO score (higher is better)
Verify: node scripts/seo-score.js --file content/blog/target-post.md
```

### With evals checkpoint every 5 iterations

```
/autoresearch
Iterations: 25
Goal: Reduce lint errors to zero
Scope: src/**/*.ts
Metric: lint error count (lower is better)
Verify: npx eslint src/ 2>&1 | grep -c "error"
--evals
--evals-interval 5
```

---

## Guard Patterns

Guard prevents regressions while you optimize a different metric.

```
# Bundle size without breaking tests
Guard: npm test

# Performance without breaking types and tests
Guard: tsc --noEmit && npm test

# Lighthouse without breaking e2e tests
Guard: npx playwright test
```

**Recovery flow when guard fails:**
1. Metric improves, guard fails
2. Revert immediately
3. Read guard output to understand what broke
4. Rework the optimization (max 2 attempts)
5. If both fail — discard, move to next iteration

---

## Bounded vs Unbounded

| | Bounded (`Iterations: N`) | Unbounded (`Iterations: unlimited`) |
|---|---|---|
| **Stops when** | N iterations complete | Goal met or Ctrl+C |
| **Best for** | Sprints, CI, fixed budgets | Overnight runs |
| **CI usage** | Yes | Only with external timeout |
| **Default** | 25 | n/a |

**Guideline:** Run `Iterations: 10` first to calibrate. If results look good, increase or remove the limit.

---

## Getting Unstuck: Fork-and-Flush

A single loop tends to improve inside one family of ideas and plateau there, because its own conversation keeps
steering it back to the same approach. Fork-and-flush ([Cai et al., arXiv:2610.07447](https://arxiv.org/abs/2610.07447))
gets it out:

1. Take the best commit so far (the incumbent) and protect it.
2. Start K fresh agents from it (default 4) that see only the files and the results TSV, not the leader's
   reasoning.
3. Run each for a small budget (about 6% of the total), keep the best, and let that branch lead.

Rounds run on a fixed schedule, at 33% and 66% of the iteration budget, plus early when 5 iterations pass with
no `keep`. The paper found plateau-triggered rounds fire too late: small gains keep resetting the stall clock.
At matched budget it scored 0.78 against 0.47 for a single run and 0.54 for best-of-4.

```
/autoresearch
Goal: Reduce p95 latency
Metric: p95 ms (lower is better)
Verify: ./bench.sh | tail -1
Iterations: 30
Forks: 2
```

Use `Forks: 2` when Verify is slow or needs a single shared resource (one local stack, one test database); the
branches then run one after another. Use `--no-fork` for mechanical sweeps with no ideas to get stuck on.

### Random and guided branches

Each round mixes two kinds of branch:

- **Random** branches get only the task. Each fresh agent works out its own next idea, which is where the
  randomness comes from.
- **Guided** branches each get one concrete experiment from a stateless Advisor
  ([Zhang et al., arXiv:2610.07625](https://arxiv.org/abs/2610.07625)). The Advisor reads the results TSV and
  `git log`, then hands out experiments that differ from each other and from every logged failure, so no budget
  is spent twice on the same idea.

`Guided: R` sets the split: `floor(K × R)` guided, the rest random. The default 0.5 gives 2 + 2 at K = 4 and
1 + 1 at K = 2. `Guided: 0` is fork-and-flush as published. The summary reports wins by kind, so you can move R
toward whichever kind keeps winning.

---

## Results TSV

```tsv
iteration  commit   metric  delta   guard  status    description
0          a1b2c3d  85.2    0.0     -      baseline  initial state
1          b2c3d4e  87.1    +1.9    pass   keep      add auth edge case tests
2          -        86.5    -0.6    -      discard   refactor helpers
3          c3d4e5f  88.3    +1.2    pass   keep      add error handling tests
```

Use `/autoresearch:evals` after a run to analyze trends, plateaus, and velocity from the TSV.

---

## When to Use Other Commands

| Situation | Command |
|-----------|---------|
| You have a measurable metric to improve | `/autoresearch` |
| You don't know what metric to use | `/autoresearch:plan` |
| Requirements are unclear | `/autoresearch:probe` |
| Tests are failing, types broken, lint is red | `/autoresearch:fix` |
| Bugs but you don't know where | `/autoresearch:debug` |
| Pre-release security review | `/autoresearch:security` |
| Ready to ship | `/autoresearch:ship` |
| Explore edge cases before building | `/autoresearch:scenario` |
| Want expert opinions first | `/autoresearch:predict` |

---

## Tips

- Write a tight `Verify` command. One number, cleanly extracted with `grep`/`awk`/`jq`.
- Run your `Verify` command manually before starting — know your baseline.
- Use `Guard: npm test` liberally when your metric isn't test pass rate.
- Run `Iterations: 10` first on an unfamiliar codebase, then scale up.
- `git log` after a run shows exactly what changed and why. `git revert <hash>` undoes any single change.

---

## Related Guides

- [/autoresearch:plan](autoresearch-plan.md) — when you need help choosing Scope and Metric
- [/autoresearch:fix](autoresearch-fix.md) — when errors need fixing before you can optimize
- [/autoresearch:evals](autoresearch-evals.md) — analyze results TSV after a run
- [Chains & Combinations](chains-and-combinations.md) — combining with debug, security, ship
- [Advanced Patterns](advanced-patterns.md) — custom verification scripts, MCP, CI/CD
