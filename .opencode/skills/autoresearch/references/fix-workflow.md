# Fix Workflow — /autoresearch_fix

Autonomous fix loop that takes a broken state and iteratively repairs it until everything passes. One fix per iteration. Atomic, committed, verified, auto-reverted on failure.

**Core idea:** Detect → Prioritize → Fix ONE thing → Verify → Keep/Revert → Repeat until zero errors.

## Trigger

- User invokes `/autoresearch_fix`
- User says "fix all errors", "make tests pass", "fix the build", "clean up all warnings"
- User has output from `/autoresearch_debug` and wants to fix the findings

## Loop Support

```
# Unlimited — keep fixing until everything passes
/autoresearch_fix

# Bounded — exactly N fix iterations
/autoresearch_fix
Iterations: 30

# With explicit target
/autoresearch_fix
Target: make all tests pass
Scope: src/**/*.ts
Guard: npm run typecheck
```

## PREREQUISITE: Interactive Setup (when invoked without flags)

**CRITICAL — BLOCKING PREREQUISITE:** If `/autoresearch_fix` is invoked without explicit `--target`, `--guard`, or `--scope`, you MUST first auto-detect all failures, then use `question` to gather user input BEFORE proceeding to ANY phase. DO NOT skip this step. DO NOT jump to Phase 1 without completing interactive setup.

**Pre-scan:** Run test suite, type checker, linter, and build to detect failures. Present summary in the first question.

**Single batched call — all 4 questions at once:**

You MUST call `question` with all 4 questions in ONE call:

| # | Header | Question | Options (from auto-detection) |
|---|--------|----------|-------------------------------|
| 1 | `Fix What` | "Found [N] test failures, [M] type errors, [K] lint errors. What should I fix?" | "Fix everything (recommended)", "Only tests", "Only type errors", "Only lint" |
| 2 | `Guard` | "What command must ALWAYS pass? (prevents fixes from breaking other things)" | "npm test", "tsc --noEmit", "npm run build", "Skip — no guard" |
| 3 | `Scope` | "Which files can I modify?" | Suggested globs from error locations + "All project files" |
| 4 | `Launch` | "Ready to fix?" | "Fix until zero errors", "Fix with iteration limit", "Edit config", "Cancel" |

