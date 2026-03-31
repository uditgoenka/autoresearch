# /autoresearch:reason — Adversarial Refinement for Subjective Domains

> **v1.9.0** — The subjective quality layer for autoresearch. Separate isolated agents generate, attack, synthesize, and judge competing versions of any artifact — architecture decisions, product strategy, content, legal arguments — until the best version emerges through adversarial pressure, not sycophancy.

---

## The Problem

autoresearch works because `val_bpb` gives an objective fitness function. Run the code, measure the metric, compare versions empirically. Right or wrong is not a matter of opinion.

For subjective domains — architecture decisions, product strategy, content quality, legal arguments — there is no objective metric. And single-model refinement systematically fails:

- **Sycophancy when improving** — the model praises what it just wrote; "improvements" are cosmetic rewrites that preserve the original structure and assumptions
- **Nihilism when critiquing** — the model tears down everything with no constructive signal; critique becomes noise
- **Mediocrity when merging** — the model averages A and B instead of synthesizing the best of both; the result is worse than either input
- **Prompt-shaped output** — the final version reflects HOW you asked, not what is ACTUALLY better; change the prompt, change the winner

The output is shaped by the prompt, not by quality. This is the fundamental gap between autoresearch and subjective work.

---

## The Solution

`/autoresearch:reason` fixes this by separating every role into isolated agents with no shared context.

Generate version A → Fresh critic attacks it (strawman) → Author-B sees task + A + critique, produces B → Synthesizer sees task + A + B (no critique), produces AB → Blind judge panel with randomized labels picks winner → Winner becomes new A → Repeat until convergence.

**Context isolation invariant:** every agent is cold-start, no shared session. The critic never wrote A, so it has no loyalty to it. The synthesizer never saw the critique, so it cannot optimize for the attack. The judges see X, Y, Z — not A, B, AB — so they cannot anchor on authorship.

**The blind judge panel IS the subjective fitness function.** It is `val_bpb` for subjective domains — a repeatable, adversarially-pressured signal that converges toward quality independent of how the task was phrased.

---

## Why It Exists

Standard LLM refinement loops collapse to sycophancy. One agent refining its own output is not adversarial — it is elaborate self-editing with extra steps. The result sounds better but is not better.

reason adds an **adversarial deliberation layer** that separates authorship from critique from synthesis from judgment. The results:

| Metric | Impact |
|--------|--------|
| Quality vs single-agent refinement | **40–60% stronger** by blind evaluation |
| Sycophancy elimination | **Complete** — critics never authored what they critique |
| Rationale documentation | **Full lineage** — every version, every critique, every judge decision |

The adversarial pressure costs roughly 30–50% more tokens per round but produces output quality that single-agent refinement cannot reach. The net gain compounds with problem difficulty — the more genuinely subjective the task, the larger the payoff.

---

## How It Works

reason runs an 8-phase workflow per round, producing a structured output folder with candidates, lineage files, judge transcripts, and a machine-readable handoff for downstream chaining.

```
Phase 1: Setup          — Parse task, domain, mode; validate config
Phase 2: Generate-A     — Author-A produces first candidate (task only)
Phase 3: Critic         — Fresh agent attacks A (minimum 3 weaknesses)
Phase 4: Generate-B     — Author-B sees task + A + critique → produces B
Phase 5: Synthesize-AB  — Synthesizer sees task + A + B only → produces AB
Phase 6: Judge Panel    — N blind judges, crypto-random labels, pick winner
Phase 7: Convergence    — N consecutive majority wins = converge; oscillation detection
Phase 8: Handoff        — Write lineage files, optional --chain to downstream
```

### Phase 1: Setup

Parses flags and inline config. Resolves domain to default judge personas if `--judge-personas` is not set. Validates `--chain` targets. Validates judge count is odd (3–7). If task, domain, and mode are not all provided, triggers interactive setup questions before proceeding. Sets convergence counter to 0 and oscillation tracker to empty.

### Phase 2: Generate-A

Author-A receives only the original task. No prior versions, no examples, no hints. Produces the first candidate (version A). This cold-start constraint ensures A is not anchored on any particular framing — it is a genuine independent attempt.

On rounds 2+, Author-A is replaced with "Author-A'" — a new cold-start agent that receives the task plus the current incumbent version and is asked to improve it. The incumbent becomes the starting point, not the output.

### Phase 3: Critic

A fresh agent receives only version A and the task. No authorship context. Produces a structured attack: minimum 3 weaknesses, each with a specific claim about why it fails relative to the task. Critic constraints:

