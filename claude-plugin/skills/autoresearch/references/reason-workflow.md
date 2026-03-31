# Reason Workflow — /autoresearch:reason

Isolated multi-agent adversarial refinement for subjective domains. Generates, critiques, synthesizes, and judges outputs through repeated rounds until convergence — producing a lineage of evolving candidates with documented decision rationale.

**Core idea:** Generate-A → Critic attacks A → Generate-B from task+A+critique → Synthesize-AB → Blind judge panel picks winner → winner becomes new A → repeat until convergence. Every agent is cold-start fresh with no shared session — prevents sycophancy. Judges receive randomized candidate labels and must compare, not praise.

## Trigger

- User invokes `/autoresearch:reason`
- User says "reason through this", "adversarial refinement", "debate and converge", "iterative argument", "multi-agent critique", "blind judging"
- User wants subjective quality improvement with documented rationale (architecture proposals, argument quality, content polish, design decisions, research hypotheses)
- Chained from another autoresearch tool via `--chain reason`

## Loop Support

```
# Unlimited — keep refining until convergence or interrupted
/autoresearch:reason

# Bounded — exactly N refinement rounds
/autoresearch:reason
Iterations: 10

# With task
/autoresearch:reason
Task: Should we use event sourcing for our order management system?
Domain: software
```

## PREREQUISITE: Interactive Setup (when invoked without full context)

**CRITICAL — BLOCKING PREREQUISITE:** If `/autoresearch:reason` is invoked without task, domain, and mode all provided, you MUST use `AskUserQuestion` to gather context BEFORE proceeding to Phase 1. DO NOT skip this step.

**TOOL AVAILABILITY:** `AskUserQuestion` may be a deferred tool. If calling it fails, use `ToolSearch` to fetch the schema first, then retry.

**Adaptive question selection rules:**
- No input at all → ask all 5 questions
- Task provided but no domain → ask questions 2, 3, 4, 5
- Task + domain provided but no convergence/mode → ask questions 3, 4, 5
- Task + domain + mode + convergence all provided → skip setup entirely

Batch ALL selected questions into a SINGLE `AskUserQuestion` call:

| # | Header | Question | When to Ask | Options |
|---|--------|----------|-------------|---------|
| 1 | `Task` | "What should be reasoned about? (a question, proposal, design, argument, or claim)" | If no task provided | Open text |
| 2 | `Domain` | "What domain is this in?" | If no `--domain` | "Software architecture", "Product strategy", "Business decision", "Security approach", "Research hypothesis", "Content/writing", "Other" |
| 3 | `Mode` | "What refinement mode?" | If no `--mode` | "Convergent (default) — stop when winner repeats N times", "Creative — keep exploring, never auto-stop", "Debate — pure argument quality, no synthesis" |
| 4 | `Judges` | "How many blind judges?" | If no `--judges` | "3 judges (default)", "5 judges (thorough)", "7 judges (deep)" |
| 5 | `Chain` | "Chain to another tool after convergence?" | If no `--chain` | "debug", "plan", "fix", "scenario", "predict", "ship", "learn", "No chain — report only" |

**Skip setup entirely when:** Task + Domain + Mode all provided inline or via flags. Proceed to Phase 1.

## Inline Context Parsing

Parse in this order (flags take precedence):

1. **Flags first:** `--iterations`, `--judges`, `--convergence`, `--mode`, `--domain`, `--chain`, `--judge-personas`, `--no-synthesis`, `--temperature`
2. **YAML config block:** `Task:`, `Domain:`, `Mode:`, `Iterations:`, `Judges:`, `Chain:`, `Convergence:`
3. **Remaining text:** treat as the task description if not matched to a flag

## Architecture

```
/autoresearch:reason
  ├── Phase 1: Setup — Interactive gate + config validation
  ├── Phase 2: Generate-A — Author-A produces first candidate
  ├── Phase 3: Critic — Adversarial attack on A (forced weaknesses)
  ├── Phase 4: Generate-B — Author-B sees task+A+critique, produces B
  ├── Phase 5: Synthesize-AB — Synthesizer produces AB from task+A+B
  ├── Phase 6: Judge Panel — N blind judges pick winner (randomized labels)
  ├── Phase 7: Convergence Check — stop if incumbent wins N consecutive rounds
  └── Phase 8: Handoff — write lineage files, optional --chain
```

