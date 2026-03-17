---
name: autoresearch:scenario
description: Scenario-driven use case generator — explores situations, edge cases, and derivative scenarios from a seed scenario using autonomous iteration.
argument-hint: "[scenario description] [--scope <glob>] [--depth shallow|standard|deep] [--domain <type>] [--iterations N]"
---

Load and follow the autoresearch scenario workflow protocol.

1. Read the skill file: `.claude/skills/autoresearch/SKILL.md` — understand the overall autoresearch framework
2. Read the scenario workflow reference: `.claude/skills/autoresearch/references/scenario-workflow.md` — this is the FULL protocol to follow
3. Parse any flags from the user's arguments: $ARGUMENTS
4. Execute the 7-phase scenario loop as defined in `scenario-workflow.md`

Follow the scenario workflow protocol exactly. Every scenario requires a concrete context (who, what, when, where) and measurable coverage across happy path, edge cases, failure modes, and adversarial inputs. Every derivative scenario is logged — breadth and depth both matter.
