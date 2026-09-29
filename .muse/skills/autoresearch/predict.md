---
name: autoresearch:predict
description: "5 expert personas debate proposed changes before implementation"
argument-hint: "[Scope: <glob>] [Goal: <text>] [--depth shallow|standard|deep] [--adversarial] [--chain <targets>]"
---

EXECUTE IMMEDIATELY.

## Parse Arguments

Extract from $ARGUMENTS:
- `Scope:` or `--scope` — file globs to analyze
- `Goal:` or `--goal` — focus area for analysis
- `Depth:` or `--depth` — shallow (3 personas, 1 round), standard (5, 2), deep (8, 3)
- `--personas N` — override persona count (3-8)
- `--rounds N` — override debate rounds (1-3)
- `--adversarial` — use hostile reviewer personas instead of default
- `--budget N` — max findings across all personas (default 40)
- `--fail-on <severity>` — CI gate: exit non-zero if findings at/above threshold
- `--incremental` — reuse existing knowledge files, update only changed files
- `--chain`, `--<subcommand>`

Remaining text not matching flags = goal description.

## Setup (if Scope or Goal missing)

request_user_input (single batch):
  Q1 (Scope): "Which files to analyze?" — suggested globs + entire codebase
  Q2 (Goal): "What should personas focus on?" — code quality, security, performance, architecture, all
  Q3 (Depth): "How deep?" — shallow (3 personas, 1 round), standard (5, 2 — recommended), deep (8, 3)
  Q4 (Chain): "After analysis, chain to?" — debug, security, fix, ship, scenario, no chain
If all provided → skip.

## Phase 1: Reconnaissance

Scan all in-scope files. Build structured knowledge:
- File inventory with purpose annotations
- Dependency graph (imports/exports)
- API surface (routes, handlers, types)
- Data flow (inputs → processing → outputs → storage)
- Existing test coverage map

## Phase 2: Persona Generation

Load `references/predict-personas.md` for persona definitions.

**Default set (5):** Architect, Security Analyst, Performance Engineer, Reliability Engineer, Devil's Advocate.
**Adversarial set (--adversarial):** Breaker, Cheater, Scaler, Newbie, Malicious Insider.

Each persona receives: task description + codebase knowledge + their specific evaluation criteria.
Personas are isolated — no shared context between them.

## Phase 3: Independent Analysis

Each persona analyzes the codebase independently:
- Read relevant code through their lens
- Produce findings with: title, severity, confidence (0-100%), file:line, recommendation
- Max findings per persona: budget / persona_count

## Phase 4: Debate (per round)

For each debate round:
1. Present all personas' findings to each other
2. Each persona can: challenge findings, raise new issues, change confidence
3. Cross-examination: personas must respond to challenges with evidence
4. No persona can dismiss without counter-evidence

## Phase 5: Consensus

Synthesizer aggregates all findings:
1. Deduplicate (same file:line + same issue = merge, keep highest severity)
2. Resolve conflicts (if personas disagree, note dissent)
3. **Anti-herd check:** if all personas agree on everything, synthesizer MUST find at least 1 counter-argument
4. Rank by: severity × average confidence × persona agreement count

## Phase 6: Report

Create output directory: `autoresearch/predict-{YYMMDD}-{HHMM}/`

Write:
- `summary.md` — top findings, consensus view, risk assessment
- `debate.md` — full persona analysis + debate transcript
- Per-persona sections with individual findings

Print to console: top 10 findings ranked by severity × confidence.

## Phase 7: CI Gate

If `--fail-on` set: check findings against threshold. Exit non-zero if exceeded.

## Chain Handoff

Write handoff.json: version "2.1.0", source "predict", timestamp, status (COMPLETE|ERROR), findings = consensus findings with severity + confidence + file:line, config{scope, goal, depth}.
Invoke next target in --chain order.
