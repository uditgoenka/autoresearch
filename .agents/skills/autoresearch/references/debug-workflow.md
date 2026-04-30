# Debug Workflow — $autoresearch debug

Autonomous bug-hunting loop that applies the scientific method iteratively. Doesn't stop at one bug — keeps investigating until the codebase is clean or you interrupt.

**Core idea:** Hypothesize → Test → Prove/Disprove → Log → Repeat. Every finding needs code evidence. Every failed hypothesis teaches the next one.

## Trigger

- User invokes `$autoresearch debug`
- User says "find all bugs", "debug this", "why is this failing", "hunt bugs", "investigate"
- User reports a specific error and wants root cause analysis

## Loop Support

```
# Unlimited — keep hunting bugs until interrupted
$autoresearch debug

# Bounded — exactly N investigation iterations
$autoresearch debug
Iterations: 20

# Focused scope
$autoresearch debug
Scope: src/api/**/*.ts
Symptom: API returns 500 on POST /users
```

## PREREQUISITE: Interactive Setup (when invoked without flags)

**CRITICAL — BLOCKING PREREQUISITE:** If `$autoresearch debug` is invoked without `--scope` or `--symptom`, you MUST use direct prompting to gather full context BEFORE proceeding to ANY phase. DO NOT skip this step. DO NOT jump to Phase 1 without completing interactive setup.

Scan the codebase first (run tests, lint, typecheck) to detect existing failures and provide smart defaults.

**Single batched call — all 4 questions at once:**

You MUST call direct prompting with all 4 questions in ONE call:

| # | Header | Question | Options (from codebase scan) |
|---|--------|----------|------------------------------|
| 1 | `Issue` | "What's the problem?" | "Hunt all bugs (scan entire codebase)", "Specific error (I'll describe it)", "Failing tests", "CI/CD failure", "Performance issue" |
| 2 | `Scope` | "Which files should I investigate?" | Suggested globs from project structure + "Entire codebase" |
| 3 | `Depth` | "How deep should I investigate?" | "Quick scan (5 iterations)", "Standard (15 iterations)", "Deep investigation (30+)", "Unlimited" |
| 4 | `After` | "When bugs are found, what should happen next?" | "Find bugs only (report)", "Find and fix (--chain fix)", "Chain to another tool (--chain <targets>)", "Ask me after each finding" |

**IMPORTANT:** Always ask all 4 questions in a single call — never one at a time. Users need full context to make informed decisions.

If `--scope`, `--symptom`, `--fix`, or `--chain` flags are provided, skip the interactive setup and proceed directly to Phase 1.

## Architecture

```
$autoresearch debug
  ├── Phase 1: Gather (symptoms + context)
  ├── Phase 2: Reconnaissance (scan codebase, map error surface)
  ├── Phase 3: Hypothesize (form falsifiable hypothesis)
  ├── Phase 4: Test (run experiment to prove/disprove)
  ├── Phase 5: Classify (bug found / hypothesis disproven / inconclusive)
  ├── Phase 6: Log (record finding or elimination)
  └── Phase 7: Repeat (next hypothesis, next vector)
```

## Phase 1: Gather — Symptoms & Context

**STOP: Have you completed the Interactive Setup above?** If invoked without `--scope`/`--symptom` flags, you MUST complete the direct prompting call above BEFORE entering this phase.

Collect everything known about the problem before investigating.

**If user provides symptoms:**
- Expected behavior vs actual behavior
- Error messages, stack traces, log output
- When it started (commit, deploy, config change)
- Reproduction steps (if known)
- Environment (OS, runtime, versions)

**If no symptoms (autonomous bug hunting):**
- Run existing test suite, collect failures
- Run linter, collect errors
- Run type checker, collect issues
- Check build, collect warnings
- Scan for common anti-patterns (unhandled promises, unchecked nulls, race conditions)

**Output:** `✓ Phase 1: Gathered — [N] symptoms, [M] error signals detected`