## Phase 1: Setup — Configuration

**STOP: Have you completed the Interactive Setup above?** Complete `AskUserQuestion` before entering this phase.

Parse and validate:
- `--iterations N`: bounded mode — run exactly N rounds then stop (overrides convergence)
- `--judges N`: judge count. Default: 3. Range: 3-7. Odd numbers preferred (majority vote)
- `--convergence N`: consecutive rounds incumbent must win to stop. Default: 3. Range: 2-5
- `--mode`: convergent (default) | creative | debate
  - `convergent`: stop when incumbent wins `--convergence` consecutive rounds
  - `creative`: never auto-stop — generate diverse candidates, no convergence gate
  - `debate`: no synthesis step, judges evaluate A vs B directly
- `--domain`: shapes judge persona expertise (software, product, business, security, research, content)
- `--chain`: validate targets. Supports comma-separated multi-chain. Known targets: debug, plan, fix, security, scenario, predict, ship, learn
- `--no-synthesis`: skip Phase 5, judge A vs B only (equivalent to `--mode debate`)
- `--judge-personas <list>`: override default judge personas with custom list

Create output directory: `reason/{YYMMDD}-{HHMM}-{slug}/`

Initialize state:
```
incumbent = null   (no winner yet — first round has no incumbent)
round = 0
consecutive_wins = 0
lineage = []
```

**Output:** `✓ Phase 1: Setup — task defined, [N] judges, convergence=[K], mode=[mode]`

## Phase 2: Generate-A — First Candidate

### Round 1 (no incumbent)

Author-A receives **only** the task. No prior candidates. No history. Cold-start context.

**Author-A prompt template:**

```
Task: {task_description}
Domain: {domain}

Produce a high-quality response to this task. Be thorough, concrete, and well-reasoned.
Do NOT hold back — this is your best attempt.

CONSTRAINTS:
- No hedging language ("perhaps", "maybe", "it depends") unless genuinely uncertain
- Every claim must be supported by reasoning or evidence
- If this is a design/architecture task: specify components, interfaces, and tradeoffs explicitly
- If this is an argument/decision task: state your position clearly, then defend it
- Length: appropriate for depth of task — not artificially long or short
```

**Round 2+ (incumbent exists)**

Author-A receives the current incumbent (the winner of the previous round). Author-A's role is to BUILD ON and IMPROVE the incumbent, not reproduce it.

```
Task: {task_description}
Domain: {domain}
Current best candidate (do not reproduce verbatim — build on it):

---
{incumbent_text}
---

Your role: Improve this candidate. Identify its weaknesses (from prior critique context if relevant)
and produce a version that addresses them. You may restructure, extend, prune, or reframe.
Do NOT simply paraphrase. Produce a genuinely better version.
```

**Output:** `✓ Phase 2: Generate-A — candidate A produced ([word_count] words)`

## Phase 3: Critic — Adversarial Attack

The Critic receives **only** candidate A. No task description to prevent task-anchoring. No incumbent history. Cold-start context.

**Context isolation invariant:** Critic MUST NOT see previous rounds, Author-B's outputs, or judge transcripts. Fresh context only.

**Critic prompt template:**

```
You are an adversarial critic. Your job is to ATTACK the following candidate ruthlessly.

Candidate:
---
{candidate_A}
---

RULES:
1. Find MINIMUM 3 distinct weaknesses (more is better)
2. Each weakness must be SPECIFIC — quote or reference the exact claim, section, or reasoning you're attacking
3. Weaknesses must be SUBSTANTIVE — not stylistic nitpicks unless the style undermines comprehension
4. Do NOT offer fixes — only attack. The Author-B role will respond to your critique
5. Rate each weakness by impact: FATAL (invalidates the argument), MAJOR (significant gap), MINOR (improvable)
6. End with a one-line "Verdict" sentence summarizing the weakest point overall

Output format:
WEAKNESS-1 [FATAL|MAJOR|MINOR]: {specific claim or section} — {critique}
WEAKNESS-2 [FATAL|MAJOR|MINOR]: ...
...
WEAKNESS-N [FATAL|MAJOR|MINOR]: ...
VERDICT: {one-line summary of the most critical weakness}
```

