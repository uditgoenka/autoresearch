# Autonomous Loop Protocol

Detailed protocol for the autoresearch iteration loop. SKILL.md has the summary; this file has the full rules.

## Loop Modes

Autoresearch supports two loop modes:

- **Unbounded (default):** Loop forever until manually interrupted (`Ctrl+C`)
- **Bounded:** Loop exactly N times when `Iterations: N` is set in the inline config (or `--iterations N` flag for CLI/CI)

When bounded, track `current_iteration` against `max_iterations`. After the final iteration, print a summary and stop.

## Phase 0: Precondition Checks (before loop starts)

**MUST complete ALL checks before entering the loop. Fail fast if any check fails.**

```bash
# 1. Verify git repo exists
git rev-parse --git-dir 2>/dev/null || echo "FAIL: not a git repo"
# → If not a git repo: ask user to run `git init` or abort

# 2. Check for dirty working tree
git status --porcelain
# → If dirty: warn user and ask to stash or commit first
#   NEVER proceed with uncommitted user changes — explicit git add will stage them

# 3. Check for stale lock files
ls .git/index.lock 2>/dev/null && echo "WARN: stale lock"
# → If lock exists: remove it (rm .git/index.lock) or warn user

# 4. Check for detached HEAD
git symbolic-ref HEAD 2>/dev/null || echo "WARN: detached HEAD"
# → If detached: warn user, suggest `git checkout <branch>`

# 5. Check for git hooks that might interfere
ls .git/hooks/pre-commit .git/hooks/commit-msg 2>/dev/null && echo "INFO: git hook detected"
ls .husky/pre-commit .husky/commit-msg 2>/dev/null && echo "INFO: husky hook detected"
ls .pre-commit-config.yaml 2>/dev/null && echo "INFO: pre-commit framework detected"
# → If hooks exist: note in setup log. If hook blocks commits during loop,
#   treat as crash and log "hook blocked commit" — do NOT use --no-verify
```

**If metric-valued guard is configured** (has `Guard-Direction` and `Guard-Threshold`):

```bash
# 6. Extract guard-metric baseline
GUARD_BASELINE=$(<guard command>)
# Validate it's a valid number (same rules as verify metric)
# Record alongside the primary metric baseline in iteration 0
```

**If any FAIL:** Stop and inform user. Do not enter the loop with broken preconditions.
**If any WARN:** Log the warning, proceed with caution, inform user.

## Phase 1: Review (30 seconds)

Before each iteration, build situational awareness. **You MUST complete ALL 6 steps — git history is critical for learning from past iterations.**

```
1. Read current state of in-scope files (full context)
2. Read last 10-20 entries from results log
3. MUST run: git log --oneline -20 to see recent changes
4. MUST run: git diff HEAD~1 (if last iteration was "keep") to review what worked
5. Identify: what worked, what failed, what's untried — based on BOTH results log AND git history
6. If bounded: check current_iteration vs max_iterations
```

**Why read git history every time?** Git IS the memory. After rollbacks, state may differ from what you expect. The git log shows which experiments were kept vs reverted. The git diff of kept changes reveals WHAT specifically improved the metric — use this to inform the next iteration. Never assume — always verify.

**Git history usage pattern:**
- `git log --oneline -20` → see the sequence of experiments (kept commits remain, discarded ones are reverted)
- `git diff HEAD~1` → inspect the last kept change to understand WHY it worked
- `git log --all --oneline` → if working on a branch, see full experiment history
- Use commit messages (e.g., "experiment: increase batch size") to avoid repeating failed approaches

## Git as Memory — Configuration

Git as Memory is **always enabled** — it's a core behavior, not optional. The agent reads its own git history every iteration to learn from past experiments.

### Configuration Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| Memory depth | 20 commits | How far back to read history |
| Diff review | HEAD~1 | How far back to diff kept changes |
| Full history | disabled | Read all branches |

### How It Works (step by step)

At the start of EVERY iteration (Phase 1), the agent runs:

```bash
# Step 1: Read recent experiment history
git log --oneline -20
# Shows: kept commits remain, discarded ones were reverted

# Step 2: Inspect the last successful change
git diff HEAD~1
# Shows: exact diff that improved the metric — informs next experiment

# Step 3: Check what was tried (avoid repeating failures)
git log --oneline -20 | grep "experiment"
# Shows: all experiment descriptions

# Step 4: Deep-dive a specific success
git show abc1234 --stat
# Shows: which files were changed in a successful experiment
```

