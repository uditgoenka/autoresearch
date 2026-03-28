# Plan Workflow — /autoresearch_plan

Convert a textual goal into a validated, ready-to-execute autoresearch configuration.

**Output:** A complete `/autoresearch` invocation with Scope, Metric, Direction, and Verify — all validated before launch.

## Trigger

- User invokes `/autoresearch_plan`
- User says "help me set up autoresearch", "plan an autoresearch run", "what should my metric be"

## Workflow

### Phase 1: Capture Goal

**CRITICAL — BLOCKING PREREQUISITE:** If no goal is provided inline, you MUST use `question` to capture it. DO NOT skip this step or proceed to Phase 2 without a goal.

```
question:
  question: "What do you want to improve? Describe your goal in plain language."
  header: "Goal"
  options:
    - label: "Code quality"
      description: "Tests, coverage, type safety, linting, bundle size"
    - label: "Performance"
      description: "Response time, build speed, Lighthouse score, memory usage"
    - label: "Content"
      description: "SEO score, readability, word count, keyword density"
    - label: "Refactoring"
      description: "Reduce LOC, eliminate patterns, simplify architecture"
```

If user provides goal text directly, skip to Phase 2.

### Phase 2: Analyze Context

1. Read codebase structure (package.json, project files, test config)
2. Identify domain: backend, frontend, ML, content, DevOps, etc.
3. Detect existing tooling: test runner, linter, bundler, benchmark scripts
4. Infer likely metric candidates from goal + tooling

### Phase 3: Define Scope

Present scope options based on codebase analysis:

```
question:
  question: "Which files should autoresearch be allowed to modify?"
  header: "Scope"
  options:
    - label: "{inferred_scope_1}"
      description: "{file count} files — {rationale}"
    - label: "{inferred_scope_2}"
      description: "{file count} files — {rationale}"
    - label: "Entire project"
      description: "All source files (use with caution)"
```

**Scope validation rules:**
- Scope must resolve to at least 1 file (run glob, confirm matches)
- Warn if scope exceeds 50 files (agent context may struggle)
- Warn if scope includes test files AND source files (prefer separating)

### Phase 4: Define Metric

This is the critical step. The metric must be **mechanical** — extractable from a command output as a single number.

Present metric options based on goal + tooling:

```
question:
  question: "What number tells you if things got better? Pick the mechanical metric."
  header: "Metric"
  options:
    - label: "{metric_1} (Recommended)"
      description: "{what it measures} — extracted via: {command snippet}"
    - label: "{metric_2}"
      description: "{what it measures} — extracted via: {command snippet}"
    - label: "{metric_3}"
      description: "{what it measures} — extracted via: {command snippet}"
```

**Metric validation rules (CRITICAL):**

| Check | Pass | Fail |
|-------|------|------|
| Outputs a number | `87.3`, `0.95`, `42` | `PASS`, `looks good`, `✓` |
| Extractable by command | `grep`, `awk`, `jq` | Requires human judgment |
| Deterministic | Same input → same output | Random, flaky, time-dependent |
| Fast | < 30 seconds | > 2 minutes |

If metric fails validation, explain why and suggest alternatives. **Do not proceed until metric is mechanical.**

### Phase 4.5: Define Guard (Optional)

Ask if the user wants a guard command to prevent regressions:

```
question:
  question: "Do you want a guard command? This is a safety net that must ALWAYS pass — it prevents breaking existing behavior while optimizing."
  header: "Guard"
  options:
    - label: "Yes — run tests as guard (Recommended)"
      description: "{detected_test_command} must pass for every kept change"
    - label: "Yes — custom guard"
      description: "I'll provide my own guard command"
    - label: "No guard needed"
      description: "Skip — the metric is enough (e.g., test coverage where tests ARE the metric)"
```

**Guard suggestion rules:**
- If metric is performance/benchmark/bundle size → suggest `{test_command}` as guard
- If metric is Lighthouse/accessibility → suggest `{test_command}` as guard
- If metric is refactoring (LOC reduction) → suggest `{test_command} && {typecheck_command}` as guard
- If metric IS tests (coverage, pass count) → suggest "No guard needed" as default
- If no test runner detected → suggest "No guard needed" with note

**Guard validation:** If guard is set, run it once to confirm it passes on current codebase. If it fails, help user fix it before proceeding.

### Phase 5: Define Direction

```
question:
  question: "Is a higher or lower number better for your metric?"
  header: "Direction"
  options:
    - label: "Higher is better"
      description: "Coverage %, score, count of passing tests, throughput"
    - label: "Lower is better"
      description: "Error count, response time, bundle size, LOC"
```

### Phase 6: Define Verify Command