**Output:** `✓ Phase 3: Critic — [N] weaknesses found ([fatal], [major], [minor])`

## Phase 4: Generate-B — Challenger Candidate

Author-B receives the task AND candidate A AND the critique. Author-B's role is to produce a BETTER candidate by learning from the critique without being told what the "right answer" is.

**Context isolation invariant:** Author-B does NOT see prior rounds. Fresh context with task + A + critique only.

**Author-B prompt template:**

```
Task: {task_description}
Domain: {domain}

Here is a previous attempt at this task:
---
CANDIDATE A:
{candidate_A}
---

Here is an adversarial critique of Candidate A:
---
CRITIQUE:
{critique}
---

Your role: Produce a BETTER candidate (Candidate B) that addresses the critique's weaknesses
while preserving what Candidate A did well.

CONSTRAINTS:
- Address at least the FATAL and MAJOR weaknesses from the critique
- Do NOT simply patch A — rethink structure and reasoning where the critique reveals deeper issues
- Do NOT reference the critique explicitly ("as the critique noted...") — integrate the improvements naturally
- Do NOT reproduce A verbatim — your candidate must be substantively different
- Every claim must be supported by reasoning or evidence
- Avoid over-correcting: if a MINOR weakness was stylistic, don't restructure the entire response for it
```

**Output:** `✓ Phase 4: Generate-B — candidate B produced ([word_count] words)`

## Phase 5: Synthesize-AB — Composite Candidate

The Synthesizer receives the task AND both A and B. It produces a third candidate (AB) that is BETTER than either by combining the best elements of both.

**This phase is skipped when:** `--mode debate` or `--no-synthesis` flag.

**Context isolation invariant:** Synthesizer MUST NOT see the critique or judge history. Receives task + A + B only.

**Synthesizer prompt template:**

```
Task: {task_description}
Domain: {domain}

You have two candidate responses to this task:
---
CANDIDATE A:
{candidate_A}
---
CANDIDATE B:
{candidate_B}
---

Your role: Produce CANDIDATE AB — a synthesis that is superior to both A and B.

CONSTRAINTS:
1. Identify what A does better than B (specific strengths)
2. Identify what B does better than A (specific strengths)
3. Combine the strongest elements — do NOT average them into mediocrity
4. Resolve any direct contradictions by reasoning through which position is better supported
5. The result must be COHERENT — not a patchwork. It should read as a single unified response
6. Do NOT invent new claims that neither A nor B supports — synthesize only from what exists
7. Do NOT hedge contradictions — pick a position and defend it

Begin with a 2-3 sentence internal monologue (in [brackets]) explaining what you're taking from each,
then produce the full synthesized candidate.
```

**Output:** `✓ Phase 5: Synthesize-AB — candidate AB produced ([word_count] words)`

## Phase 6: Judge Panel — Blind Evaluation

N judges evaluate candidates using randomized labels. Judges never know which label maps to which candidate.

### Label Randomization Protocol

Before dispatching judges:
1. Generate a random permutation of candidate IDs: e.g., `shuffle([A, B, AB])` → `[AB, A, B]`
2. Assign display labels: `X = AB`, `Y = A`, `Z = B` (example — reshuffled each round)
3. Judges see only X, Y, Z — never A, B, AB
4. Label mapping stored internally in `reason-lineage.jsonl` only — never revealed to judges mid-evaluation
5. **Why:** Prevents judges from anchoring on "the synthesis is always better" — forces genuine comparative evaluation

### Judge Count by Mode

| `--judges` | Judges Dispatched | Majority Threshold |
|-----------|------------------|-------------------|
| 3 (default) | 3 | ≥2 votes |
| 5 | 5 | ≥3 votes |
| 7 | 7 | ≥4 votes |

In `--mode debate` (no AB): judges evaluate X vs Y only (A vs B under randomized labels).

### Judge Prompt Template