### Example: Memory in Action

```
# Agent reads git log and sees:
# a1b2c3d experiment(api): add response caching — KEPT (metric improved)
# d4e5f6g Revert "experiment(api): increase cache TTL to 60s" — REVERTED
# c3d4e5f experiment(api): add cache invalidation on write — KEPT
#
# Agent learns:
# ✓ Caching works (2 kept commits)
# ✗ Increasing TTL didn't help (reverted)
# → Next: try a different cache strategy, NOT longer TTL
```

### Git Memory Integration with the Autonomous Loop

Shows exactly how git memory integrates at each loop phase with executable bash.

```bash
# === PHASE 0: Initialize Git Memory ===
# Verify git repo is ready for memory tracking
git_memory_init() {
  git rev-parse --git-dir 2>/dev/null || { echo "FAIL: not a git repo"; return 1; }
  git status --porcelain | grep -q . && { echo "WARN: dirty tree — stash or commit first"; return 1; }
  echo "✓ Git memory initialized — $(git log --oneline | wc -l) commits available"
}

# === PHASE 1: Read Git Memory ===
# Called at the START of every iteration to build situational awareness
read_git_memory() {
  local depth=${1:-20}

  # 1. Recent experiment history (what was tried)
  echo "=== Recent Experiments ==="
  git log --oneline -"$depth" | grep -E "experiment|Revert"

  # 2. Last successful change (what worked and why)
  echo "=== Last Kept Change ==="
  git diff HEAD~1 --stat 2>/dev/null

  # 3. Pattern detection (which files drive improvements)
  echo "=== Success Patterns ==="
  git log --oneline -"$depth" --diff-filter=M --name-only | sort | uniq -c | sort -rn | head -5

  # 4. Failed approaches (what to avoid)
  echo "=== Reverted Experiments (avoid repeating) ==="
  git log --oneline -"$depth" | grep "Revert" | sed 's/Revert "//' | sed 's/"$//'
}

# === PHASE 2: Query Git Memory for Decision Making ===
# Before choosing the next experiment, the agent queries history
query_git_memory() {
  local query="$1"

  # Find commits related to a topic
  git log --oneline -20 --grep="$query" 2>/dev/null

  # Check if this approach was already tried and reverted
  if git log --oneline -20 | grep -q "Revert.*$query"; then
    echo "⚠ WARNING: '$query' was tried before and REVERTED — try a different approach"
    return 1
  fi
  return 0
}

# === PHASE 6: Write to Git Memory ===
# Commit becomes memory. Revert becomes "lesson learned."
write_git_memory() {
  local scope="$1" description="$2"
  git add "$scope"
  git commit -m "experiment($scope): $description"
  echo "✓ Experiment committed to git memory"
}
```

### Error Handling for Git Operations

```bash
# Safe git operations with error handling
safe_git_log() {
  git log --oneline -"${1:-20}" 2>/dev/null || echo "WARN: git log failed — empty repo?"
}

safe_git_diff() {
  git diff HEAD~1 --stat 2>/dev/null || echo "INFO: no previous commit to diff (first iteration)"
}

# Handle detached HEAD (common after revert conflicts)
ensure_on_branch() {
  if ! git symbolic-ref HEAD 2>/dev/null; then
    echo "WARN: detached HEAD detected — creating recovery branch"
    git checkout -b autoresearch-recovery-$(date +%s)
  fi
}
```

### Complete Integration Example

```
/autoresearch
Goal: Improve ML model accuracy from 85% to 95%
Scope: model.py, config.yaml
Verify: python train.py --eval 2>&1 | grep 'accuracy' | awk '{print $2}'

# What happens internally at each iteration:

# Iteration 3 — Agent reads git memory:
$ git log --oneline -5
# c3d4e5f experiment(model): increase hidden layers from 2 to 4 — KEPT
# Revert "experiment(model): switch optimizer to SGD"
# a1b2c3d experiment(model): add dropout 0.3 — KEPT
# 0000000 baseline — accuracy 85%

# Agent's decision process (informed by git memory):
# ✓ "increase hidden layers" KEPT → try variant: increase to 6 layers
# ✗ "switch to SGD" REVERTED → avoid optimizer changes
# ✓ "add dropout" KEPT → dropout works, try adjusting rate
# → Decision: increase hidden layers from 4 to 6 (exploiting success pattern)

# Agent modifies model.py, commits:
$ git commit -m "experiment(model): increase hidden layers from 4 to 6"
# Verify: accuracy = 91.2% (+2.1%) → KEEP

# Next iteration reads updated memory, sees 3 successful layer changes...
```

