# /autoresearch:probe — Adversarial Multi-Persona Interrogation Engine

> **v1.10.0** — The requirement-clarification layer for autoresearch. Eight adversarial personas interrogate user and codebase together until net-new constraints per round drop below a threshold (mechanical saturation). Output is the 5 autoresearch primitives — Goal, Scope, Metric, Direction, Verify — ready to feed any other autoresearch command.

---

## The Problem

You start a feature, a refactor, an audit. You think you know what you want. You run `/autoresearch` or `/plan` or `/debug` — and three rounds in, a buried assumption breaks the loop. The metric was wrong. The scope was undefined. A constraint nobody named blocks the whole approach.

Vague intent compounds. Every iteration on top of an unstated assumption multiplies the cost of unwinding it later. Single-shot intake — "what's your goal?" — collects what the user can articulate, not what the work actually requires.

`/autoresearch:probe` fixes this by interrogating the user *and the codebase* through 8 adversarial personas, harvesting atomic constraints round after round, until additional questions stop yielding new constraints. The terminal state is mechanical: net-new constraints below a threshold for K consecutive rounds = saturated.

---

## The Solution

probe runs an unlimited or bounded loop of:

1. Each active persona drafts 1–2 candidate questions for this round
2. Questions are deduped, batched, capped at ≤5
3. User answers via `AskUserQuestion` (or self-answers in `--mode autonomous`)
4. Every answer is parsed into atomic constraints, classified into 7 types
5. Atoms are cross-checked against the codebase and prior rounds
6. Saturation check — if net-new < threshold for K rounds → STOP

When saturation is reached, probe synthesizes the harvest into the 5 autoresearch primitives plus a `handoff.json` that any chained command can ingest directly.

**Why it works:** the personas have no shared loyalty. The Skeptic challenges what the Scope Sentinel just accepted. The Contradiction Finder cross-references the Constraint Excavator's atoms against the Prior-Art Investigator's ledger. No single voice can lull the loop into "sounds good — moving on."

---

## When to use it

| Situation | Why probe |
|---|---|
| Starting a non-trivial feature with vague requirements | Surfaces hidden constraints before committing to implementation |
| Inheriting code with unclear intent | Codebase grounding (Phase 3) builds a prior-art ledger; questions calibrated against it |
| Pre-`/autoresearch` setup — Goal/Scope/Metric/Direction/Verify undefined | probe IS the wizard for these primitives, more rigorous than `/autoresearch:plan` |
| Pre-mortem — about to start work and want to stress-test the plan | `--adversarial` flag rotates Skeptic/Contradiction/Edge-Case to the front |
| Cross-team alignment — multiple stakeholders with conflicting requirements | Contradiction Finder surfaces inter-answer conflicts to `contradictions.md` |

If your goal is already crystal — one sentence, mechanical metric, scope is one file — skip probe and go straight to `/autoresearch`.

---

## How It Works

10 phases per round, terminating at mechanical saturation:

```
Phase 1:  Seed Capture        — Parse topic; tokenize into seed atoms
Phase 2:  Persona Activation  — Pick N personas (default 6 of 8)
Phase 3:  Codebase Grounding  — Scan --scope, build prior-art ledger
Phase 4:  Round Generation    — Each persona drafts 1-2 candidate questions
Phase 5:  Question Synthesis  — Dedupe, drop answered, cap at ≤5/round
Phase 6:  Answer Capture      — Single batched AskUserQuestion call
Phase 7:  Constraint Extraction — Classify atoms (7 types)
Phase 8:  Cross-Check         — Validate against codebase + prior rounds
Phase 9:  Saturation Check    — Net-new < threshold for K rounds → STOP
Phase 10: Synthesize & Handoff — probe-spec.md + autoresearch-config.yml + handoff.json
```

---

## The Personas

8 personas. Default activation = first 6 in this order. `--adversarial` rotates 1, 5, 2 to the front.

| # | Persona | Signature focus |
|---|---|---|
| 1 | Skeptic | Challenges premises. "Why is this the right problem? What if the opposite is true?" |
| 2 | Edge-Case Hunter | Boundaries, off-by-one, empty/null/max inputs, "what about zero, what about a million" |
| 3 | Scope Sentinel | "Is X in scope or out?" — forces explicit anti-goals |
| 4 | Ambiguity Detective | Surfaces vague terms ("fast", "scalable", "soon") and demands atomic definitions |
| 5 | Contradiction Finder | Cross-references answers; flags internal inconsistencies |
| 6 | Prior-Art Investigator | "Has this been tried? What broke?" — reads codebase + git history |
| 7 | Success-Criteria Auditor | Forces mechanical, measurable success: "How will we KNOW it worked?" |
| 8 | Constraint Excavator | Surfaces non-obvious constraints (perf, compliance, infra, dependency policy) |

