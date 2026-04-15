---
description: Use when user types /autoresearch_reason or asks for adversarial generate-critique-synthesize refinement. Isolated multi-agent adversarial refinement — generate, critique, synthesize, repeat until convergence.
agent: build
---

EXECUTE IMMEDIATELY — do not deliberate, do not ask clarifying questions before reading the protocol.

## Argument Parsing (do this FIRST)

Extract these from $ARGUMENTS — the user may provide extensive context alongside flags. Ignore prose and extract ONLY flags/config:

- `--scope <glob>` or `Scope:` — file globs for context
- `--depth <level>` or `Depth:` — shallow (1 round), standard (2 rounds), deep (3 rounds)
- `--domain <type>` or `Domain:` — code, architecture, strategy, research, general
- `--adversarial` — maximize dissent between agents
- `Task:` — the task/question to reason about
- `Iterations:` or `--iterations N` — integer for bounded mode (CRITICAL: run exactly N iterations then stop)

If `Iterations: N` or `--iterations N` is found, set `max_iterations = N`. Track `current_iteration` starting at 0. After iteration N, print final summary and STOP.

All remaining text not matching flags is the task/question.

## Execution

1. Read the reason workflow: `.opencode/skills/autoresearch/references/reason-workflow.md`
2. If task or domain is missing — use `question` with adaptive questions per reason-workflow.md
3. Execute the multi-agent adversarial refinement loop
4. If bounded: after each iteration, check `current_iteration < max_iterations`. If not, STOP and print summary.

Stream all output live — never run in background.