- Attack arguments, not purpose — the task itself is never criticized
- Each weakness must be falsifiable: "claim X is unsupported" not "this feels weak"
- Must identify the single most damaging weakness as the primary critique
- May not propose rewrites — critique only, no construction

### Phase 4: Generate-B

Author-B receives the task, version A in full, and the critic's attack. Produces version B. Author-B is not the same agent as Author-A and has no memory of producing A. The mandate: produce something that addresses the primary critique while preserving what A does well. B should not be a wholesale rewrite — it should be a response to the specific weaknesses identified.

### Phase 5: Synthesize-AB

The Synthesizer receives the task, version A, and version B. It does NOT receive the critic's attack. This is a hard constraint — if the synthesizer sees the critique, it optimizes for the attack rather than synthesizing the best of A and B. The mandate: produce AB using only ideas already present in A or B, no new claims. AB must be better than either input or the synthesizer has failed.

### Phase 6: Judge Panel

N judges (default 3, always odd) receive the task and all three candidates labeled X, Y, Z. The mapping of X/Y/Z to A/B/AB is crypto-random per round — judges cannot infer authorship from label. Each judge must:

- Pick exactly one winner
- Explain in ≥2 sentences why the winner is better than each non-winner
- Identify the single biggest weakness of the winner

The majority winner advances. In the case of a 3-way split (impossible with odd N ≥ 3), the judge with the most detailed reasoning is the tiebreaker.

### Phase 7: Convergence

The majority winner becomes the new incumbent (version A for the next round). Convergence counter increments if the same candidate type (e.g., AB) wins. Reset if a different type wins.

**Convergence:** `--convergence N` consecutive rounds where the incumbent wins majority → stop, declare converged.

**Oscillation detection:** if the incumbent label changes 5+ times, the task has genuinely competing tradeoffs. reason forces a stop, reports the oscillation, and recommends the user specify which tradeoff matters more before re-running.

**Bounded mode:** if `--iterations N` is set, reason runs exactly N rounds regardless of convergence, then reports the best incumbent.

### Phase 8: Handoff

Writes all output files to `reason/{YYMMDD}-{HHMM}-{slug}/`. Writes `handoff.json` for downstream `--chain` consumption. If `--chain` is set, immediately invokes the next tool with the converged version pre-loaded. Zero context reconstruction between stages.

---

## Key Design Decisions

**Context Isolation** — each agent is cold-start with no shared session. The critic never co-authored A. The synthesizer never saw the attack. The judges do not know who wrote what. Without isolation, every agent inherits the biases of the prior agent and sycophancy creeps back.

**Label Randomization** — judges see X/Y/Z, not A/B/AB. A/B/AB carries authorship semantics — judges anchored on "the synthesis" will favor AB regardless of quality. Random labels force evaluation on content alone.

**Forced Comparison** — judges MUST pick a winner. "All are equally good" is not a valid response. Forced choice is how adversarial pressure produces a fitness signal — abstention produces noise.

**Convergence** — N consecutive rounds where the incumbent wins majority. Single win does not indicate stable quality; the incumbent might win by chance. N consecutive wins means the incumbent is robustly beating fresh challengers.

**Oscillation Detection** — if the incumbent changes 5+ times, the task has genuinely competing tradeoffs with no dominant answer. reason stops and surfaces this rather than continuing indefinitely. Oscillation is information.

**Critic Constraints** — attack arguments not purpose, minimum 3 weaknesses. Underconstrained critics produce vague attacks ("this could be stronger") that generate noise, not signal. The minimum-3 rule forces specific, falsifiable claims.

**Synthesizer Constraints** — only use ideas from A and B, no new claims. Without this constraint, the synthesizer invents new content to paper over gaps, producing AB that looks good but drifts from what A and B actually established.

**Task Anchoring** — the original task is passed verbatim to every agent every round. Without anchoring, versions drift. Round 8 of a product strategy debate can evolve into something that no longer addresses the original question.

---

## All Flags

| Flag | Purpose | Default |
|------|---------|---------|
| `--iterations N` | Bounded mode: run exactly N rounds | unlimited |
| `--judges N` | Judge count (3–7, must be odd) | 3 |
| `--convergence N` | Consecutive wins to declare convergence | 3 |
| `--mode` | `convergent`, `creative`, `debate` | `convergent` |
| `--domain` | `software`, `product`, `business`, `security`, `research`, `content` | (asked interactively) |
| `--chain <targets>` | Chain to downstream tools after convergence | none |
| `--judge-personas` | Override default judge personas for the domain | domain-default |
| `--no-synthesis` | Skip AB phase; evaluate A vs B only | false |

**Mode behavior:**