```
You are an expert evaluator in {domain}.

Task: {task_description}

Below are {N} candidate responses. Labels are arbitrary — do NOT assume ordering implies quality.
---
CANDIDATE X:
{candidate_X_text}

---
CANDIDATE Y:
{candidate_Y_text}

---
{if not debate mode}
CANDIDATE Z:
{candidate_Z_text}
{/if}
---

EVALUATION RULES:
1. You MUST pick a winner. "Tie" is not acceptable — force-rank if close
2. Evaluate on: accuracy/correctness, completeness, reasoning quality, practical applicability
3. Domain-specific criteria apply: {domain_criteria}
4. Your reasoning must cite SPECIFIC text from the candidates (quote or reference)
5. DO NOT pick based on length — longer is not better
6. DO NOT pick based on style — substance wins

Output format:
WINNER: X | Y | Z
RUNNER-UP: X | Y | Z
REASONING: {2-4 sentences citing specific evidence}
WINNING_STRENGTH: {the single strongest element of the winner}
RUNNER_UP_GAP: {the specific gap that prevented runner-up from winning}
```

### Domain Criteria Injection

| Domain | Criteria |
|--------|---------|
| `software` | Correctness, feasibility, edge case coverage, maintainability tradeoffs |
| `product` | User value clarity, feasibility, prioritization rationale, metrics |
| `business` | ROI reasoning, risk awareness, stakeholder consideration, actionability |
| `security` | Threat coverage, defense-in-depth, real attack scenario validity |
| `research` | Hypothesis clarity, falsifiability, methodology soundness, novelty |
| `content` | Clarity, audience fit, argument strength, factual accuracy |

### Vote Tallying

1. Decode each judge's winner vote back to A/B/AB using the label map
2. Count votes per candidate
3. Plurality winner becomes `round_winner`
4. If tie (only possible with even N — discourage even N):
   - Tiebreak by "runner-up" second-choice votes
   - If still tied: incumbent wins (status quo bias — challenger must clearly win)

### Reasoning Aggregation

Collect all `WINNING_STRENGTH` and `RUNNER_UP_GAP` entries per candidate. Used for:
- Author-A context in next round (what did winner do well?)
- Lineage documentation
- Chain handoff quality signal

**Output:** `✓ Phase 6: Judge Panel — winner: [A|B|AB], votes [N]-[M]-[K], round [R]`

## Phase 7: Convergence Check

After each judge round:

1. Update `consecutive_wins` counter:
   - If `round_winner` == `incumbent` → `consecutive_wins += 1`
   - If `round_winner` != `incumbent` → `consecutive_wins = 1`, update `incumbent = round_winner`

2. Check stop conditions (evaluated in order):
   - **Bounded mode** (`--iterations N`): if `round >= N` → STOP
   - **Convergence** (convergent mode): if `consecutive_wins >= convergence_threshold` → STOP
   - **Creative mode**: never auto-stop — only stops on user interrupt or `--iterations N`
   - **Max oscillation guard**: if incumbent has changed 5+ times with no consecutive wins → STOP and flag oscillation

3. If continuing: advance to Phase 2 (Generate-A) with current incumbent as base

### Convergence Report (printed when stopping)

```
✓ Converged after [N] rounds
Final winner: [A|B|AB], round [R], [consecutive_wins] consecutive wins
Total candidates evaluated: [N*3 or N*2 in debate mode]
Lineage: [brief trace of who won each round]
```

### Oscillation Detection

If the winner alternates without achieving consecutive wins (e.g., round pattern: A→B→A→B→A):
- After 5 oscillations: `OSCILLATION WARNING` — forced stop
- Log in overview.md: `⚠️ Convergence failed: oscillation detected. The task may be genuinely ambiguous or the candidates may be at parity.`
- Surface all three candidates from final round in report — present as "equivalent alternatives"

**Output:** `✓ Phase 7: Convergence — [continuing|converged|oscillation_stop|bounded_stop]`

## Phase 8: Handoff — Output Files and Optional Chain

### reason-lineage.jsonl

Append one record per round (newline-delimited JSON):