## Phase 2: Reconnaissance — Map the Error Surface

Understand the codebase area where bugs likely live.

**Actions:**
1. Read files mentioned in stack traces / error messages
2. Trace call chains from error origin backward
3. Identify entry points (API routes, event handlers, CLI commands)
4. Map data flow through affected components
5. Check recent git changes in affected area (`git log --oneline -20 -- <path>`)
6. Identify external dependencies and integration points

**Error surface map:**
```
Entry Point → Data Flow → Failure Point → Side Effects
  POST /users → validate() → db.insert() → ← FAILS HERE
                                             → notification.send() ← cascading
```

**Output:** `✓ Phase 2: Recon — [N] files scanned, [M] potential failure points mapped`

## Phase 3: Hypothesize — Form Falsifiable Hypothesis

**A good hypothesis is:**
- Specific: "The JWT validation skips algorithm check on line 42 of auth.ts"
- Testable: Can be proven/disproven with a concrete experiment
- Falsifiable: There exists evidence that would prove it wrong
- Prioritized: Most likely cause first (based on evidence so far)

**Hypothesis formation strategy:**

| Priority | Strategy | When to Use |
|----------|----------|-------------|
| 1 | **Error message literal** | Stack trace points to exact line |
| 2 | **Recent change** | Bug started after specific commit |
| 3 | **Data flow trace** | Input → Transform → Output chain |
| 4 | **Environment diff** | Works locally, fails in CI/prod |
| 5 | **Dependency issue** | After upgrade/install |
| 6 | **Race condition** | Intermittent, timing-dependent |
| 7 | **Edge case** | Works for most inputs, fails for specific ones |

**Cognitive bias guards:**
- Confirmation bias: Actively seek evidence AGAINST your hypothesis
- Anchoring: Don't fixate on the first clue — consider alternatives
- Sunk cost: If 3 experiments fail to confirm, abandon and try new hypothesis
- Availability: Just because a bug pattern is familiar doesn't mean it's the cause

**Output:** `Hypothesis [N]: "[specific, testable claim]" — testing...`

## Phase 4: Test — Run Experiment

Design a minimal experiment that definitively proves or disproves the hypothesis.

**Experiment types:**

| Type | Method | Best For |
|------|--------|----------|
| **Direct inspection** | Read the code at suspected location | Logic errors, missing checks |
| **Trace execution** | Add logging, run, read output | Data flow issues |
| **Minimal reproduction** | Create smallest failing case | Complex interactions |
| **Binary search** | Comment out half the code, narrow | "Something in this file breaks" |
| **Differential** | Compare working vs broken (git diff, env diff) | Regressions |
| **Git bisect** | Find exact commit that introduced bug | "It used to work" |
| **Input variation** | Change inputs systematically | Edge cases, boundary issues |

**Experiment rules:**
- ONE experiment per iteration (atomic — know exactly what you tested)
- Record the exact command/action and its output
- If experiment is destructive, git stash first
- Timeout: if an experiment takes >30 seconds, it's too complex — simplify

## Phase 5: Classify — What Did We Learn?

| Result | Action |
|--------|--------|
| **Bug confirmed** | Record finding with full evidence, severity, location |
| **Hypothesis disproven** | Log as eliminated, extract learnings for next hypothesis |
| **Inconclusive** | Refine hypothesis with additional constraints, re-test |
| **New lead discovered** | Log discovery, add to hypothesis queue |

**Bug finding format:**
```
### [SEVERITY] Bug: [title]
- **Location:** `file:line`
- **Hypothesis:** [what we suspected]
- **Evidence:** [code snippet + experiment result]
- **Reproduction:** [exact steps to trigger]
- **Impact:** [what breaks, who's affected]
- **Root cause:** [WHY it happens, not just WHAT happens]
- **Suggested fix:** [concrete code change]
```