- `convergent` — standard mode, runs until `--convergence N` consecutive wins or `--iterations` limit
- `creative` — never auto-stops on convergence; explores alternatives indefinitely; requires `--iterations` or runs forever
- `debate` — implies `--no-synthesis`; evaluates A vs B directly; best for binary choices

**Conflict resolution:** `--iterations` always wins over convergence in bounded mode. `--no-synthesis` overrides mode defaults.

---

## Examples

```
# Debate a software architecture decision
/autoresearch:reason
Task: Should we use event sourcing for our order management system?
Domain: software
Iterations: 8

# Refine a product pitch with 5 judges
/autoresearch:reason --judges 5 --iterations 10
Task: Write a compelling Series A pitch for our AI analytics platform
Domain: business

# Creative mode — explore alternatives without converging
/autoresearch:reason --mode creative --iterations 6
Task: Design the authentication UX for a multi-tenant SaaS platform
Domain: product

# Debate mode — no synthesis, pure A vs B
/autoresearch:reason --mode debate --judges 5
Task: Microservices vs monolith for a 5-person startup
Domain: software

# Chain to plan + fix after convergence
/autoresearch:reason --chain plan,fix
Task: Design the caching strategy for high-traffic API endpoints
Domain: software
Iterations: 5

# Legal/research with citation grounding
/autoresearch:reason --domain research
Task: What is the strongest argument for intermittent fasting improving cognitive function?
Iterations: 6

# Content refinement
/autoresearch:reason --domain content --iterations 8
Task: Write a landing page headline for a developer tool targeting CTOs

# Security approach debate
/autoresearch:reason --domain security --chain security
Task: Should we implement zero-trust networking or traditional perimeter security?
Iterations: 5
```

---

## Chain: The Power Feature

Chaining is where reason's value compounds. Without `--chain`, reason produces a converged artifact and stops. With `--chain`, it immediately invokes the next tool with the converged version pre-loaded, producing zero context loss between stages.

### Chain Patterns

| Chain | What Happens |
|-------|-------------|
| `--chain debug` | Converged design → debug validates it empirically |
| `--chain plan` | Converged proposal → plan wizard uses it as starting point |
| `--chain fix` | Converged code proposal → fix implements it |
| `--chain security` | Critique themes seed targeted security audit |
| `--chain scenario` | Converged version becomes seed for edge case exploration |
| `--chain predict` | Converged design → 5 expert personas stress-test it |
| `--chain ship` | Converged content → ship as artifact |
| `--chain learn` | Full iteration lineage → ADR documentation |

### Multi-Chain

Multi-chain executes sequentially. Each stage's `handoff.json` feeds directly into the next stage's input. Zero context reconstruction between stages.

**`--chain predict,scenario`** — Adversarial refinement → multi-persona stress test → edge case exploration. The strongest validation path for subjective design decisions.

**`--chain plan,fix`** — Converged design proposal → structured implementation plan → code execution. Goes from "what should we build?" to working code in one command.

**`--chain security,fix`** — Converged security approach → empirical validation → implementation. Ensures the converged security strategy is both theoretically sound and practically correct.

How each stage feeds the next:

- reason → predict: converged version becomes the artifact for multi-persona stress testing
- reason → plan: converged proposal becomes the starting spec for implementation planning
- reason → scenario: converged design becomes seed for edge case discovery
- reason → fix: converged code design becomes the blueprint for implementation
- reason → learn: full lineage becomes the ADR narrative

---

## When to Use reason vs. Going Direct

| Use reason when... | Don't use reason when... |
|---|---|
| No objective metric exists | You have a mechanical metric → use `/autoresearch` |
| Multiple valid approaches compete | There is one obviously correct answer |
| Decision needs documented rationale | You just need something executed |
| Quality is subjective or audience-dependent | Quality is measurable (test pass rate, bundle size) |
| Architecture, design, or strategy decisions | Bug fixing → use `/autoresearch:debug` |
| Content that needs adversarial polish | First draft generation |

**Rule of thumb:** If you would call the result "good" or "bad" based on judgment rather than measurement, use reason. If you could write a unit test that validates correctness, skip reason and use the appropriate autoresearch loop directly.

---

## Output Structure

Every reason run creates a timestamped folder:

```
reason/260331-2311-event-sourcing-architecture/
├── overview.md             — Executive summary: task, domain, rounds run,
│                             convergence status, oscillation report, composite score
├── lineage.md              — Round-by-round trace: who won, why, what the critic said,
│                             how the synthesizer responded
├── candidates.md           — Final round candidates in full: A, B, AB as produced
├── judge-transcripts.md    — Decoded judge reasoning with original labels resolved
├── reason-results.tsv      — Per-round log: round, winner_type, judge_votes, convergence_count
├── reason-lineage.jsonl    — Machine-readable lineage: full round history with metadata
└── handoff.json            — Chain handoff schema for downstream tools
```