## Phase 2: Ideate (Strategic)

Pick the NEXT change. **MUST consult git history and results log before deciding.**

**How to use git as memory:**
- Run `git log --oneline -10` — read commit messages to see what was tried
- For each "keep" in results log, run `git show <commit-hash> --stat` to see what files/patterns worked
- For discarded approaches, read the commit message to understand what was attempted and avoid repeating it
- Look for patterns: if 3 commits improved metric by touching file X, focus on file X

**Priority order:**

1. **Fix crashes/failures** from previous iteration first
2. **Exploit successes** — run `git diff` on last kept commit, try variants in same direction
3. **Explore new approaches** — cross-reference results log AND git history to find untried approaches
4. **Combine near-misses** — two changes that individually didn't help might work together
5. **Simplify** — remove code while maintaining metric. Simpler = better
6. **Radical experiments** — when incremental changes stall, try something dramatically different

**Anti-patterns:**
- Don't repeat exact same change that was already discarded — CHECK git log first
- Don't make multiple unrelated changes at once (can't attribute improvement)
- Don't chase marginal gains with ugly complexity
- Don't ignore git history — it's the primary learning mechanism between iterations

**Bounded mode consideration:** If remaining iterations are limited (<3 left), prioritize exploiting successes over exploration.

## Phase 3: Modify (One Atomic Change)

- Make ONE focused change to in-scope files
- The change should be explainable in one sentence
- Write the description BEFORE making the change (forces clarity)

### Multi-File Atomic Changes

One logical change may span multiple files. This is still ONE change if it serves a single purpose.

**The one-sentence test:** If you need "and" to describe it, it's two changes. Split them.

| One Change (OK) | Two Changes (Split) |
|-----------------|---------------------|
| Change port 3000→8080 in Dockerfile + compose + nginx | Change port AND add new service |
| Update Node 18→20 in Dockerfile + CI + package.json | Update Node AND switch to pnpm |
| Add Redis in compose + app config + env vars | Add Redis AND refactor auth module |

#### DevOps Example

```bash
# Iteration 1: Enable Docker layer caching (2 files, one intent)
git add Dockerfile .github/workflows/ci.yml
git commit -m "experiment(ci): enable Docker layer caching"
# ✓ One change: "enable caching" — same intent across files

# Iteration 2: Parallelize test jobs (1 file)
git add .github/workflows/ci.yml
git commit -m "experiment(ci): parallelize tests with matrix strategy"
# ✓ One change: "parallelize tests"
```

### Enforcing Atomicity — Self-Check

```bash
# After modifying but before committing, validate atomicity:
FILES_CHANGED=$(git diff --name-only | wc -l)

# Heuristic: >5 files likely means multiple changes — review
if [ "$FILES_CHANGED" -gt 5 ]; then
  echo "WARN: ${FILES_CHANGED} files changed — verify single intent"
fi

# The one-sentence test: describe the change in ONE sentence
# If you need "and", split into separate iterations
```

### Atomicity Configuration

Configure how strictly the agent enforces the one-change-per-iteration rule:

```
/autoresearch
Goal: Optimize API response time
Scope: src/api/**/*.ts
Verify: wrk -t2 -c10 -d10s http://localhost:3000 | grep 'Avg Lat' | awk '{print $2}'
Atomicity: strict       # enforce one-change rule (default)
Max-Files-Per-Change: 3  # alert if >3 files modified in one iteration
```

**Atomicity levels:**

| Level | Behavior | When to Use |
|-------|----------|-------------|
| `strict` (default) | Agent MUST make exactly one logical change per iteration. Self-check validates before commit. If >5 files changed, agent re-evaluates and splits if needed. | Most optimization tasks |
| `relaxed` | Agent can make coordinated multi-file changes as one unit. No file count warnings. Still requires one-sentence description test. | Infrastructure/config changes spanning many files |

**How the agent enforces atomicity at Phase 3:**