**Severity classification:**
| Level | Criteria |
|-------|----------|
| CRITICAL | Data loss, security breach, system crash |
| HIGH | Feature broken, incorrect results, performance degradation >10x |
| MEDIUM | Edge case failure, degraded UX, workaround exists |
| LOW | Cosmetic, minor inconsistency, theoretical risk |

## Phase 6: Log — Record Everything

**Append to debug-results.tsv:**
```tsv
iteration	type	hypothesis	result	severity	location	description
1	hypothesis	JWT skips alg check	confirmed	CRITICAL	auth.ts:42	Algorithm confusion vulnerability
2	hypothesis	Rate limit missing	disproven	-	-	Rate limiter exists in middleware
3	discovery	-	new_lead	-	db.ts:88	Unhandled promise rejection in insert
4	hypothesis	DB insert missing await	confirmed	HIGH	db.ts:88	Silent failure on write errors
```

**Every 5 iterations, print progress:**
```
=== Debug Progress (iteration 10) ===
Bugs found: 3 (1 Critical, 1 High, 1 Medium)
Hypotheses tested: 8 (3 confirmed, 4 disproven, 1 inconclusive)
Files investigated: 14 / 47 in scope
Techniques used: direct inspection, trace, binary search
```

## Phase 7: Repeat — Next Investigation

**Prioritization for next iteration:**
1. Follow new leads discovered during previous experiments
2. Untested high-priority hypotheses
3. Uninvestigated files in the error surface
4. Deeper investigation of confirmed bugs (find root cause, not just symptom)
5. Pattern-based search (if found NULL check bug, look for similar patterns elsewhere)

**When to stop (unbounded mode):**
- Never stop automatically — user interrupts
- Print a "diminishing returns" warning after 5 iterations with no new findings

**When to stop (bounded mode):**
- After N iterations, print final summary and stop

## Flags

| Flag | Purpose |
|------|---------|
| `--fix` | After finding bugs, switch to autoresearch:fix mode to fix them (shortcut for `--chain fix`) |
| `--scope <glob>` | Limit investigation to specific files |
| `--symptom "<text>"` | Pre-fill symptom instead of asking |
| `--severity <level>` | Only report findings at or above this severity |
| `--technique <name>` | Force a specific investigation technique |
| `--chain <targets>` | Chain to downstream tool(s) after completion. Comma-separated for multi-chain. Spaces after commas tolerated. |

## Composite Metric

For bounded loops, the debug thoroughness metric:

```
debug_score = bugs_found * 15
            + hypotheses_tested * 3
            + (files_investigated / files_in_scope) * 40
            + (techniques_used / 7) * 10
```

Higher = more thorough. Incentivizes breadth (cover more files) AND depth (test more hypotheses).

## Investigation Techniques Reference

### Binary Search
Comment out half the suspicious code. If bug disappears, it's in that half. Repeat.

### Differential Debugging
Compare working state vs broken state:
- `git stash` to test clean state
- `git bisect` to find exact breaking commit
- Environment variables diff between working/failing environments

### Minimal Reproduction
Strip away everything until you have the smallest possible case that reproduces the bug. Fewer moving parts = clearer cause.

### Trace Execution
Add strategic console.log/print statements at key data flow points. Run and read the actual values vs expected values.

### Pattern Search
Found one bug? Search for the same anti-pattern across the codebase:
```bash
grep -rn "pattern" src/ --include="*.ts"
```

### Working Backwards
Start from the error (output) and trace backward through the code until you find where correct behavior diverges from actual behavior.

### Rubber Duck
Explain the code out loud, line by line. The act of explaining often reveals the assumption that's wrong.

## Common Bug Patterns by Language

Quick reference for language-specific bugs to scan for during reconnaissance.