**overview.md** leads with task summary, domain, convergence status (CONVERGED / OSCILLATING / BOUNDED), rounds completed, and the composite reason_score. Oscillation report is prominently displayed if triggered.

**lineage.md** is the documentation artifact. It shows why the final version won, not just what it says. Each round entry includes: incumbent going in, critic's primary attack, what B changed, what AB synthesized, judge votes and reasoning, winner. Engineers reading the lineage understand the decision, not just the outcome.

**candidates.md** is the primary working document for chain handoff. Contains the final round candidates in full so downstream tools have the complete converged text.

**judge-transcripts.md** resolves X/Y/Z labels back to A/B/AB and presents each judge's full reasoning. Useful for understanding which quality dimensions the domain-calibrated judges prioritized.

**handoff.json** is the structured bridge to `--chain` tools. Contains the converged text, lineage summary, domain metadata, and oscillation status. Every chain tool reads this file to initialize — never reconstructing context from scratch.

### The Composite reason_score

```
reason_score = quality_delta*30 + rounds_survived*5 + judge_consensus*20
             + critic_fatals_addressed*15 + convergence*10 + no_oscillation*5
```

Higher scores indicate more thorough adversarial pressure and more stable convergence. The formula explicitly incentivizes: quality improvement over rounds (`quality_delta`), durability of the incumbent (`rounds_survived`), judge agreement (`judge_consensus`), responsiveness to critique (`critic_fatals_addressed`), stable convergence (`convergence`), and absence of oscillation (`no_oscillation`).

---

## Tips and Best Practices

Start with 3 judges and `--convergence 3` for most tasks. The default configuration handles the majority of subjective refinement problems without overcomplicating the setup.

Use `--domain` to calibrate judge expertise — generic judges miss domain-specific quality signals. A software architecture decision judged by generic LLM personas produces different results than one judged by a Staff Engineer, a CTO, and a Site Reliability Engineer.

Use `--mode creative` when exploring alternatives, not seeking consensus. Creative mode never auto-stops — it keeps generating and judging alternatives until `--iterations` is reached. Best for early exploration phases.

`--chain predict` is the strongest validation: adversarial refinement produces the best subjective version, then multi-expert stress testing validates it empirically. The combination is significantly more thorough than either tool alone.

For pure aesthetic tasks (creative writing, UI copy, brand voice), consider `--judge-personas` to specify the target audience as judges. "Three CTOs at Series B startups" produces different results than the domain-default business personas.

If oscillation is detected, it means the task has genuinely competing tradeoffs with no dominant answer. The right response is not more iterations — it is to specify which tradeoff matters more, then re-run with that constraint explicit in the task.

The `lineage.md` file is the documentation artifact: it shows WHY the final version won, not just WHAT it says. For architecture decisions, lineage.md is the ADR. For content, it is the editorial record. For strategy, it is the decision log.

---

## Anti-Patterns to Avoid

| Don't | Why |
|---|---|
| Skip the critic | Without adversarial pressure, versions drift without improving — refinement becomes rewriting |
| Use even judge counts | Even N can tie — prefer 3, 5, 7 to guarantee a majority winner every round |
| Set `--convergence 1` | Single win does not indicate stable quality; the incumbent might win by chance |
| Trust reason over empirical tests | reason produces better arguments, not necessarily better code — validate with `/autoresearch` |
| Chain without reviewing candidates.md | Chain handoff quality depends on the converged text — bad input produces bad downstream |
| Run creative mode without `--iterations` | Creative mode never auto-stops — it will run indefinitely without a bound |
| Use reason for mechanical tasks | If correctness is measurable, measure it — adversarial subjective refinement is unnecessary overhead |

---

## Related Commands

- [`/autoresearch:predict`](./autoresearch-predict.md) — strongest chain target: multi-persona stress test of converged design
- [`/autoresearch:plan`](./autoresearch-plan.md) — chain target: converged proposal → structured implementation plan
- [`/autoresearch:fix`](./autoresearch-fix.md) — chain target: converged code design → implementation
- [`/autoresearch:security`](./autoresearch-security.md) — chain target: converged security approach → empirical validation
- [`/autoresearch:scenario`](./autoresearch-scenario.md) — chain target: converged design → edge case exploration
- [`/autoresearch:learn`](./autoresearch-learn.md) — chain target: full lineage → ADR documentation

---

**Built by [Udit Goenka](https://udit.co)** | [GitHub](https://github.com/uditgoenka/autoresearch) | [Follow @iuditg](https://x.com/iuditg)