```bash
# Step 1: Before making any change, write the description
DESCRIPTION="add response caching to /api/users endpoint"
# Test: Can this be said in ONE sentence without "and"? → Yes ✓

# Step 2: Make the change (modify files)
# ... edit src/api/users.ts ...

# Step 3: Validate atomicity before committing
FILES_CHANGED=$(git diff --name-only | wc -l | tr -d ' ')
LINES_CHANGED=$(git diff --stat | tail -1 | grep -oP '\d+ insertion' | grep -oP '\d+' || echo 0)

if [ "$FILES_CHANGED" -gt "${MAX_FILES:-5}" ]; then
  echo "⚠ ATOMICITY CHECK: ${FILES_CHANGED} files changed"
  echo "  Review: is this truly ONE logical change?"
  echo "  If not, split into separate iterations"
  # Agent re-evaluates and may undo partial changes
fi

# Step 4: Verify the one-sentence test passes
echo "Change: ${DESCRIPTION}"
# If description contains "and" linking unrelated actions → SPLIT
echo "$DESCRIPTION" | grep -qE '\band\b.*\b(add|remove|change|update|fix)\b' && \
  echo "⚠ Description contains 'and' with multiple actions — consider splitting"

# Step 5: Commit only if atomicity validated
git add <specific-files>
git commit -m "experiment(api): ${DESCRIPTION}"
```

**Examples of atomicity enforcement:**

```
# ✓ ATOMIC — passes all checks:
Description: "add response caching to /api/users"
Files changed: 1 (src/api/users.ts)
→ Commit proceeds

# ✓ ATOMIC — multi-file but single intent:
Description: "add Redis caching layer"
Files changed: 3 (docker-compose.yml, src/cache.ts, src/api/users.ts)
→ Same intent across files, commit proceeds

# ✗ NOT ATOMIC — fails one-sentence test:
Description: "add caching AND refactor error handling"
→ Contains "and" linking unrelated actions
→ Split into: iteration N = "add caching", iteration N+1 = "refactor error handling"

# ✗ NOT ATOMIC — too many unrelated files:
Description: "optimize performance"
Files changed: 12 (across api, db, frontend, config)
→ Too broad — split into focused iterations
```

## Phase 4: Commit (Before Verification)

**You MUST commit before running verification.** This enables clean rollback if the experiment fails.

```bash
# Stage ONLY in-scope files (safer than git add -A)
# List the specific files you modified and add them individually:
git add <file1> <file2> ...
# AVOID git add -A — it stages ALL files including .env, node_modules, and user's unrelated work

# Check if there's actually something to commit
git diff --cached --quiet
# → If exit code 0 (no staged changes): skip commit, log as "no-op", go to next iteration
# → If exit code 1 (changes exist): proceed with commit

# Commit with descriptive experiment message
git commit -m "experiment(<scope>): <one-sentence description of what you changed and why>"
```

**"Nothing to commit" handling:** If `git add <files>` followed by `git diff --cached --quiet` shows no changes, the modification phase produced no actual diff. This is NOT a crash — log as `status=no-op` with description of what was attempted, skip verification, and proceed to next iteration. Do NOT create an empty commit.

**WARNING:** NEVER use `git add -A` — it stages ALL files including .env, credentials, and user's unrelated work. Always use `git add <file1> <file2> ...` with explicit file paths. After staging, verify with `git diff --cached --name-only` that only in-scope files are staged.

**Commit message format:** Use conventional commit format with `experiment` type: `experiment(<scope>): <description>`. This keeps compatibility with commit-lint while clearly marking autoresearch iterations. Example: `experiment(auth): increase timeout from 5s to 30s — hypothesis: reduces flaky test failures`.

**Hook failure handling:** If a pre-commit hook blocks the commit:
1. Read the hook's error output to understand WHY it blocked
2. If fixable (lint error, formatting): fix the issue, re-stage, and retry the commit — do NOT use `--no-verify`
3. If not fixable within 2 attempts: log as `status=hook-blocked`, revert the in-scope file changes (`git checkout -- <files>`), and move to next iteration
4. NEVER bypass hooks with `--no-verify` — hooks exist to protect code quality

**Rollback strategy (if experiment fails):**
```bash
# Preferred: git revert (safe, preserves history)
git revert HEAD --no-edit

# Alternative: git reset (if revert conflicts)
git revert --abort && git reset --hard HEAD~1
```

**IMPORTANT:** Prefer `git revert` over `git reset --hard` — revert preserves the experiment in history (so you can learn from it), while reset destroys it. Use `git reset --hard` only if revert produces merge conflicts.

**Phase 4 safety:** If `git commit` itself fails for any reason (disk full, hook timeout, permissions), clean up staged changes before moving on:

```bash
git reset HEAD -- .   # unstage everything
git checkout -- <in-scope files>   # restore files to last committed state
# Log as status=crash, continue to next iteration
```

## Phase 5: Verify (Mechanical Only)