| Language | Classic Bug | Pattern to Search | Why It Happens |
|----------|-------------|-------------------|----------------|
| **JavaScript** | Unhandled promise rejection | `Promise` without `.catch` / missing `await` | Async errors are swallowed silently |
| **TypeScript** | `undefined` access after null check narrowing | `obj?.prop` then `obj.other` (lost narrowing) | Type narrowing is scope-limited |
| **Python** | Mutable default argument | `def f(x=[]):` — shared across all calls | Python evaluates defaults once at definition time |
| **Python** | `None` injection from unchecked return | Function returns `None` on error path, caller chains it | Missing null/None guard |
| **Go** | Goroutine leak | Goroutine blocks on channel that's never closed | Missing `defer close(ch)` or `context.Cancel()` |
| **Go** | Race condition on shared map | Concurrent read/write without mutex | Maps in Go are not goroutine-safe |
| **Go** | Integer overflow in slice/buffer ops | `int` size differences on 32-bit vs 64-bit | Implicit numeric type assumptions |
| **Rust** | Panic in production from `.unwrap()` | `Option::unwrap()` / `Result::unwrap()` on `Err` | Error path not handled |
| **Java** | `NullPointerException` cascade | Unguarded method chain `a.b().c().d()` | No null checks in chain |
| **Java** | SQL injection via string concat | `"SELECT * FROM t WHERE id=" + id` | Missing parameterized queries |
| **SQL** | N+1 query | Loop calling DB inside loop | Missing JOIN or batch fetch |
| **All** | Race condition on shared state | Global/singleton mutated from concurrent threads | Missing synchronization |
| **All** | Integer overflow in calculations | Arithmetic on large numbers without bounds check | Silent wrap-around on overflow |
| **All** | Injection vulnerability | User input concatenated into command/query/template | Missing sanitization/escaping |

**Reconnaissance shortcut:** When entering Phase 2, grep for these patterns first — they're statistically the most common issues.

## Domain-Specific Debugging

Different domains have predictable failure modes. Apply domain-specific reconnaissance before forming hypotheses.

### API Bugs

Common failure points: auth middleware order, content-type mismatch, serialization/deserialization, HTTP status code semantics.

**API debug checklist:**
- Does the route exist and match the HTTP method?
- Is auth middleware applied and in the correct order?
- Does the request body parse correctly (Content-Type header)?
- Are 4xx responses distinguishable from 5xx? Is error shape consistent?
- Are query parameters validated and typed correctly?

### Database Bugs

Common failure points: N+1 queries, missing transactions, constraint violations swallowed by ORM, timezone handling, NULL propagation.

**Database debug checklist:**
- Are all writes wrapped in transactions where atomicity is needed?
- Are NULL values handled at the DB and application layer?
- Is the query hitting an index? (check with `EXPLAIN`)
- Is connection pooling exhausted? (check connection count vs pool limit)
- Are timestamps stored as UTC? Converted correctly on read?

### Authentication / Authorization Bugs

Common failure points: token validation skipping algorithm check, expired token not rejected, privilege escalation from missing ownership check.

**Auth debug checklist:**
- Is the JWT `alg` field validated (prevent algorithm confusion attacks)?
- Is token expiry (`exp`) checked?
- Is authorization (ownership check) separate from authentication (identity check)?
- Are there privilege escalation paths (e.g., regular user accessing admin endpoint)?

### Async / Concurrency Bugs

Common failure points: race conditions on shared state, missing await causing partial execution, event loop blocking, deadlock.

**Async debug checklist:**
- Is every `async` function `await`ed at the call site?
- Are shared mutable state accesses synchronized (mutex, lock, atomic)?
- Is there a risk of deadlock (two locks acquired in different orders)?
- Are network/database calls inside async handlers non-blocking?

### Network / Integration Bugs

Common failure points: timeout misconfiguration, retry storm on transient failure, missing circuit breaker, charset encoding mismatch.

**Network debug checklist:**
- Are timeouts set on all outbound calls?
- Is retry logic bounded (exponential backoff with max retries)?
- Is response parsing resilient to unexpected fields?
- Are character encoding assumptions explicit (UTF-8 everywhere)?

## What NOT to Do — Debug Anti-Patterns

