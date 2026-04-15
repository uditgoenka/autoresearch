---
description: Use when user types /autoresearch_debug or asks to hunt bugs / find root cause iteratively. Autonomous bug-hunting loop — scientific method + autoresearch iteration. Finds ALL bugs, not just one.
agent: build
---

EXECUTE IMMEDIATELY — do not deliberate, do not ask clarifying questions before reading the protocol.

## Argument Parsing (do this FIRST)

Extract these from $ARGUMENTS — the user may provide extensive context alongside flags. Ignore prose and extract ONLY flags/config:

- `--fix` — if present, auto-switch to /autoresearch_fix after finding bugs
- `--scope <glob>` or `Scope:` — file globs to investigate
- `--symptom "<text>"` or `Symptom:` — description of what's broken
- `--severity <level>` — minimum severity to report (critical/high/medium/low)
- `--technique <name>` — force a specific investigation technique (binary-search, differential, minimal-reproduction, trace, pattern-search, working-backwards, rubber-duck)
- `Iterations:` or `--iterations N` — integer for bounded mode (CRITICAL: run exactly N iterations then stop)

If `Iterations: N` or `--iterations N` is found, set `max_iterations = N`. Track `current_iteration` starting at 0. After iteration N, print final summary and STOP.

All remaining text in $ARGUMENTS is additional context — use it to understand the problem but do not treat it as flags.

## Execution

1. Read the debug workflow: `.opencode/skills/autoresearch/references/debug-workflow.md`
2. If scope or symptom is missing — use `question` with batched questions per debug-workflow.md
3. Execute the 7-phase debug loop
4. If bounded: after each iteration, check `current_iteration < max_iterations`. If not, STOP and print summary.

Stream all output live — never run in background.