Run the agreed-upon verification command. Capture output.

**Timeout rule:** If verification exceeds 2x normal time, kill and treat as crash.

**Extract metric:** Parse the verification output for the specific metric number.

**Metric validation (MANDATORY after extraction):**

The extracted value MUST be a valid number before ANY decision logic runs. A non-numeric value means the verify pipeline is broken — the agent must not guess, interpolate, or treat it as zero.

```
extracted_value = <result of verify pipeline>

# Strip leading/trailing whitespace and newlines before validation
extracted_value = strip(extracted_value)

# Validate: must match a number (integer or float, optional leading minus)
IF extracted_value does NOT match pattern: ^-?[0-9]+\.?[0-9]*$
    STATUS = "metric-error"
    LOG iteration as:
      status=metric-error
      description="Metric extraction returned non-numeric value: '{extracted_value}'"
    safe_revert()

    # Diagnose: show the raw verify output so the problem is visible
    PRINT "⚠ Metric extraction failed — got '{extracted_value}' instead of a number"
    PRINT "Raw verify output (last 5 lines):"
    PRINT <tail -5 of verify command output>
    PRINT "Check your Verify command pipeline — the final output must be a single number"

    # If this is the 2nd consecutive metric-error, the verify command is broken.
    # Do NOT keep iterating with a broken pipeline.
    IF previous_iteration.status == "metric-error":
        PRINT "✗ Two consecutive metric extraction failures — verify command is broken. Stopping."
        STOP (even in unbounded mode)

    # Otherwise, proceed to next iteration (a transient failure is possible
    # if the codebase is in a state where the verify command can't run cleanly)
    CONTINUE to next iteration
```

**Valid statuses** now include `metric-error` alongside `keep`, `discard`, `crash`, `no-op`, `hook-blocked`.

### Verification Command Templates by Language

| Language | Verify Command | Metric | Direction |
|----------|---------------|--------|-----------|
| **Node.js** | `npx jest --coverage 2>&1 \| grep 'All files' \| awk '{print $4}'` | Coverage % | higher |
| **Python** | `pytest --cov=src --cov-report=term 2>&1 \| grep TOTAL \| awk '{print $4}'` | Coverage % | higher |
| **Rust** | `cargo test 2>&1 \| grep -oP '\d+ passed' \| grep -oP '\d+'` | Tests passed | higher |
| **Go** | `go test -count=1 ./... 2>&1 \| grep -c '^ok'` | Packages passing | higher |
| **Java** | `mvn test 2>&1 \| grep 'Tests run:' \| tail -1 \| grep -oP 'Failures: \d+' \| grep -oP '\d+'` | Failures | lower |
| **Bundle** | `npx esbuild src/index.ts --bundle --minify \| wc -c` | Bytes | lower |
| **Lighthouse** | `npx lighthouse http://localhost:3000 --output=json \| jq '.categories.performance.score * 100'` | Score 0-100 | higher |
| **Latency** | `wrk -t2 -c10 -d10s http://localhost:3000/api 2>&1 \| grep 'Avg Lat' \| awk '{print $2}'` | ms | lower |

## Phase 5.1: Noise Handling (for Volatile Metrics)

Some metrics are inherently noisy — benchmark times, ML accuracy, Lighthouse scores. A single measurement can mislead. Use these strategies to prevent false keep/discard decisions.

### Strategy 1: Multi-Run Verification

Run verify N times and use the median to filter outliers:

```bash
# Single run (unreliable for noisy metrics):
npm run benchmark  # might report 142ms or 158ms randomly

# Multi-run with median (reliable):
for i in 1 2 3; do
  npm run benchmark 2>&1 | grep 'avg' | awk '{print $2}'
done | sort -n | sed -n '2p'  # median of 3 runs
```

Configure via inline config:
```
/autoresearch
Verify: npm run benchmark 2>&1 | grep 'avg' | awk '{print $2}'
Noise: high           # triggers 3-run median automatically
Noise-Runs: 5         # custom: 5 runs instead of default 3
```

### Strategy 2: Minimum Improvement Threshold

Ignore improvements smaller than the noise floor:

```
# Configuration:
Min-Delta: 2.0   # only keep if improvement > 2%

# Decision logic (extends Phase 6):
IF metric_improved AND delta > min_delta:
    STATUS = "keep"
ELIF metric_improved AND delta <= min_delta:
    STATUS = "discard"
    LOG "NOISE: delta {delta} below threshold {min_delta}"
```

### Strategy 3: Confirmation Run

