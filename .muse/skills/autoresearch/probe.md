---
name: autoresearch:probe
description: "8 personas interrogate requirements until constraints saturate"
argument-hint: "[Topic: <text>] [Scope: <glob>] [--depth shallow|standard|deep] [--personas N] [--mode interactive|autonomous] [Iterations: N] [--evals]"
---

EXECUTE IMMEDIATELY.

## Parse Arguments

Extract from $ARGUMENTS:
- `Topic:` — strip keyword, remaining text is topic (or full $ARGUMENTS if no keyword)
- `Scope:` or `--scope` — file globs for codebase grounding
- `Depth:` or `--depth` — shallow (5 rounds), standard (15), deep (30)
- `--personas N` or `Personas:` — active persona count (3-8, default 6)
- `--saturation-threshold N` — net-new constraints/round below which counts toward saturation (default 2)
- `--mode` or `Mode:` — interactive (default, uses request_user_input) or autonomous (self-answers from codebase)
- `--adversarial` — rotate hostile personas to front
- `Iterations:` or `--iterations` — default 15 rounds. "unlimited" for unbounded.
- `--evals`, `--evals-interval N`, `--chain`, `--<subcommand>`

## Setup (if Topic missing)

request_user_input (single batch):
  Q1 (Topic): "What to probe?" — open text describing feature, requirement, or design
  Q2 (Scope): "Which files for context?" — suggested globs + entire codebase
  Q3 (Depth): "How deep?" — shallow (5 rounds), standard (15), deep (30), unlimited
  Q4 (Mode): "How to answer persona questions?" — interactive (you answer), autonomous (agent infers from code)
If all provided → skip.

## 8 Personas

| # | Persona | Focus |
|---|---|---|
| 1 | Domain Expert | Business rules, domain constraints, terminology |
| 2 | End User | Usability, expectations, error recovery |
| 3 | Skeptic | Assumptions that might be wrong |
| 4 | Edge-Case Hunter | Boundary conditions, rare scenarios |
| 5 | Ops Engineer | Deployment, monitoring, scaling, failure modes |
| 6 | Security Reviewer | Attack vectors, data protection, auth |
| 7 | Contradiction Finder | Conflicts between requirements |
| 8 | Scope Guardian | Feature creep, unnecessary complexity |

If --adversarial: rotate Skeptic + Contradiction Finder + Edge-Case Hunter to front.

## Phase 1: Seed

- Parse topic into initial constraint set
- Read codebase context (if --scope provided)
- Initialize constraint registry (empty)

## Round Loop

### Phase 2: Persona Activation
- Select 2-3 personas for this round (rotate through all 8)
- Each persona generates 3-5 probing questions from their perspective

### Phase 3: Codebase Grounding
- Check questions against existing code for evidence
- Annotate questions with: relevant file:line, existing behavior, gaps

### Phase 4: Answer Capture
- **Interactive mode:** present questions via request_user_input, collect answers
- **Autonomous mode:** infer answers from codebase context, label confidence (high/medium/low)

### Phase 5: Constraint Extraction
- Parse answers into atomic constraints
- Each constraint: id, source persona, description, confidence, evidence
- Deduplicate against existing registry

### Phase 6: Cross-Check
- Check new constraints against existing for conflicts
- Flag contradictions for resolution (interactive → ask user, autonomous → note uncertainty)

### Phase 7: Saturation Check
- Count net-new constraints this round
- If net-new < saturation_threshold for 3 consecutive rounds → SATURATED, exit loop
- Track: total constraints, new this round, saturation window

### Phase 8: Log
Append to output: round number, personas active, questions asked, constraints extracted, net-new count

### Eval Checkpoint
If --evals: check if current_round % interval == 0 → run checkpoint.

### Bounded Check
If bounded: current_round >= max_iterations → exit loop.

## Phase 9: Synthesize & Output

Create output directory: `autoresearch/probe-{YYMMDD}-{HHMM}/`

1. Write `constraints.md` — full constraint registry organized by category
2. Write `conflicts.md` — unresolved contradictions
3. Generate ready-to-run autoresearch config:
   - Derived Goal, Scope, Metric, Verify from constraints
   - Include as code block in summary.md

Print: total rounds, constraints found, saturation status, unresolved conflicts.

## Summary

Print: total rounds, total constraints, net-new trend, saturation status, top 5 most impactful constraints.

## Eval Checkpoint (--evals flag)

If --evals present:
- Compute interval: floor(max_iterations / 3), min 1. Fixed 10 if unbounded.
- Print: `--- Eval Checkpoint (rounds {X}-{Y}) ---\nConstraints: {total} (+{new}) | Saturation: {window_count}/3\n{recommendation}\n---`
- If saturated 3+ checkpoints → recommend early stop.
- At loop end → full evals summary to evals-summary.md.

## Chain Handoff

Write handoff.json: version "2.1.0", source "probe", timestamp, status (COMPLETE|SATURATED|USER_INTERRUPT|BOUNDED|ERROR), findings = constraints, config = derived autoresearch config.
Invoke next target in --chain order. Propagate --evals flag.
