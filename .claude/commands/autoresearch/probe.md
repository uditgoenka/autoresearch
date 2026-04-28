---
name: autoresearch:probe
description: Use when user types /autoresearch:probe or asks for adversarial requirement / assumption interrogation. Multi-persona probe loop that interrogates user and codebase until net-new constraints saturate, then emits ready-to-run autoresearch config. Output feeds any other autoresearch command via --chain.
argument-hint: "[topic/goal] [--depth shallow|standard|deep] [--personas N] [--saturation-threshold N] [--scope <glob>] [--chain <targets>] [--mode interactive|autonomous] [--adversarial] [--iterations N]"
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, Agent, WebSearch, WebFetch
---

EXECUTE IMMEDIATELY — do not deliberate, do not ask clarifying questions before reading the protocol.

## Argument Parsing (do this FIRST)

Extract these from $ARGUMENTS — the user may provide extensive context alongside flags. Ignore prose and extract ONLY flags/config:

- `--depth <level>` or `Depth:` — shallow (5 rounds), standard (15 rounds), deep (30 rounds)
- `--personas N` or `Personas:` — active persona count (3-8, default 6)
- `--saturation-threshold N` or `Saturation-Threshold:` — net-new atoms/round below which a round counts toward saturation (default 2, window K=3)
- `--scope <glob>` or `Scope:` — codebase glob for Phase 3 grounding
- `--chain <targets>` or `Chain:` — comma-separated downstream commands (plan, predict, debug, fix, scenario, reason, ship, learn)
- `--mode <mode>` or `Mode:` — interactive (default — uses AskUserQuestion) or autonomous (self-answers from codebase context with confidence labels)
- `--adversarial` — rotate Skeptic + Contradiction Finder + Edge-Case Hunter to the front of persona ordering
- `--iterations N` or `Iterations:` — bounded mode: hard cap on rounds, overrides `--depth`
- `Topic:` prefix — strip it, treat trailing text as the topic

If `Iterations: N` or `--iterations N` is found, set `max_iterations = N`. Track `current_round` starting at 0. After round N, print final summary and STOP with status BOUNDED.

All remaining text not matching flags is the topic / goal description.

## Execution

1. Read the probe workflow: `.claude/skills/autoresearch/references/probe-workflow.md`
2. If topic, depth, or personas is missing — use `AskUserQuestion` with batched adaptive questions per probe-workflow.md PREREQUISITE Interactive Setup section
3. Execute the 10-phase probe workflow (Seed → Persona Activation → Codebase Grounding → Round Generation → Synthesis → Answer Capture → Constraint Extraction → Cross-Check → Saturation Check → Synthesize & Handoff)
4. After each round, run Phase 9 saturation check. If `SATURATED`, `BOUNDED`, `USER_INTERRUPT`, or `SCOPE_LOCKED` → enter Phase 10 and STOP.
5. If `--chain` is set, hand off `handoff.json` to each chained command sequentially per probe-workflow.md Chaining Examples section.

Stream all output live — never run in background.
