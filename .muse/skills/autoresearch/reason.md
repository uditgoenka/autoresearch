---
name: autoresearch:reason
description: "Adversarial debate with blind judges until convergence"
argument-hint: "[Task: <question>] [Domain: <type>] [--mode convergent|creative|debate] [--judges N] [Iterations: N] [--evals]"
---

EXECUTE IMMEDIATELY.

## Parse Arguments

Extract from $ARGUMENTS:
- `Task:` — question, proposal, design, argument, or claim to refine
- `Domain:` or `--domain` — software, product, business, security, research, content
- `Mode:` or `--mode` — convergent (default), creative, debate
- `--judges N` or `Judges:` — blind judge count (3 default, 5 thorough, 7 deep)
- `--convergence N` or `Convergence:` — stop when incumbent wins N consecutive rounds (default 3)
- `Iterations:` or `--iterations` — default 8. "unlimited" for unbounded.
- `--judge-personas` — custom judge persona overrides
- `--no-synthesis` — skip synthesis, pure debate only
- `--temperature` — generation temperature hint
- `--evals`, `--evals-interval N`, `--chain`, `--<subcommand>`

Remaining text not matching flags = task description.

## Setup (if Task or Domain missing)

request_user_input (single batch):
  Q1 (Task): "What should be reasoned about?" — open text
  Q2 (Domain): "What domain?" — software architecture, product strategy, business decision, security, research, content
  Q3 (Mode): "Refinement mode?" — convergent (stop when winner repeats), creative (never auto-stop), debate (no synthesis)
  Q4 (Judges): "How many blind judges?" — 3 (default), 5 (thorough), 7 (deep)
If all provided → skip.

## Setup Phase

1. Load `references/reason-judge-protocol.md` for judge and convergence specs
2. Parse domain → select domain-specific judge criteria
3. Create output directory: `autoresearch/reason-{YYMMDD}-{HHMM}/`
4. TSV header: `round\ttimestamp\tcandidate_label\tjudge_verdict\tconvergence_count\tdescription`
5. Initialize: incumbent = null, convergence_count = 0

## Round Loop

### Phase 1: Generate-A
- If round 1: Author-A generates first candidate from task description
- If round N>1: incumbent is Author-A's candidate
- Cold-start: Author-A sees ONLY task description + domain context

### Phase 2: Critic
- Critic receives candidate-A (cold-start, no shared session)
- MUST find at least 3 specific weaknesses
- MUST suggest what a superior candidate would do differently
- Role is purely adversarial — never compliment

### Phase 3: Generate-B
- Author-B receives: task + candidate-A + critique (cold-start)
- Produces candidate-B addressing critique while preserving A's strengths

### Phase 4: Synthesize (unless --no-synthesis or debate mode)
- Synthesizer receives: task + A + B (cold-start)
- Produces hybrid candidate-AB merging best of both

### Phase 5: Blind Judge Panel
- Each judge receives 3 candidates with RANDOMIZED labels (Label-X, Label-Y, Label-Z)
- Judges evaluate independently on domain-specific criteria
- Each produces ranking + one-paragraph justification
- Verdict: majority vote. Tie → synthesized candidate wins.

### Phase 6: Convergence Check
- If winner == incumbent → convergence_count++
- If winner != incumbent → convergence_count = 1, winner becomes incumbent
- **Convergent mode**: convergence_count >= N → CONVERGED, stop
- **Creative mode**: never auto-stop
- **Debate mode**: same as convergent, no synthesis

### Phase 7: Oscillation Guard
If incumbent changed 5+ times in last 8 rounds → recommend early stop (not converging).

### Phase 8: Log
Append to TSV: round, timestamp, winning candidate label, judge verdict, convergence_count, description

### Eval Checkpoint
If --evals: check if current_round % interval == 0 → run checkpoint.

### Bounded Check
If bounded: current_round >= max_iterations → exit loop.

## Output

- `reason-results.tsv` — per-round results
- `lineage.md` — full history of candidates + critiques + judge reasoning
- `summary.md` — final winner, convergence trajectory, key insights

## Summary

Print: total rounds, convergence status, final winner summary, judge agreement rate.

## Eval Checkpoint (--evals flag)

If --evals present:
- Compute interval: floor(max_iterations / 3), min 1. Fixed 10 if unbounded.
- Print: `--- Eval Checkpoint (rounds {X}-{Y}) ---\nIncumbent: {label} | Convergence: {count}/{target} | Oscillations: {n}\n{recommendation}\n---`
- If oscillation detected 3+ checkpoints → recommend early stop.
- At loop end → full evals summary to evals-summary.md.

## Chain Handoff

After completion, write handoff.json: version "2.1.0", source "reason", timestamp, status (COMPLETE|CONVERGED|USER_INTERRUPT|BOUNDED|ERROR), results_tsv path, findings = [{id, type: "recommendation", summary: winner description}], config{task, domain, mode}.
Invoke next target in --chain order. Propagate --evals flag.
