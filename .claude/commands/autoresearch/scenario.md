---
name: autoresearch:scenario
description: Use when user types /autoresearch:scenario or asks to explore edge cases from a seed scenario. Scenario-driven use case generator — explores situations, edge cases, and derivative scenarios from a seed scenario using autonomous iteration.
argument-hint: "[scenario description] [--scope <glob>] [--depth shallow|standard|deep] [--domain <type>] [--format <type>] [--focus <area>] [--iterations N]"
---

EXECUTE IMMEDIATELY — do not deliberate, do not ask clarifying questions before reading the protocol.

## Argument Parsing (do this FIRST)

Extract these from $ARGUMENTS — the user may provide extensive context alongside flags. Ignore prose and extract ONLY flags/config:

- `--domain <type>` or `Domain:` — software, product, business, security, marketing
- `--depth <level>` or `Depth:` — shallow (10 iterations), standard (25), deep (50+)
- `--scope <glob>` or `Scope:` — file globs
- `--format <type>` — use-cases, user-stories, test-scenarios, threat-scenarios
- `--focus <area>` — edge-cases, failures, security, scale
- `Iterations:` or `--iterations N` — integer for bounded mode (CRITICAL: run exactly N iterations then stop). Overrides depth preset.
- `Scenario:` — text after "Scenario:" keyword

All remaining text not matching flags is the scenario description.

If `Iterations: N` or `--iterations N` is found, set `max_iterations = N`. Track `current_iteration`. After N, STOP.

## Execution

1. Read the scenario workflow: `.claude/skills/autoresearch/references/scenario-workflow.md`
2. If scenario or domain is missing — use `AskUserQuestion` with adaptive questions per scenario-workflow.md
3. Execute the 7-phase scenario loop
4. If bounded: after each iteration, check `current_iteration < max_iterations`. If not, STOP and print summary.

Stream all output live — never run in background.
