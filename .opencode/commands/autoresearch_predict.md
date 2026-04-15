---
description: Use when user types /autoresearch_predict or asks for multi-persona pre-analysis. Multi-persona swarm prediction — pre-analyze code from multiple expert perspectives using file-based knowledge representation. Zero external dependencies.
agent: build
---

EXECUTE IMMEDIATELY — do not deliberate, do not ask clarifying questions before reading the protocol.

## Argument Parsing (do this FIRST)

Extract these from $ARGUMENTS — the user may provide extensive context alongside flags. Ignore prose and extract ONLY flags/config:

- `--scope <glob>` or `Scope:` — file globs to analyze
- `--chain <targets>` or `Chain:` — comma-separated: debug,security,fix,ship,scenario
- `--depth <level>` or `Depth:` — shallow (3 personas, 1 round), standard (5, 2), deep (8, 3)
- `--personas N` — number of personas (3-8)
- `--rounds N` — debate rounds (1-3)
- `--adversarial` — use red team personas
- `--budget <N>` — max total findings across all personas (default: 40)
- `--fail-on <severity>` — CI/CD gate
- `--incremental` — reuse existing knowledge files, update only changed files
- `--goal <text>` or `Goal:` — focus area for analysis
- `Iterations:` or `--iterations N` — integer for bounded mode (CRITICAL: run exactly N iterations then stop)

If `Iterations: N` or `--iterations N` is found, set `max_iterations = N`. Track `current_iteration` starting at 0. After iteration N, print final summary and STOP.

All remaining text not matching flags is the goal/focus description.

## Execution

1. Read the predict workflow: `.opencode/skills/autoresearch/references/predict-workflow.md`
2. If scope or goal is missing — use `question` with batched questions per predict-workflow.md
3. Execute the 8-phase predict workflow
4. If bounded: after each iteration, check `current_iteration < max_iterations`. If not, STOP and print summary.
5. If `--chain` is set, hand off to each chained command sequentially

Stream all output live — never run in background.