**IMPORTANT:** Always ask all 4 questions in a single call — never one at a time. Users need the full picture (what's broken, what's the guard, what's the scope) to make informed decisions together.

If the user provides `--target`, `--guard`, `--scope`, or `--from-debug` flags, skip the interactive setup and proceed directly to Phase 1.

## Architecture

```
/autoresearch_fix
  ├── Phase 1: Detect (what's broken?)
  ├── Phase 2: Prioritize (fix order)
  ├── Phase 3: Fix ONE thing (atomic change)
  ├── Phase 4: Commit (before verification)
  ├── Phase 5: Verify (did error count decrease?)
  ├── Phase 6: Guard (did anything else break?)
  ├── Phase 7: Decide (keep / revert / rework)
  └── Phase 8: Log & Repeat
```

## Phase 1: Detect — What's Broken?

**STOP: Have you completed the Interactive Setup above?** If invoked without `--target`/`--guard`/`--scope` flags, you MUST complete the `question` call above BEFORE entering this phase.

Auto-detect the failure domain from context, or accept explicit target.

**Detection algorithm:**
```
FUNCTION detectFailures(context):
  failures = []

  # Run test suite
  IF test runner detected (jest, pytest, vitest, go test, cargo test):
    result = run_tests()
    IF failures → ADD {type: "test", count: N, details: [...]}

  # Run type checker
  IF typescript detected:
    result = run("tsc --noEmit")
    IF errors → ADD {type: "type", count: N, details: [...]}

  # Run linter
  IF linter detected (eslint, ruff, clippy):
    result = run_lint()
    IF errors → ADD {type: "lint", count: N, details: [...]}

  # Run build
  IF build script detected:
    result = run_build()
    IF fails → ADD {type: "build", count: 1, details: [...]}

  # Check for debug findings
  IF debug/{latest}/findings.md exists:
    bugs = parse_findings()
    ADD {type: "bug", count: N, details: [...]}

  # Check CI
  IF .github/workflows/ exists:
    IF user mentions CI failure → ADD {type: "ci", count: 1, details: [...]}

  # Detect warnings (lower priority but tracked)
  IF warning-level output detected:
    result = run_warnings()
    IF warnings → ADD {type: "warning", count: N, details: [...]}

  RETURN failures sorted by severity
```

**Output:** `✓ Phase 1: Detected — [N] test failures, [M] type errors, [K] lint errors, [W] warnings`

**Detection priority note:** Run build first — if build fails, type/test/lint results are unreliable. Warnings are detected last; {type: "warning"} items go to lowest priority queue.

## Phase 2: Prioritize — Fix Order

Fix in this order (blockers first, polish last):

| Priority | Category | Why First |
|----------|----------|-----------|
| 1 | **Build failures** | Nothing works if it doesn't compile |
| 2 | **Critical/High bugs** | From debug findings — data loss, security |
| 3 | **Type errors** | Type safety prevents cascading bugs |
| 4 | **Test failures** | Tests verify correctness |
| 5 | **Medium/Low bugs** | From debug findings |
| 6 | **Lint errors** | Code quality |
| 7 | **Warnings** | Polish — type "warning" in detection |

**Within a category, prioritize by:**
1. Cascading impact (fixing one may fix others downstream)
2. Simplicity (quick wins first — build momentum)
3. File locality (fixes in same file grouped)

**Output:** `✓ Phase 2: Prioritized — fixing [category] first ([N] items)`

## Phase 3: Fix ONE Thing — Atomic Change

Pick the highest-priority unfixed item and make ONE focused change.

**Fix strategies by category:**

| Category | Strategy |
|----------|----------|
| Build failure | Read error, fix the exact line/import/config |
| Type error | Add proper types, fix signatures, handle null cases |
| Test failure | Read test + implementation, find mismatch, fix implementation (not test) |
| Lint error | Apply the rule — auto-fix where possible |
| Bug (from debug) | Apply the suggested fix from findings.md |
| Warning | Resolve the underlying issue, don't suppress |

**Fix Strategies by Language:**

| Language | Never Do | Correct Pattern |
|----------|----------|-----------------|
| TypeScript | `any`, `@ts-ignore`, type assertions to bypass | Proper interfaces, generics, discriminated unions |
| Python | Bare `except:`, missing type hints on public API | `except SpecificError:`, full type hints with `from __future__ import annotations` |
| Go | Ignoring errors with `_`, `panic` in library code | Explicit error wrapping `fmt.Errorf("context: %w", err)`, propagate with context |
| Rust | `.unwrap()` in production, silencing `#[allow(unused)]` | `Result<T, E>` propagation with `?`, custom error types with `thiserror` |
| Java | Swallowing exceptions, raw types | Typed exceptions, generics, checked exception handling |

**Rules:**
- ONE fix per iteration. Not two. Not "while I'm here."
- Fix the IMPLEMENTATION, not the test (unless the test is genuinely wrong)
- Never add `@ts-ignore`, `eslint-disable`, `# type: ignore` to suppress errors
- Never use any|any escape hatch never solves type errors — use proper narrowed types or generics
- Never delete test|delete test coverage never improves code — fix the implementation to satisfy tests
- Prefer minimal changes — smallest diff that fixes the issue

## Phase 4: Commit — Before Verification

```bash
git add <modified-files>
git commit -m "fix: [what was fixed] — [file:line]"
```

Commit BEFORE running verification. This enables clean rollback if the fix breaks something.

## Phase 5: Verify — Did It Help?

Re-run the detection from Phase 1 and compare:

```
previous_errors = error_count_before
current_errors = error_count_after

delta = previous_errors - current_errors
```

**Expected:** `delta > 0` (fewer errors than before)

## Phase 6: Guard — Did Anything Else Break?

If a guard command is specified, run it:

```
guard_result = run(guard_command)  # e.g., "npm test"
```

**Guard prevents regressions.** Fixing a type error shouldn't break a test. Fixing a test shouldn't break the build.

## Phase 7: Decide — Keep, Revert, or Rework

| Condition | Action |
|-----------|--------|
| `delta > 0` AND guard passes | **KEEP** — commit stays, log "fixed" |
| `delta > 0` AND guard fails | **REWORK** — revert, try different approach (max 2 attempts) |
| `delta == 0` | **DISCARD** — revert, fix didn't help |
| `delta < 0` (more errors!) | **DISCARD** — revert immediately |
| Crash during fix | **RECOVER** — revert, try simpler approach (max 3 attempts) |

**Rework strategy (when guard fails):**
1. Read the guard failure — understand what regressed
2. Revert the failing fix: `git revert HEAD --no-edit`
3. Understand why the fix broke something else (check cascading dependencies)
4. Find an approach that fixes the target WITHOUT breaking the guard
5. If 2 rework attempts fail → skip this item, add to `blocked.md`, move to next
6. Log in fix-results.tsv with status "rework" and description of what was attempted

**Decision matrix extended:**

| Condition | delta | Guard | Action | TSV Status |
|-----------|-------|-------|--------|-----------|
| Perfect fix | > 0 | pass | KEEP | fixed |
| Partial fix | > 0 | pass | KEEP + continue | fixed |
| Regression introduced | > 0 | fail | REWORK | rework |
| No effect | == 0 | - | DISCARD | discard |
| Made it worse | < 0 | - | DISCARD immediately | discard |
| Crash/exception | any | fail | RECOVER (simpler) | recover |
| 3rd attempt fails | any | any | SKIP to blocked | blocked |

## Phase 8: Log & Repeat

**Append to fix-results.tsv:**
```tsv
iteration	category	target	delta	guard	status	description
0	-	-	-	pass	baseline	47 test failures, 12 type errors, 3 lint errors
1	type	auth.ts:42	-2	pass	fixed	add return type annotation
2	type	db.ts:15	-1	pass	fixed	handle nullable column
3	test	api.test.ts	-3	pass	fixed	fix expected status code (was 200, should be 201)
4	test	auth.test.ts	0	-	discard	wrong approach — test expectation was correct
5	test	auth.test.ts	-1	pass	fixed	missing await on async handler
```

**Every 5 iterations, print progress:**
```
=== Fix Progress (iteration 15) ===
Baseline: 62 errors → Current: 23 errors (-39, -63%)
Category breakdown:
  Tests:  31/47 fixed
  Types:  8/12 fixed
  Lint:   0/3 fixed (not yet started — lower priority)
Keeps: 11 | Discards: 3 | Reworks: 1
```

**Completion detection:**
```
IF current_errors == 0:
  PRINT "=== All Clear — Zero Errors ==="
  STOP (even in unbounded mode)
```

## Flags

| Flag | Purpose |
|------|---------|
| `--target <command>` | Explicit verify command (overrides auto-detection) |
| `--guard <command>` | Safety command that must always pass |
| `--scope <glob>` | Limit fixes to specific files |
| `--category <type>` | Only fix specific category (test, type, lint, build, bug) |
| `--skip-lint` | Don't fix lint errors (focus on functional issues) |
| `--from-debug` | Read findings from latest debug/ session |
| `--chain <targets>` | Chain to downstream tool(s) after completion. Comma-separated for multi-chain. Spaces after commas tolerated. |

## Fix Session State Machine

```
States: DETECTING → PRIORITIZING → FIXING → VERIFYING → DECIDING → [DONE | LOOP]

DETECTING:
  → Run all error detection commands
  → If zero errors found → DONE (nothing to fix)
  → If errors found → PRIORITIZING

PRIORITIZING:
  → Sort errors by priority table
  → Group cascading errors (fixing one fixes others)
  → Pick first unfixed item → FIXING

FIXING:
  → Read error details + surrounding code
  → Assess blast radius (impact assessment)
  → Check git history for prior attempts on this file
  → Apply minimal change
  → Commit → VERIFYING

VERIFYING:
  → Re-run error detection
  → Compute delta (previous - current)
  → Run guard command → DECIDING

DECIDING:
  → delta > 0 AND guard passes → KEEP → log "fixed" → LOOP
  → delta > 0 AND guard fails → REWORK (max 2) → FIXING
  → delta == 0 → DISCARD → revert → PRIORITIZING (next item)
  → delta < 0 → DISCARD → revert immediately → PRIORITIZING
  → 3 failed attempts on same item → SKIP → blocked list → PRIORITIZING
  → All items fixed or skipped → DONE

DONE:
  → Generate summary.md
  → Print fix_score
  → Suggest /autoresearch_debug for blocked items
```

## What NOT to Do — Anti-Patterns

These shortcuts seem to fix the error but make things worse:

| Anti-Pattern | Why It's Wrong | Do This Instead |
|--------------|----------------|-----------------|
| Add `@ts-ignore` / `eslint-disable` | Hides the problem — resurfaces as runtime error | Fix the root cause |
| Use `any` type to silence TypeScript | Defeats type safety for the whole chain | Use proper types, generics, or `unknown` with narrowing |
| Delete or skip failing tests | Removes the safety net | Fix the implementation to satisfy the test |
| Suppress lint with inline comments | Accumulates tech debt silently | Apply the lint rule correctly |
| `catch (e) {}` empty catch blocks | Swallows errors — bugs become invisible | Log at minimum; handle or re-throw |
| Comment out broken code | It will never be uncommented | Fix it or delete it entirely |
| Hardcode values to pass specific tests | Test passes, but feature is broken for real data | Fix the logic, not the values |
| `--force` on npm/yarn install | Ignores peer dep conflicts causing runtime crashes | Resolve conflicts explicitly |
| Increase test timeouts without fixing cause | Masks slow code or deadlocks | Profile and fix the underlying issue |

**The ONE fix rule prevents most anti-patterns.** When tempted to use one, it signals the real fix is harder — log it, skip to next item, return with fresh context.

## Fix Verification Depth

Verification depth scales with blast radius:

| Change Scope | Minimum Verification | Full Verification |
|-------------|---------------------|-------------------|
| Single utility function | Unit tests for that function | Unit + integration tests for callers |
| Public API change | Integration tests | Unit + integration + contract tests |
| Database schema | Migration dry-run | Staging environment smoke test |
| Config / env var | CI pipeline run | Full deployment to staging |
| Dependency upgrade | `npm test` | Full regression suite + e2e |
| Auth / security code | Unit + integration | Security audit + penetration test |

## Composite Metric

For bounded loops, a nuanced fix_score accounting for quality of fixes:

```
fix_score = reduction_score + quality_score + bonus_score

reduction_score = ((baseline_errors - current_errors) / baseline_errors) * 60
  # Weight: 60% — primary goal is reducing errors

quality_score = 0
  # Deduct for low-quality fixes (anti-patterns used):
  quality_score -= (suppression_count * 5)   # @ts-ignore, eslint-disable used
  quality_score -= (skipped_test_count * 10)  # tests deleted/commented out
  quality_score -= (any_type_count * 3)       # `any` type introduced
  quality_score = max(quality_score, -20)     # floor: never below -20

guard_score = (guard_always_passed ? 25 : 0)
  # Weight: 25% — no regressions is critical

bonus_score = 0
  bonus_score += (zero_errors ? 10 : 0)              # all clear bonus
  bonus_score += (no_discards ? 5 : 0)               # every fix worked first try
  bonus_score += (compound_detected_and_fixed ? 5 : 0) # found hidden bugs too
```

**Interpretation:**
- **100+** = perfect: all errors fixed, no regressions, no anti-patterns
- **80-99** = good: significant progress, guards held, minimal anti-patterns
- **60-79** = acceptable: meaningful reduction, but some regressions or anti-patterns
- **<60** = needs work: too many discards, guard failures, or anti-patterns used

## Fix Impact Assessment

Before applying a fix, estimate the blast radius:

```
FUNCTION assessImpact(target_file, fix_type):
  # How many files import this file?
  dependents = grep -r "import.*{target_file}" src/

  # Is this in a critical path?
  is_critical = target_file in [auth, payments, database, api-gateway]

  # How many tests cover this?
  test_coverage = count tests that import or test target_file

  RETURN {
    dependents: N,
    is_critical: bool,
    test_coverage: N,
    risk_level: HIGH if (dependents > 10 OR is_critical) else MEDIUM if dependents > 3 else LOW
  }
```

| Risk Level | Action |
|------------|--------|
| LOW | Fix and verify with unit tests |
| MEDIUM | Fix with unit + integration tests as guard |
| HIGH | Fix in isolation branch, verify against full suite, get review before merge |

## Compound Fix Detection

When fixing one error reveals another, or a fix is only partial:

```
FUNCTION detectCompound(before_errors, after_errors):
  new_errors = after_errors - before_errors  # errors that didn't exist before

  IF new_errors > 0:
    LOG "Compound fix detected: {N} new errors surfaced"
    # These are likely pre-existing errors that were masked
    ADD new_errors to fix queue at current priority
    CONTINUE (do not treat as regression)

  IF delta == 0 AND error_details_changed:
    LOG "Error transformed — not fixed, just moved"
    REVERT and try different approach
```

**Common compound patterns:**
- Fixing a type error reveals a logic error that the wrong type was hiding
- Fixing a null check reveals a missing initialization
- Upgrading a dependency reveals previously passing tests were relying on a bug
- Fixing test A reveals test B was sharing mutable state

## Rollback Protocol

When a fix makes things worse (delta < 0) or breaks the guard:

```
STEP 1: Identify the bad commit
  git log --oneline -5

STEP 2: Revert the specific commit
  git revert HEAD --no-edit
  # OR for harder cases:
  git reset --soft HEAD~1  # unstage the commit
  git checkout -- .        # discard working changes

STEP 3: Verify rollback succeeded
  Run original failing command — should return to pre-fix error count

STEP 4: Log the failed approach in fix-results.tsv
  Mark as "discard" with description of why it failed

STEP 5: Analyze before retrying
  - What assumption was wrong?
  - What did the fix break?
  - Is there a smaller, safer change?
```

**Never skip rollback.** A partial fix in a broken state makes the next iteration's error detection unreliable.

## Parallel Fix Detection

Some errors are independent and can be fixed in parallel (separate files, no shared state):

```
FUNCTION detectParallelizable(error_list):
  groups = {}

  FOR each error:
    affected_files = error.file
    FOR each group:
      IF affected_files overlaps group.files:
        MERGE error into group  # dependent
      ELSE:
        CREATE new group        # independent

  independent_groups = groups where len(group.files) == 1

  RETURN independent_groups  # can be fixed in parallel subagents
```

**When to parallelize:** 5+ independent errors across different modules. Spawn parallel fix agents with `--scope` to isolate.

## Fix History Pattern Learning

Before attempting a fix, check git history for past approaches on the same file:

```bash
# See what fixes were tried in this file before
git log --oneline --follow -- src/auth/handler.ts

# See the diff of a specific past fix
git show <commit-hash> -- src/auth/handler.ts

# Search for past fix attempts on this error type
git log --grep="fix: type error" --oneline
```

**Pattern signals:**
- Same error fixed 3+ times → root cause not addressed, fix the architectural issue
- Recent revert in same file → previous approach failed, avoid repeating it
- Large diff for "simple" fix → complexity hidden in that file, be careful with changes

## The Fix Didn't Work — Escalation Path

When 3 attempts at the same error fail:

```
Attempt 1: FAIL → Log approach, try different strategy
Attempt 2: FAIL → Log approach, read git history for prior attempts
Attempt 3: FAIL → Escalate:

  1. DOCUMENT: What was tried (3 approaches), why each failed
  2. ISOLATE: Create minimal reproduction case
  3. SKIP: Move this error to "blocked" list, continue with others
  4. FLAG: Note in summary.md — "Error X requires investigation"
  5. SUGGEST: /autoresearch_debug on the specific error for root cause analysis
```

**Never loop on the same failing approach.** Each attempt must use a materially different strategy.

## Dependency Fix Patterns

When the error originates from `node_modules`, `pip` packages, or vendored dependencies:

| Symptom | Strategy | Command |
|---------|----------|---------|
| Peer dependency conflict | Upgrade to compatible version | `npm install pkg@latest` |
| Breaking change in minor update | Pin to last working version | `npm install pkg@1.2.3` |
| Security vulnerability | Patch or replace | `npm audit fix` / replace with alternative |
| Transitive dependency conflict | Force resolution | `package.json` resolutions/overrides field |
| Python package incompatibility | Pin in requirements | `pip install pkg==x.y.z` |
| Missing native bindings | Rebuild from source | `npm rebuild` / `pip install --no-binary` |

**Rule:** Never vendor-patch `node_modules` directly — it will be overwritten. Add a `patch-package` patch or fork.

## Database Migration Fix Patterns

When errors involve schema conflicts or data integrity:

| Error Type | Strategy |
|------------|----------|
| Migration out of order | Check migration history table, apply missing migrations in sequence |
| Schema conflict (column exists) | Make migration idempotent: `IF NOT EXISTS` / `ADD COLUMN IF NOT EXISTS` |
| Data integrity violation | Fix data BEFORE applying constraint, or migrate in two steps: add nullable → backfill → add constraint |
| Failed rollback | Restore from backup, replay forward migrations to known-good point |
| Enum type conflict (Postgres) | Cannot alter enums in transactions — use `ALTER TYPE` outside transaction block |

**Rule:** Always test migrations on a copy of production data before applying. Use `--dry-run` if available.

## CI/CD Pipeline Fix Patterns

When errors appear only in CI (not locally):

| Symptom | Root Cause | Fix |
|---------|------------|-----|
| `env var not found` | Secret not in CI environment | Add secret to CI settings, reference via `${{ secrets.NAME }}` |
| Permission denied | Missing IAM role / workflow permissions | Add `permissions:` block to workflow YAML |
| Timeout | Slow test / missing cache | Add caching step, increase timeout, parallelize jobs |
| Works locally, fails in CI | OS difference (macOS vs Linux) | Test in Docker matching CI OS; check path case sensitivity |
| Flaky test in CI | Race condition or timing | Add retry logic, fix async handling, isolate test state |
| Cache poisoning | Stale cache from broken state | Clear CI cache, add cache key version bump |

## Auto-Detection Reference

| Signal | Detected Type | Verify Command |
|--------|---------------|----------------|
| `package.json` has `test` script | test | `npm test` |
| `tsconfig.json` exists | type | `tsc --noEmit` |
| `.eslintrc*` or `eslint.config.*` exists | lint | `npx eslint .` |
| `pyproject.toml` has `pytest` | test | `pytest` |
| `pyproject.toml` has `mypy` or `ruff` | type + lint | `mypy .`, `ruff check .` |
| `Cargo.toml` exists | test + lint | `cargo test`, `cargo clippy` |
| `go.mod` exists | test + lint | `go test ./...`, `golangci-lint run` |
| `build` script in package.json | build | `npm run build` |
| `next.config.*` exists | build | `next build` |
| `vite.config.*` exists | build | `vite build` |
| `.github/workflows/*.yml` exists | ci | Check latest run: `gh run list --limit 1` |
| `debug/*/findings.md` exists | bug | Parse findings |
| `tsc --noEmit` shows `TS2322`, `TS2345` | type error | Fix type mismatch |
| test output shows `Expected.*Received` | test failure | Fix assertion |
| build log shows `Module not found` | build failure | Fix import path |
| CI log shows `exit code 1` | ci | Inspect failed step |

## Chaining Patterns

```bash
# Debug first, then fix what was found
/autoresearch_debug
Iterations: 15

/autoresearch_fix --from-debug
Iterations: 30

# Fix with guard
/autoresearch_fix
Target: npm run typecheck
Guard: npm test

# Fix only tests, guard with types
/autoresearch_fix --category test --guard "tsc --noEmit"

# Fix everything — iterate until clean
/autoresearch_fix

# Bounded sprint — fix as many as you can in 20 iterations
/autoresearch_fix
Iterations: 20
```

### Chain Conversion

#### `--chain debug`

After fixing, hunt for more bugs in affected areas. Passes the set of modified files so debug focuses where changes landed.

```
/autoresearch_debug
Scope: {unique file paths modified during fix session}
Symptom: post-fix verification — check for regressions or newly exposed bugs
```

#### `--chain security`

After fixes, verify no security regressions were introduced and confirm that fix changes didn't open new attack surface.

```
/autoresearch_security
Scope: {files modified during fix session}
Focus: post-fix security regression check
```

#### `--chain ship`

After all fixes pass, ship the changes. Passes fix session stats as a readiness signal.

```
/autoresearch_ship
Gate: {PASS if fix_score >= 80 and zero blocked items, WARN otherwise}
```

#### `--chain learn`

Document what was fixed and patterns found for codebase knowledge.

```
/autoresearch_learn
Topic: fix patterns and root causes from fix session
Source: fix/{slug}/summary.md
```

#### `--chain scenario`

Explore edge cases around areas that were fixed — verify the fix is correct under boundary conditions.

```
/autoresearch_scenario
Scenario: edge cases around recently fixed code
Domain: software
Scope: {file paths modified during fix session}
```

#### `--chain predict`

Predict impact of the fixes on the broader codebase — catch cascading effects the fix might have introduced.

```
/autoresearch_predict
Scope: {file paths modified during fix session}
Goal: predict cascading impact of recent fixes
```

#### `--chain plan`

Plan next steps based on remaining blocked items from `blocked.md`.

```
/autoresearch_plan
Goal: address blocked fix items requiring further investigation
Source: fix/{slug}/blocked.md
```

#### `--chain reason`

Reason about best approach for blocked or complex fixes that couldn't be resolved in the fix loop.

```
/autoresearch_reason
Task: determine best approach for blocked fix items
Evidence: fix/{slug}/blocked.md
```

#### `--chain probe`

Interrogate whether the fix requirements were complete — blocked items often reveal missing or contradictory requirements.

```
/autoresearch_probe
Topic: requirement gaps revealed by blocked fixes
Source: fix/{slug}/blocked.md
```

### Multi-Chain Execution

`--chain debug,security,ship` executes sequentially:

1. Write `handoff.json` after fix completes
2. Launch `debug` with chain conversion above
3. After `debug` completes, convert debug findings + `handoff.json` → `security` context
4. After `security` completes, convert security findings → `ship` gate
5. Each stage's output feeds the next via updated `handoff.json`

**Empirical evidence rule:** Downstream loop results ALWAYS override upstream fix session conclusions. If debug or security finds regressions introduced by the fix, downstream results win — do not assume the fix is clean.

## Output Directory

Creates `fix/{YYMMDD}-{HHMM}-{fix-slug}/` with:
- `fix-results.tsv` — iteration log
- `summary.md` — what was fixed, what remains, stats
- `blocked.md` — errors that needed 3+ attempts and were escalated
- `impact-assessment.md` — blast radius analysis for each fix applied

## Extended Chaining Patterns

```bash
# Full pipeline: debug → fix → ship
/autoresearch_debug
Iterations: 15

/autoresearch_fix --from-debug --guard "npm test"
Iterations: 30

/autoresearch_ship

# Fix only critical issues, then verify clean
/autoresearch_fix --category build
/autoresearch_fix --category type --guard "npm run build"
/autoresearch_fix --category test --guard "tsc --noEmit"

# Scoped fix with parallel agents
/autoresearch_fix --scope "src/api/**" --category type
/autoresearch_fix --scope "src/auth/**" --category test

# Fix with warning suppression disabled
/autoresearch_fix --category warning --skip-lint

# CI-specific fix: re-run on CI failure
/autoresearch_fix --target "npm run ci" --guard "npm test"

# After dependency upgrade: fix cascade
npm upgrade && /autoresearch_fix --category type --category test
```

## Summary Report Format

```markdown
# Fix Session Summary

## Stats
- Session: fix/260316-1805-auth-fixes/
- Duration: 23 iterations
- Baseline: 47 errors (31 test, 12 type, 4 lint)
- Final: 3 errors (2 test, 1 type, 0 lint)
- Reduction: 93.6% (-44 errors)

## Fix Score
fix_score: 97/100
- Reduction: 58/60 (93.6%)
- Guard: 25/25 (no regressions)
- Bonus: +10 (zero lint errors)
- Anti-patterns used: 0

## Fixed
- auth.ts:42 — add return type annotation (type)
- db.ts:15 — handle nullable column (type)
- api.test.ts — fix expected status code 200→201 (test)
[... 41 more ...]

## Blocked (requires investigation)
- auth/token-refresh.ts — circular dependency blocks type resolution
  → Suggested: /autoresearch_debug --scope auth/token-refresh.ts

## Remaining
- user.test.ts:88 — flaky timing test (not a code bug)
- config.ts:12 — type error requires breaking API change
```