| Anti-Pattern | Why It Fails |
|---|---|
| **Fix before understanding** | You'll fix symptoms, not causes. The bug comes back. |
| **Change multiple things at once** | Can't attribute improvement/regression to any single change. |
| **Ignore disproven hypotheses** | Not logging eliminations means repeating failed investigations. |
| **Assume instead of verify** | "It's probably X" without testing = confirmation bias. Run the experiment. |
| **Skip reproduction** | If you can't reproduce it, you can't verify the fix. |
| **Debug in production** | Never investigate with live data. Reproduce locally first. |
| **Tunnel vision on one file** | Bugs often span boundaries. Trace the full data flow. |
| **Trust error messages literally** | Error messages describe symptoms. Root cause is often 2-3 layers deeper. |
| **Give up after 3 tries** | Some bugs need 10+ hypotheses. Shift technique, don't stop. |
| **Blame the framework** | 95% of the time it's your code. Prove framework bug with minimal reproduction first. |

## Multi-File Bug Tracing

When a bug spans multiple files or services, standard single-file inspection fails. Use a structured cross-file trace.

**When to apply:**
- Stack trace crosses multiple files/modules
- Bug involves data transformation across service boundaries
- Fix in one file doesn't resolve the issue (symptom vs cause)

**Protocol:**
1. Start at the symptom (error output or failing assertion)
2. Trace backwards across file boundaries: identify the data/call flowing in
3. For each file in the trace, record: what goes in, what comes out, where it transforms
4. Identify the first file where the output diverges from the expected contract
5. That file owns the bug — even if it's not where the error surfaces

**Multi-file trace map format:**
```
file-a.ts → file-b.ts → file-c.ts → ERROR
  input: {...}  transform: {...}  output: WRONG
         ^first divergence = root cause lives here
```

**Across microservices:** Add network boundaries to the map. Include request/response payloads at each service boundary. A bug "in service B" often means service A sent malformed data.

## Performance Bug Investigation

Performance bugs are correctness bugs where the output is "too slow" rather than "wrong". Apply the same scientific method with profiling as the measurement tool.

**Profiling first, guessing second:**
- Profile before optimizing — the slow part is almost never where you think
- Identify the single hottest path (slow query, slow render, slow computation)
- Reproduce the slowness with a minimal benchmark before attempting a fix

**Performance issue patterns:**
| Symptom | Likely Cause | Investigation Method |
|---------|--------------|---------------------|
| Slow API response | N+1 database queries | Log SQL queries, count DB calls per request |
| Slow page render | Expensive recomputation on every render | Profiling (React DevTools, Chrome DevTools) |
| Slow background job | Missing index on query inside loop | `EXPLAIN ANALYZE` on repeated queries |
| Gradual memory growth | Memory leak (event listeners, unclosed connections) | Heap snapshots over time |
| Slow cold start | Over-importing, large bundle, slow init code | Bundle analyzer, startup profiling |
| Intermittent slow requests | Lock contention or connection pool exhaustion | DB slow query log, connection pool metrics |

**Performance debug checklist:**
1. Measure baseline (p50, p95, p99 latency or total time)
2. Profile to find the actual hotspot (not the assumed one)
3. Form hypothesis: "removing X will reduce Y by Z%"
4. Implement ONE change, re-measure
5. Verify improvement is statistically significant (not noise)

## The 5 Whys — Root Cause Drill-Down

Surface errors rarely reveal root causes. Ask "why" recursively until you reach a fundamental cause you can permanently fix.

**Template:**
```
Symptom: [what the user/system reported]
Why 1: [immediate technical cause]
Why 2: [cause of the cause]
Why 3: [deeper system issue]
Why 4: [process or design flaw]
Why 5: [root cause — fixable permanently]
```