```json
{
  "round": 1,
  "timestamp": "2026-03-31T14:22:00Z",
  "task_hash": "sha256_of_task_text",
  "candidate_A_words": 312,
  "candidate_B_words": 287,
  "candidate_AB_words": 298,
  "label_map": {"X": "AB", "Y": "A", "Z": "B"},
  "judge_votes": [
    {"judge": 1, "winner_label": "X", "winner_decoded": "AB", "runner_up": "Y"},
    {"judge": 2, "winner_label": "X", "winner_decoded": "AB", "runner_up": "Z"},
    {"judge": 3, "winner_label": "Y", "winner_decoded": "A", "runner_up": "X"}
  ],
  "round_winner": "AB",
  "vote_tally": {"A": 1, "B": 0, "AB": 2},
  "incumbent_before": "A",
  "incumbent_after": "AB",
  "consecutive_wins": 1,
  "critic_weaknesses": ["FATAL: no tradeoff analysis", "MAJOR: missing failure modes"],
  "winning_strength": "Synthesized version explicitly addresses both scalability and consistency tradeoffs",
  "runner_up_gap": "Candidate A lacked concrete failure mode analysis despite stronger initial structure"
}
```

### handoff.json Schema

```json
{
  "version": "1.0",
  "tool": "reason",
  "generated_at": "2026-03-31T14:30:00Z",
  "task": "Should we use event sourcing for our order management system?",
  "domain": "software",
  "mode": "convergent",
  "summary": {
    "rounds_run": 6,
    "converged": true,
    "consecutive_wins": 3,
    "oscillation_detected": false,
    "final_winner": "AB",
    "reason_score": 187
  },
  "converged_candidate": {
    "text": "{full text of the winning candidate}",
    "word_count": 312,
    "won_in_round": 6,
    "vote_margin": "3-0"
  },
  "lineage_path": "reason/{slug}/reason-lineage.jsonl",
  "critique_themes": [
    "Missing failure mode analysis",
    "No concrete rollback strategy",
    "Event ordering assumptions under concurrent writes"
  ],
  "quality_signals": {
    "critic_fatals_addressed": 3,
    "judge_consensus_final_round": 1.0,
    "quality_delta": 0.42
  }
}
```

### Chain Conversion

#### `--chain debug`

The converged candidate (if technical: architecture, design, algorithm) becomes a hypothesis context for the debug loop. Critique themes become suspect areas.

```
/autoresearch:debug
Scope: {files relevant to task domain}
Symptom: Implementing {task} — authoritative design from reason loop
Context: {converged_candidate_text truncated to 500 chars}
Hypotheses:
  {critique_theme_1 mapped to file scope if determinable}
  {critique_theme_2}
```

#### `--chain plan`

The converged candidate becomes the basis for an autoresearch:plan configuration.

```
/autoresearch:plan
Goal: {task_as_goal}
Context: Reasoned design from {N} rounds of adversarial refinement:
{converged_candidate_text}
```

#### `--chain fix`

If task involves existing code or errors, converged candidate becomes the authoritative fix target description.

```
/autoresearch:fix
Target: {task_description}
Scope: {task-relevant file globs}
Fix-Rationale: {converged_candidate_text — the authoritative approach after N rounds}
```

#### `--chain security`

Critique themes that overlap with security concerns (threat modeling, auth, data handling) seed the security audit focus.

```
/autoresearch:security
Scope: {files relevant to task domain}
Focus: Security aspects surfaced by adversarial reason loop:
  {security-relevant critique themes}
```

#### `--chain scenario`

The converged candidate becomes the seed scenario. Critique themes become explicit dimensions to explore.

```
/autoresearch:scenario
Scenario: {converged_candidate_text — the converged approach}
Domain: {domain}
Focus: {primary critique theme — e.g., "failure modes", "concurrency"}
Depth: standard
```

#### `--chain predict`

The converged candidate and lineage critique themes become the goal for multi-persona swarm analysis.

```
/autoresearch:predict
Scope: {task-relevant file globs}
Goal: Validate and stress-test this design: {converged_candidate_text truncated to 300 chars}
Depth: standard
```

#### `--chain ship`

Converged candidate feeds directly to ship workflow as the artifact to ship.

```
/autoresearch:ship
Target: {converged_candidate as content artifact or implementation spec}
Type: {auto-detect from domain}
```

#### `--chain learn`

The full reason lineage (all rounds, critique themes, candidate evolution) feeds to learn as documentation source.

```
/autoresearch:learn
Mode: update
Context: Reason lineage from {N} rounds — {task_description}
Source: reason/{slug}/reason-lineage.jsonl
```