Construct the verification command that:
1. Runs the tool/test/benchmark
2. Extracts the metric as a single number
3. Exits 0 on success, non-zero on crash

Present the constructed command:

```
question:
  question: "This is the verify command I'll run each iteration. Does this look right?"
  header: "Verify"
  options:
    - label: "Looks good, use this (Recommended)"
      description: "{full_verify_command}"
    - label: "Modify it"
      description: "I'll adjust the command"
    - label: "I have my own command"
      description: "Let me provide a custom verify command"
```

**Verify validation (MANDATORY — run before accepting):**

1. **Dry run** the verify command on current codebase
2. Confirm it exits with code 0
3. Confirm output contains a parseable number
4. Record the baseline metric value
5. If dry run fails → show error, ask user to fix, re-validate

```
Dry run result:
  Exit code: {0 or error}
  Output snippet: {relevant line}
  Extracted metric: {number}
  Baseline: {number}
  Status: ✓ VALID / ✗ INVALID — {reason}
```

**Do not proceed if verify command fails dry run.** Help user fix it.

### Phase 7: Confirm & Launch

Present the complete configuration:

```markdown
## Autoresearch Configuration

**Goal:** {user's goal}
**Scope:** {glob pattern}
**Metric:** {metric name} ({direction})
**Verify:** `{command}`
**Guard:** `{guard_command}` *(or "none")*
**Baseline:** {value from dry run}

### Ready-to-use command:

/autoresearch
Goal: {goal}
Scope: {scope}
Metric: {metric} ({direction})
Verify: {verify_command}
Guard: {guard_command}
```

If no guard was set, omit the Guard line from the output.

Then ask:

```
question:
  question: "Configuration validated. How do you want to run it?"
  header: "Launch"
  options:
    - label: "Launch now — unlimited (Recommended)"
      description: "Start /autoresearch immediately, loop until interrupted"
    - label: "Launch now — bounded"
      description: "Run a fixed number of iterations (I'll ask how many)"
    - label: "Copy config only"
      description: "Just show me the command, I'll run it myself later"
```

If "Launch now — unlimited": invoke `/autoresearch` with the configuration.
If "Launch now — bounded": ask for iteration count, then invoke `/autoresearch` with `Iterations: N` in the inline config.
If "Copy config only": output the ready-to-paste command block and stop.

## Metric Suggestion Database

Use these as starting points based on detected domain/tooling:

### Code Quality
| Goal Pattern | Metric | Verify Template |
|---|---|---|
| test coverage | Coverage % | `{test_runner} --coverage \| grep "All files"` |
| type safety | `any` count | `grep -r ":\s*any" {scope} --include="*.ts" \| wc -l` |
| lint errors | Error count | `{linter} {scope} 2>&1 \| grep -c "error"` |
| build errors | Error count | `{build_cmd} 2>&1 \| grep -c "error"` |

### Performance
| Goal Pattern | Metric | Verify Template |
|---|---|---|
| bundle size | Size in KB | `{build_cmd} 2>&1 \| grep "First Load JS"` |
| response time | Time in ms | `{bench_cmd} \| grep "p95"` |
| lighthouse | Score 0-100 | `npx lighthouse {url} --output json --quiet \| jq '.categories.performance.score * 100'` |
| build time | Time in seconds | `time {build_cmd} 2>&1 \| grep real` |

### Content
| Goal Pattern | Metric | Verify Template |
|---|---|---|
| readability | Flesch score | `node scripts/readability.js {file}` |
| word count | Word count | `wc -w {scope}` |
| SEO score | Score 0-100 | `node scripts/seo-score.js {file}` |

### Refactoring
| Goal Pattern | Metric | Verify Template |
|---|---|---|
| reduce LOC | Line count | `{test_cmd} && find {scope} -name "*.ts" \| xargs wc -l \| tail -1` |
| reduce complexity | Cyclomatic complexity | `npx complexity-report {scope} \| grep "average"` |
| eliminate pattern | Pattern count | `grep -r "{pattern}" {scope} \| wc -l` |

## Error Recovery

| Error | Recovery |
|---|---|
| No test runner detected | Ask user for test command |
| Verify command fails | Show error, suggest fix, re-validate |
| Metric not parseable | Suggest adding `grep`/`awk` to extract number |
| Scope resolves to 0 files | Show glob result, ask user to fix pattern |
| Scope too broad (>100 files) | Suggest narrowing, warn about context limits |

## Anti-Patterns

- **Do NOT accept subjective metrics** — "looks better" is not a metric
- **Do NOT skip the dry run** — always validate verify command works
- **Do NOT suggest verify commands you haven't tested** — run it first
- **Do NOT overwhelm with questions** — max 5-6 questions total across all phases
- **Do NOT auto-launch without explicit user consent** — always confirm at Phase 7