Each persona is cold-start within a round — none sees the others' candidate questions until Phase 5 synthesis. This is the same isolation invariant that `/autoresearch:reason` uses for its judges.

---

## Saturation — The Mechanical Stop

probe does not stop because it "feels done." It stops when the math says continuing is wasteful.

Track `net_new_constraints[round]`. When the trailing K-round window is all below `--saturation-threshold`, probe terminates with status `SATURATED`.

```
saturation_threshold = 2  (default)
window_K             = 3  (default)

Round 1: 14 atoms — clearly not saturated
Round 2:  9 atoms
Round 3:  5 atoms
Round 4:  3 atoms
Round 5:  2 atoms — entered window
Round 6:  1 atom  — window=[2,1]
Round 7:  1 atom  — window=[2,1,1] — all < threshold → SATURATED
```

Other terminations:

| Status | Meaning | Exit |
|---|---|---|
| `SATURATED` | Net-new below threshold for K rounds | 0 |
| `BOUNDED` | `Iterations: N` exhausted | 0 |
| `USER_INTERRUPT` | Ctrl+C or "stop" answer mid-round | 130 |
| `SCOPE_LOCKED` | All atoms in 2 consecutive rounds classified out-of-scope | 0 |

---

## Flags

| Flag | Default | Purpose |
|---|---|---|
| `--depth shallow\|standard\|deep` | standard | shallow=5 rounds, standard=15, deep=30 hard cap |
| `--personas N` | 6 | Active persona count (3-8) |
| `--saturation-threshold N` | 2 | Net-new atoms/round below which a round counts toward saturation |
| `--scope <glob>` | repo top 3 dirs | Files for codebase grounding (Phase 3) |
| `--chain <targets>` | none | Comma-separated downstream commands: plan, predict, debug, fix, scenario, reason, ship, learn |
| `--mode interactive\|autonomous` | interactive | autonomous = no AskUserQuestion; self-answers from codebase with confidence labels |
| `--adversarial` | off | Rotate Skeptic + Contradiction Finder + Edge-Case Hunter to the front |
| `--iterations N` | (depth) | Hard cap on rounds; overrides `--depth` |

---

## Output Structure

Every run creates `probe/{YYMMDD}-{HHMM}-{topic-slug}/`:

```
probe/260416-1815-add-oauth2-to-api/
├── probe-spec.md              ← Narrative requirements doc (Goal/Scope/Constraints/Assumptions/Risks/OOS/Open Questions)
├── constraints.tsv            ← (round, persona, atom, type, flag, source)
├── questions-asked.tsv        ← (round, persona, question, answer, atoms_extracted)
├── contradictions.md          ← Inter-answer conflicts surfaced by Contradiction Finder
├── hidden-assumptions.md      ← Atoms that quietly negate prior-art constraints
├── autoresearch-config.yml    ← Ready-to-use Goal/Scope/Metric/Direction/Verify
├── summary.md                 ← Composite metric, termination reason, persona contribution
└── handoff.json               ← Same shape as predict's handoff.json — chain-ready
```

`autoresearch-config.yml` is the payoff. Pipe it into the next command:

```yaml
goal: "Add OAuth2 password-grant flow to /api/v1/auth"
scope: "src/api/auth/**, src/middleware/auth.ts, tests/auth/**"
metric: "auth_score = passing_tests * 10 + zero_secrets_in_logs * 50 + p95_latency_ms_under_100 * 30"
direction: "minimize"
verify: "npm test -- auth/ && npm run lint && grep -ri 'TODO.*auth' src/ | wc -l == 0"
guard: "no new dependencies; no breaking changes to existing /api/v1/users"
iterations: 25
```

---

## Composite Metric

For bounded loops, probe scores its own thoroughness:

```
probe_score = constraints_extracted * 10
            + contradictions_resolved * 25
            + hidden_assumptions_surfaced * 20
            + ambiguities_clarified * 15
            + (dimensions_covered / total_dimensions) * 30
            + (saturation_reached ? 100 : 0)
            + (autoresearch_config_complete ? 50 : 0)
```

Heaviest weight on `saturation_reached` and `autoresearch_config_complete` because those are terminal goals. Mid-weight on contradiction and assumption surfacing — those are the differentiators a single-pass interview misses. Lighter weight on raw counts to discourage round-up gaming.

---

## Usage

```
# Unbounded — keep probing until saturation
/autoresearch:probe

# Bounded — exactly 10 rounds
/autoresearch:probe
Iterations: 10

# Inline topic + flags
/autoresearch:probe --depth deep --personas 8 --adversarial
Topic: Migrate session storage from Redis to Postgres

# Codebase-grounded (recommended for inherited code)
/autoresearch:probe --scope src/auth/**
Topic: Tighten OAuth2 token validation

# Autonomous mode (no user prompts — derive from codebase)
/autoresearch:probe --mode autonomous --scope src/checkout/**
Topic: Identify race conditions in checkout flow

# Chain — probe synthesizes config, then runs the autoresearch loop
/autoresearch:probe --chain plan
Topic: Add rate limiting to /api/v1/*

# Multi-stage chain — probe → scenario → debug → fix
/autoresearch:probe --chain scenario,debug,fix --scope src/payments/**
Topic: Find and fix payment retry edge cases
```

