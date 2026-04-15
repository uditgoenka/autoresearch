---
name: autoresearch
description: Use when user types /autoresearch or asks to run an autonomous iteration loop against a goal/metric. Autonomous Goal-directed Iteration — modify, verify, keep/discard, repeat. Apply to ANY task with a measurable metric.
argument-hint: "[Goal: <text>] [Scope: <glob>] [Metric: <text>] [Verify: <cmd>] [Guard: <cmd>] [--iterations N]"
---

EXECUTE IMMEDIATELY — do not deliberate, do not ask clarifying questions before reading the protocol.

## Argument Parsing (do this FIRST, before reading any files)

Extract these from $ARGUMENTS — the user may provide extensive context alongside config. Ignore prose and extract ONLY structured fields:

- `Goal:` — text after "Goal:" keyword
- `Scope:` or `--scope <glob>` — file globs after "Scope:" keyword
- `Metric:` — text after "Metric:" keyword
- `Verify:` — shell command after "Verify:" keyword
- `Guard:` — shell command after "Guard:" keyword (optional)
- `Iterations:` or `--iterations` — integer N for bounded mode (CRITICAL: if set, you MUST run exactly N iterations then stop)

If `Iterations: N` or `--iterations N` is found, set `max_iterations = N`. Track `current_iteration` starting at 0. After iteration N, print final summary and STOP.

## Execution

1. Read the autonomous loop protocol: `.claude/skills/autoresearch/references/autonomous-loop-protocol.md`
2. Read the results logging format: `.claude/skills/autoresearch/references/results-logging.md`
3. If Goal, Scope, Metric, and Verify are all extracted — proceed directly to loop setup
4. If any critical field is missing — use `AskUserQuestion` with batched questions as defined in SKILL.md "Interactive Setup" section
5. Execute the autonomous loop: Modify → Verify → Keep/Discard → Repeat
6. If bounded: after each iteration, check `current_iteration < max_iterations`. If not, STOP and print summary.

IMPORTANT: Start executing immediately. Stream all output live — never run in background. Never stop early unless goal achieved or max_iterations reached.