Re-verify before making a final keep decision:

```
IF metric_improved:
    second_metric = run_verify()  # run verify again
    IF abs(second_metric - first_metric) / first_metric < 0.01:
        STATUS = "keep"     # confirmed — both runs agree
    ELSE:
        STATUS = "discard"  # first result was noise
        LOG "NOISE: confirmation run disagreed"
```

### Strategy 4: Environment Pinning

Reduce noise at the source by controlling external factors:

```bash
# Pin random seeds for ML/statistical workloads
PYTHONHASHSEED=42 python train.py --seed 42

# Use deterministic test ordering
pytest -p no:randomly

# Flush caches before benchmarking
redis-cli FLUSHALL 2>/dev/null; npm run benchmark

# Warm up before timing (eliminates JIT/cold-start noise)
node server.js &
sleep 2
wrk -t1 -c1 -d3s http://localhost:3000  # warm-up (discard)
wrk -t2 -c10 -d10s http://localhost:3000  # actual measurement
```

### When to Use Each Strategy

| Metric Type | Noise Level | Strategy |
|-------------|-------------|----------|
| Test coverage (%) | None | No special handling |
| Bundle size (bytes) | None | No special handling |
| Benchmark time (ms) | Medium | Multi-run median (3 runs) |
| Lighthouse score | Medium | Multi-run median (5 runs) |
| ML training loss | High | Environment pinning + confirmation run |
| API response time | High | Warm-up + multi-run + min-delta |

### Preventing Premature Rollbacks

When a metric seems worse but could be noise:

```
IF metric_worse AND abs(delta) < noise_floor:
    second_result = run_verify()  # confirm the regression
    IF second_result also worse:
        STATUS = "discard"    # confirmed regression — revert
    ELSE:
        STATUS = "keep"       # first measurement was noise — keep the change
        LOG "NOISE: initial regression not confirmed on re-run"
```

## Phase 5.5: Guard (Regression Check)

If a **guard** command was defined during setup, run it after verification.

The guard protects existing functionality while the main metric is being optimized. It operates in one of two modes:

**Pass/fail mode (default):** Guard is a command that must exit 0. Common examples: `npm test`, `npm run typecheck`, `pytest`, `cargo test`.

**Metric-valued mode:** Guard extracts a number (like the verify command) and checks it against a regression threshold. Use this when you need tolerance, not a binary tripwire. Example: "bundle size can grow up to 5% from baseline, but no more."

```
# Pass/fail guard (default):
Guard: npm test

# Metric-valued guard:
Guard: npx esbuild src/index.ts --bundle --minify | wc -c
Guard-Direction: lower is better
Guard-Threshold: 5%
```

**Key distinction:**
- **Verify** answers: "Did the metric improve?" (the goal)
- **Guard** answers: "Did anything else break?" (the safety net)

