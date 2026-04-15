---
name: autoresearch:plan
description: Use when user types /autoresearch:plan or asks to turn a goal into Scope/Metric/Direction/Verify. Interactive wizard that builds the full autoresearch config from a single Goal.
argument-hint: "[goal description]"
---

EXECUTE IMMEDIATELY — do not deliberate, do not ask clarifying questions before reading the protocol.

## Argument Parsing (do this FIRST)

Extract the goal from $ARGUMENTS. The user may provide extensive context — treat the entire text as goal context. Look for `Goal:` keyword; if absent, the full $ARGUMENTS text IS the goal.

## Execution

1. Read the plan workflow: `.claude/skills/autoresearch/references/plan-workflow.md`
2. Execute the 7-step planning wizard

Stream all output live — never run in background.
