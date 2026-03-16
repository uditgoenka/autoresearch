---
name: autoresearch
description: Autonomous Goal-directed Iteration. Modify, verify, keep/discard, repeat. Apply to ANY task with a measurable metric.
argument-hint: "[Goal: <text>] [Scope: <glob>] [Metric: <text>] [Verify: <cmd>]"
---

Load and follow the autoresearch autonomous loop protocol.

1. Read the skill file: `.claude/skills/autoresearch/SKILL.md` — understand the full framework, setup phase, and critical rules
2. Read the core principles: `.claude/skills/autoresearch/references/core-principles.md`
3. Read the autonomous loop protocol: `.claude/skills/autoresearch/references/autonomous-loop-protocol.md`
4. Read the results logging format: `.claude/skills/autoresearch/references/results-logging.md`
5. Parse any inline config from the user's arguments: $ARGUMENTS
6. If Goal, Scope, Metric, and Verify are all provided — extract them and proceed to setup step 5
7. If any critical field is missing — run the interactive setup with batched `AskUserQuestion` calls as defined in SKILL.md
8. Execute the autonomous loop: Modify → Verify → Keep/Discard → Repeat

Follow the protocol exactly. One atomic change per iteration. Mechanical verification only. Auto-rollback on failure.