**Guard rules (both modes):**
- Only run if a guard was defined (it's optional)
- Run AFTER verify — no point checking guard if the metric didn't improve
- If guard fails, revert the optimization and try to rework it (max 2 attempts)
- NEVER modify guard/test files — always adapt the implementation instead
- Log guard failures distinctly so the agent can learn what kinds of changes cause regressions

**Pass/fail mode rules:**
- Exit code 0 = pass. Non-zero = fail.

**Metric-valued mode rules:**
- Extract the guard-metric using the same numeric validation as the primary metric (must match `^-?[0-9]+\.?[0-9]*$`)
- If guard-metric extraction fails, treat as guard failure (not metric-error)
- Compare against baseline using the threshold:
  ```
  IF Guard-Direction is "lower is better":
      guard_passed = (guard_metric <= guard_baseline * (1 + threshold/100))
      # Example: baseline 50000 bytes, threshold 5% → pass if <= 52500
  IF Guard-Direction is "higher is better":
      guard_passed = (guard_metric >= guard_baseline * (1 - threshold/100))
      # Example: baseline 95% coverage, threshold 5% → pass if >= 90.25%
  ```
- `Guard-Threshold: 0%` means strict no-regression: the guard-metric must not worsen at all from baseline.

**Guard failure recovery (max 2 rework attempts):**

When the guard fails but the metric improved, the optimization idea may still be viable — it just needs a different implementation that doesn't break behavior:

1. Revert the change (use `safe_revert()` — try `git revert HEAD --no-edit`, fallback to `git reset --hard HEAD~1` if conflicts)
2. Read the guard output to understand WHAT broke (which tests, which assertions)
3. Rework the optimization to avoid the regression — e.g.:
   - If inlining a function broke callers → try a different optimization angle
   - If changing a data structure broke serialization → preserve the interface
   - If reordering logic broke edge cases → add the optimization more surgically
4. Commit the reworked version, re-run verify + guard
5. If both pass → keep. If guard fails again → one more attempt, then give up

**Critical:** Guard/test files are read-only. The optimization must adapt to the tests, never the other way around. If after 2 rework attempts the optimization can't pass the guard, discard it and move on to a different idea.

## Phase 6: Decide (No Ambiguity)

```bash
# Rollback function — used for all discard/crash decisions
safe_revert() {
  echo "Reverting: $(git log --oneline -1)"

  # Attempt 1: git revert (preserves history — preferred)
  if git revert HEAD --no-edit 2>/dev/null; then
    echo "✓ Reverted via git revert (experiment preserved in history for learning)"
    return 0
  fi

  # Attempt 2: revert conflicted — fallback to reset
  git revert --abort 2>/dev/null
  echo "⚠ Revert conflicted — using git reset --hard HEAD~1"
  git reset --hard HEAD~1
  echo "✓ Reverted via reset (experiment removed from history)"
  return 0
}

# Usage in Phase 6 decision logic:
# if STATUS == "discard" or STATUS == "crash": safe_revert
```

```
IF metric_improved AND (no guard OR guard_passed):
    STATUS = "keep"
    # Do nothing — commit stays. Git history preserves this success.
ELIF metric_improved AND guard_failed:
    safe_revert()
    # Rework the optimization (max 2 attempts)
    FOR attempt IN 1..2:
        Analyze guard output → rework implementation (NOT tests)
        git add <modified-files> && git commit -m "experiment(<scope>): rework — <description>"
        Re-run verify
        IF metric_improved:
            Re-run guard
            IF guard_passed:
                STATUS = "keep (reworked)"
                BREAK
        safe_revert()
    IF still failing after 2 attempts:
        STATUS = "discard"
        REASON = "guard failed, could not rework optimization"
ELIF metric_same_or_worse:
    STATUS = "discard"
    safe_revert()
ELIF crashed:
    # Attempt fix (max 3 tries)
    IF fixable:
        Fix → re-commit → re-verify → re-guard
    ELSE:
        STATUS = "crash"
        safe_revert()
```

**Why `git revert` instead of `git reset --hard`?**
- `git revert` preserves the failed experiment in history — this IS the "memory." Future iterations can read `git log` and see what was tried and failed.
- `git reset --hard` destroys the commit entirely — the agent loses memory of what was attempted.
- `git revert` is also safer in Claude Code — it's a non-destructive operation that doesn't trigger safety warnings.
- Fallback: if `git revert` produces merge conflicts, use `git revert --abort` then `git reset --hard HEAD~1`.

## Phase 7: Log Results

Append to results log (TSV format):

```
iteration  commit   metric   status        description
42         a1b2c3d  0.9821   keep          increase attention heads from 8 to 12
43         -        0.9845   discard       switch optimizer to SGD
44         -        0.0000   crash         double batch size (OOM)
45         -        -        no-op         attempted to modify read-only config (no diff produced)
46         -        -        hook-blocked  pre-commit lint hook rejected formatting in model.py
```

**Valid statuses:** `keep`, `keep (reworked)`, `discard`, `crash`, `no-op`, `hook-blocked`, `metric-error`

## Phase 8: Repeat

### Unbounded Mode (default)

Go to Phase 1. **Do not ask "should I keep going?" — keep iterating unless a halt condition fires** (see Plateau Detection below).

### Bounded Mode (with Iterations: N)

```
IF current_iteration < max_iterations:
    Go to Phase 1
ELIF goal_achieved:
    Print: "Goal achieved at iteration {N}! Final metric: {value}"
    Print final summary
    STOP
ELSE:
    Print final summary
    STOP
```

**Final summary format:**
```
=== Autoresearch Complete (N/N iterations) ===
Baseline: {baseline} → Final: {current} ({delta})
Keeps: X | Discards: Y | Crashes: Z | Skipped: W (no-ops + hook-blocked)
Best iteration: #{n} — {description}
```

### When Stuck (>5 consecutive discards)

Applies to both modes:
1. Re-read ALL in-scope files from scratch
2. Re-read the original goal/direction
3. Review entire results log for patterns
4. Try combining 2-3 previously successful changes
5. Try the OPPOSITE of what hasn't been working
6. Try a radical architectural change

### Plateau Detection (unbounded mode)

"Stuck" catches consecutive discards, but a subtler failure mode exists: the agent keeps iterating, occasionally getting a `keep`, yet the *best* metric never actually improves. The loop burns tokens without making real progress.

Track two values across iterations:

```
best_metric       = baseline metric from iteration 0
best_iteration    = 0
iterations_since_best = 0
plateau_patience  = 15  (default, configurable via Plateau-Patience: N)
```

Update after every iteration where a valid metric was extracted:

```
IF new_metric is better than best_metric (respecting Direction):
    best_metric = new_metric
    best_iteration = current_iteration
    iterations_since_best = 0
ELSE:
    iterations_since_best += 1
```

Skip iterations with no valid metric (`no-op`, `metric-error`, `hook-blocked`, `crash`) — they don't count toward the patience window because the agent didn't get a real signal.

**When `iterations_since_best >= plateau_patience`:**

```
PRINT "⚠ Plateau detected — best metric has not improved in {plateau_patience} iterations"
PRINT "  Best: {best_metric} (iteration #{best_iteration})"
PRINT "  Current: {current_metric}"
PRINT "  Last {plateau_patience} iterations: {keeps} keeps, {discards} discards — no net gain"

AskUserQuestion:
  question: "The metric has plateaued. How do you want to proceed?"
  header: "Plateau Detected"
  options:
    - label: "Stop here"
      description: "End the loop. Best metric: {best_metric} at iteration #{best_iteration}"
    - label: "Continue with reset patience"
      description: "Keep going for another {plateau_patience} iterations before checking again"
    - label: "Change strategy"
      description: "I'll adjust the goal, scope, or verify command"
```

**Configuration:**

```
/autoresearch
Goal: Reduce bundle size below 200KB
Verify: npx esbuild src/index.ts --bundle --minify | wc -c
Plateau-Patience: 20    # check after 20 iterations without improvement (default: 15)
```

Set `Plateau-Patience: off` to disable plateau detection entirely and restore the original unbounded behavior. Use this for overnight runs where you accept the token cost.

**Bounded mode:** Plateau detection is disabled. The iteration limit already bounds the run, and the agent should use all N iterations to explore.

## Crash Recovery

### Within an iteration (verify command failures)

- Syntax error → fix immediately, don't count as separate iteration
- Runtime error → attempt fix (max 3 tries), then move on
- Resource exhaustion (OOM) → revert, try smaller variant
- Infinite loop/hang → kill after timeout, revert, avoid that approach
- External dependency failure → skip, log, try different approach

### Session crash (agent itself dies mid-iteration)

If the agent crashes (API timeout, context window exhaustion, user kills the process), the working tree may be in a partially modified state. On the next invocation, Phase 0 precondition checks will detect this. Here's how to recover depending on what state git is in:

**Detect state:**

```bash
# 1. Uncommitted changes in working tree?
DIRTY=$(git status --porcelain)

# 2. Last commit is an unverified experiment?
LAST_MSG=$(git log --oneline -1)
# If it starts with "experiment(" and there's no corresponding results log entry,
# the agent crashed after commit but before verify/decide.
```

**Recovery rules:**

```
IF working tree is dirty (changes not yet committed):
    # Agent crashed during Phase 3 (modify) — before commit
    # These changes were never verified. Discard them.
    git checkout -- <in-scope files>
    LOG "Recovered from session crash: discarded uncommitted modifications"
    Resume loop from Phase 1

IF last commit is "experiment(...)" with no matching results log entry:
    # Agent crashed after Phase 4 (commit) but before Phase 6 (decide)
    # The experiment was never verified. Revert it.
    safe_revert()
    LOG "Recovered from session crash: reverted unverified experiment"
    Resume loop from Phase 1

IF working tree is clean AND last commit has a results log entry:
    # Agent crashed after Phase 7 (log) — clean state
    # Nothing to recover. Resume normally.
    Resume loop from Phase 1
```

## Communication

- **DO NOT** ask "should I keep going?" — in unbounded mode, keep iterating unless a halt condition fires (plateau detection, two consecutive metric-errors). In bounded mode, continue until N is reached.
- **DO NOT** summarize after each iteration — just log and continue
- **DO** print a brief one-line status every ~5 iterations (e.g., "Iteration 25: metric at 0.95, 8 keeps / 17 discards")
- **DO** alert if you discover something surprising or game-changing
- **DO** print a final summary when bounded loop completes
