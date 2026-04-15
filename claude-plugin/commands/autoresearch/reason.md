---
name: autoresearch:reason
description: Use when user types /autoresearch:reason or asks for adversarial generate-critique-synthesize refinement. Isolated multi-agent adversarial refinement — generate, critique, synthesize, and judge outputs through repeated rounds until convergence. Produces a lineage of evolving candidates with documented decision rationale.
argument-hint: "[task/question] [--domain <domain>] [--mode convergent|creative|debate] [--judges N] [--iterations N] [--convergence N] [--chain debug|plan|fix|scenario|predict|ship|learn]"
---

EXECUTE IMMEDIATELY — do not deliberate, do not ask clarifying questions before reading the protocol.

## Argument Parsing (do this FIRST)

Extract these from $ARGUMENTS — the user may provide extensive context alongside flags. Ignore prose and extract ONLY flags/config:

- `--domain <domain>` or `Domain:` — subject domain (software, product, security, research, content, etc.)
- `--mode <mode>` or `Mode:` — convergent (default), creative, debate
- `--judges N` or `Judges:` — number of blind judges (3 default, 5 thorough, 7 deep)
- `--iterations N` or `Iterations:` — bounded mode: run exactly N refinement rounds then stop
- `--convergence N` or `Convergence:` — stop when winner repeats N times (default: 3)
- `--chain <targets>` or `Chain:` — comma-separated tools to chain after convergence
- `--judge-personas <list>` — custom judge persona overrides
- `--no-synthesis` — skip synthesis phase, pure debate only
- `--temperature <value>` — generation temperature hint

If `Iterations: N` or `--iterations N` is found, set `max_iterations = N`. Track `current_iteration` starting at 0. After iteration N, print final summary and STOP.

All remaining text not matching flags is the task/question description.

## Execution

1. Read the reason workflow: `.claude/skills/autoresearch/references/reason-workflow.md`
2. If task, domain, or mode is missing — use `AskUserQuestion` with batched questions per reason-workflow.md
3. Execute the multi-phase reason workflow
4. If bounded: after each iteration, check `current_iteration < max_iterations`. If not, STOP and print summary.
5. If `--chain` is set, hand off to each chained command sequentially

Stream all output live — never run in background.