**Example:**
```
Symptom: API returns 500 on POST /users
Why 1: database insert throws ConstraintViolationError
Why 2: email field is empty string, violates NOT NULL constraint
Why 3: validation layer allows empty strings as valid email
Why 4: validation uses truthy check (empty string is falsy — wait, it isn't)
Why 5: regex validator has a bug — accepts empty string as valid email format
Root Fix: fix the email regex to require at least one character before @
```

**Stop when:** The why leads to an external system outside your control, a deliberate design decision, or a hardware/infrastructure limit. Those get a workaround, not a root fix.

**Stop asking why if:** You reach a fix that prevents ALL future instances of this class of bug — not just this specific instance.

### Chain Conversion

#### `--chain fix`

Most natural pairing. Each confirmed bug becomes a fix target sorted by severity. Passes bug title, file location, and a `From-Debug: true` marker so fix knows context.

```
$autoresearch fix
Scope: {unique file paths from findings.md}
Target: {top bug title}
From-Debug: true
```

#### `--chain security`

Filter findings where root cause is security-related (auth, injection, data exposure, privilege). Map each to the relevant STRIDE category for a focused security audit.

```
$autoresearch security
Scope: {files from security-related findings}
Focus: Swarm-predicted vectors: {comma-separated bug titles}
```

#### `--chain scenario`

Each confirmed bug becomes a scenario seed exploring its edge cases and blast radius.

```
$autoresearch scenario
Scenario: {bug title} — {one-line description}
Domain: software
Depth: standard
```

#### `--chain predict`

Bug patterns become the goal for a multi-persona swarm — "predict what else might break given these patterns."

```
$autoresearch predict
Scope: {file paths from findings.md}
Goal: predict related failures given bug patterns: {comma-separated bug root causes}
```

#### `--chain plan`

Confirmed bugs become the goal for a structured fix implementation plan.

```
$autoresearch plan
Goal: fix confirmed bugs — {N} items
Scope: {file paths from findings.md}
```

#### `--chain learn`

Bug patterns and root causes documented for codebase learning.

```
$autoresearch learn
Topic: bug patterns and root causes from debug session
Source: debug/{slug}/findings.md
```

#### `--chain reason`

Bug findings become the task for adversarial refinement — "what's the best fix approach."

```
$autoresearch reason
Task: determine best fix approach for confirmed bugs
Evidence: debug/{slug}/findings.md
```

#### `--chain ship`

Convert bugs to gate classifications before shipping.

```
$autoresearch ship
Gate: {FAIL if any Critical/High confirmed bugs, WARN if Medium, INFO if Low only}
Blockers: {count of Critical/High bugs}
```

#### `--chain probe`

Bug patterns become topics for requirement interrogation — "what requirements did we miss."

```
$autoresearch probe
Topic: requirement gaps revealed by bugs: {comma-separated bug titles}
```

### Multi-Chain Execution

`--chain fix,scenario,security` executes sequentially:

1. Write `handoff.json` after debug completes
2. Launch `fix` with chain conversion above
3. After `fix` completes, convert fix results + `handoff.json` → `scenario` context
4. After `scenario` completes, convert scenario findings → `security` targets
5. Each stage's output feeds the next via updated `handoff.json`

**Empirical evidence rule:** Downstream loop results ALWAYS override upstream findings. If fix or security disproves a debug hypothesis, the downstream result wins — do not revert to the debug conclusion.

## Output Directory

Creates `debug/{YYMMDD}-{HHMM}-{debug-slug}/` with:
- `findings.md` — all confirmed bugs with evidence
- `eliminated.md` — disproven hypotheses (equally valuable)
- `debug-results.tsv` — iteration log
- `summary.md` — executive summary with recommendations

## Chaining with $autoresearch fix

```
# Find bugs, then fix them
$autoresearch debug --fix

# Or manually chain
$autoresearch debug
Iterations: 15

$autoresearch fix
Iterations: 20
```

When `--fix` is specified, after the debug loop completes, automatically switches to `$autoresearch fix --from-debug` targeting the discovered issues. The `--from-debug` flag tells fix to read findings from the latest debug session.