---

## Chaining Patterns

probe is an **upstream tool**. Its `handoff.json` feeds every other autoresearch command.

### probe → autoresearch (most common)

```
/autoresearch:probe
Topic: Reduce p95 latency on /search to under 50ms

# saturates after ~12 rounds, emits autoresearch-config.yml

/autoresearch
Goal: (from probe-spec.md)
Scope: (from autoresearch-config.yml)
Metric: (from autoresearch-config.yml)
...
```

### probe → predict

probe defines the scope and constraints, predict swarms it from 5 expert perspectives:

```
/autoresearch:probe --chain predict
Topic: Add multi-tenant isolation to the database layer
```

### probe → reason → probe (refinement loop)

reason converges on a subjective decision; probe interrogates the converged answer for missing constraints:

```
/autoresearch:reason --domain software
Task: Pick a state-management library for the new dashboard

/autoresearch:probe --chain reason
Topic: (winner from reason output)
```

### probe → scenario,debug,fix (full quality pipeline)

```
/autoresearch:probe --chain scenario,debug,fix --scope src/checkout/**
Topic: Harden checkout against partial-failure modes
```

probe surfaces the constraints, scenario enumerates the situations, debug hunts the bugs, fix repairs them.

---

## Modes

### Interactive (default)

Each round, probe batches up to 5 questions into a single `AskUserQuestion` call. You answer once per round; probe parses your answers into atoms and starts the next round. Optimal for human-in-the-loop requirement clarification.

### Autonomous (`--mode autonomous`)

probe self-answers from the codebase + persona reasoning, marking every atom with `confidence: low|med|high`. Useful for:

- Inherited codebases — derive intent from code before asking the human
- CI/CD gating — probe stale specs against current code, fail on contradictions
- Bootstrapping — auto-generate a starting `autoresearch-config.yml` for review

Downstream commands SHOULD treat `confidence: low` atoms as needing user re-confirmation before destructive operations.

---

## Anti-Patterns (DO NOT)

| Anti-pattern | Why it fails |
|---|---|
| Vague questions | "Is this complete?" yields "yes/no" — no atom. Every question must demand an atomic constraint. |
| Persona drift | The Skeptic must skeptic — not turn into a planner. Drift collapses the adversarial structure. |
| Accepting "sounds good" | Vague answers re-queue to the next round, never extract as constraints. |
| Skipping codebase grounding | Without Phase 3, the prior-art ledger is empty and questions duplicate decisions already made. |

---

## Composite vs. Single-Pass

Single-pass intake (`/autoresearch:plan`) is faster but shallower:

| Dimension | `/autoresearch:plan` | `/autoresearch:probe` |
|---|---|---|
| Rounds | 1 | Until saturation (typ. 8–15) |
| Personas | 1 (the wizard) | 6–8 adversarial |
| Codebase grounding | Optional | Mandatory (Phase 3) |
| Output | 5 primitives | 5 primitives + constraints.tsv + contradictions.md + hidden-assumptions.md |
| Best for | Clear intent | Fuzzy intent OR adversarial pre-mortem |

If you can already articulate Goal/Scope/Metric in one sentence each, use `plan`. If three rounds of "yes but what about" are likely, use `probe`.

---

## FAQ

**Q: How long does a probe session take?**
A: Standard depth (15-round cap, typically saturates at 8–12) takes 5–15 minutes of human attention with batched questions. Autonomous mode runs unattended.

**Q: Can I resume a probe session?**
A: Re-invoke with `--scope` matching the prior probe folder. probe loads the existing `constraints.tsv` and continues from the next round.

**Q: What if I disagree with the saturation call?**
A: Override with `--saturation-threshold 1` (stricter) or `Iterations: 30` (force more rounds). probe respects the explicit cap.

**Q: Does probe modify code?**
A: No. probe is read-only against the codebase. All output goes to `probe/{...}/`. Downstream chained commands may write code.

**Q: Can I add custom personas?**
A: Not in v1.10.0. The 8 default personas are fixed. `--adversarial` rotates the order; `--personas N` selects how many.

---

## See Also

- `/autoresearch:plan` — single-pass goal-to-config wizard (faster, less rigorous)
- `/autoresearch:predict` — multi-persona swarm prediction (after probe defines scope)
- `/autoresearch:reason` — adversarial refinement for subjective decisions
- `/autoresearch:scenario` — enumerate edge cases (chain after probe)
- `.claude/skills/autoresearch/references/probe-workflow.md` — the canonical workflow protocol