### Multi-Chain Execution

`--chain scenario,debug,fix` executes sequentially:
1. Write `handoff.json` after convergence
2. Launch `scenario` with chain conversion above
3. After scenario completes, convert scenario findings + handoff.json → debug context
4. After debug completes, convert debug findings → fix targets
5. Each stage's output feeds the next via updated handoff.json

**Empirical evidence rule:** Downstream loop results (debug, fix, security) ALWAYS override reason consensus. If debug disproves a design conclusion from the reason loop, log: `Reason candidate's claim [X] DISPROVEN by empirical debug loop — [evidence]`. Do NOT revert to reason consensus.

## Output Files

Creates `reason/{YYMMDD}-{HHMM}-{slug}/` with:

| File | Description |
|------|-------------|
| `overview.md` | Executive summary: task, rounds run, convergence result, final winner, quality delta, oscillation status |
| `lineage.md` | Human-readable round-by-round trace: who won, vote tally, key critique that drove change |
| `candidates.md` | Final round candidates A, B, AB in full — for manual review |
| `judge-transcripts.md` | Full judge reasoning per round (decoded — labels revealed post-evaluation) |
| `reason-results.tsv` | Per-round log: round, winner, votes, consecutive_wins, word_counts |
| `reason-lineage.jsonl` | Machine-readable full lineage (consumed by --chain tools) |
| `handoff.json` | Chain handoff schema |

## Composite Metric

```
reason_score = quality_delta * 30
             + rounds_survived * 5
             + judge_consensus_final_round * 20
             + critic_fatals_addressed * 15
             + (convergence_achieved ? 10 : 0)
             + (no_oscillation ? 5 : 0)

Where:
  quality_delta = (final_winner_word_count - A_round1_word_count) / A_round1_word_count
                  — normalized change in substance (not just length)
                  — capped at 1.0 to prevent inflation from padding
  judge_consensus_final_round = winning_votes / total_judges (0.0 to 1.0)
  critic_fatals_addressed = count of FATAL weaknesses that didn't recur in later rounds
```

Higher = more thorough + more decisive convergence. Incentivizes: substantial improvement over starting candidate, decisive judge consensus, critique responsiveness, and convergence over oscillation.

## Flags

| Flag | Purpose | Example |
|------|---------|---------|
| `--iterations N` | Bounded mode — run exactly N rounds | `--iterations 10` |
| `--judges N` | Judge count (3-7, odd preferred) | `--judges 5` |
| `--convergence N` | Consecutive wins to declare convergence (2-5) | `--convergence 3` |
| `--mode <mode>` | convergent (default), creative, debate | `--mode creative` |
| `--domain <type>` | Domain for judge personas | `--domain software` |
| `--chain <targets>` | Chain to downstream tool(s). Comma-separated for multi-chain | `--chain scenario,debug` |
| `--judge-personas <list>` | Override default judge personas | `--judge-personas "DBA,Frontend,PM"` |
| `--no-synthesis` | Skip synthesis step (A vs B only) | `--no-synthesis` |
| `--temperature low|high` | Low: forces decisive wins. High: allows closer votes | `--temperature low` |

## What NOT to Do — Anti-Patterns

| Anti-Pattern | Why It Fails |
|---|---|
| Let judges see candidate labels (A/B/AB) | Judges will bias toward synthesis — randomized labels are the entire point |
| Pass critique to Synthesizer | Synthesizer produces a strawman fix, not a genuine synthesis — give it only A and B |
| Pass prior judge transcripts to Author-B | Author-B anchors on what judges liked rather than fixing critique weaknesses |
| Use even N for judges | Even judge counts can tie. Prefer 3, 5, 7 |
| Skip convergence check | Without convergence detection, creative mode runs forever on trivial tasks |
| Trust reason loop over empirical tests | Adversarial refinement produces better arguments, not necessarily better code — verify empirically |
| Set `--convergence 1` | A single win doesn't indicate stable quality — use ≥2 |
| Chain without reviewing candidates.md | Chain handoff quality depends on the actual converged text — check it before trusting downstream |
| Run unbounded on `--mode creative` without `--iterations` | Creative mode never auto-stops — always pair with `--iterations N` unless you intend to run until interrupt |
