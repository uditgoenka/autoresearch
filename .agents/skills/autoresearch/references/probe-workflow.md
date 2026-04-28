# Probe Workflow — $autoresearch probe

Adversarial multi-persona requirement & assumption interrogation engine. Probes user and codebase through N personas until net-new constraints per round drop below a threshold (mechanical saturation), then emits the 5 autoresearch primitives ready to feed any other autoresearch command.

**Core idea:** Topic in → 8 personas interrogate → constraints harvested → saturation reached → autoresearch config out.

## Trigger

- User invokes `$autoresearch probe`
- User says "interrogate requirements", "probe for assumptions", "find hidden constraints", "stress-test my goal", "what am I missing"
- User wants to surface undeclared constraints and assumptions before committing to a plan, design, or research loop
- Chained from another autoresearch tool via `--chain probe`

## Loop Support

```
# Unlimited — keep probing until saturation or interrupted
$autoresearch probe

# Bounded — hard cap on rounds
$autoresearch probe
Iterations: 15

# Focused with full flags
$autoresearch probe --depth deep --personas 8
Topic: Event-driven order management system
```

## PREREQUISITE: Interactive Setup (when invoked without topic)

**CRITICAL — BLOCKING PREREQUISITE:** If `$autoresearch probe` is invoked without a topic description, you MUST use direct prompting to gather context BEFORE proceeding to ANY phase. DO NOT skip this step. DO NOT jump to Phase 1 without completing interactive setup.

**TOOL AVAILABILITY:** direct prompting may be a deferred tool. If calling it fails or the schema is not available, you MUST use `ToolSearch` to fetch the direct prompting schema first, then retry. NEVER skip interactive setup because of a tool fetch issue — resolve tool availability, then ask the questions.

The question count adapts (4-7) based on input fidelity:

**Adaptive question selection rules:**

| Input fidelity | Questions to ask |
|---|---|
| No input at all | Ask all 7 questions |
| Topic only (≤5 words or no verb) | Ask questions 2-7 |
| Clear topic (actor + action + object) | Ask questions 2, 3, 5, 6, 7 |
| Topic + mode + depth all provided | Ask questions 5, 6, 7 only |
| Topic + mode + depth + scope all provided | Skip setup entirely |

**Classification examples:**

- "billing" → **vague** (1 word, no actor, no action)
- "authentication system" → **vague** (no actor, no verb)
- "User resets password via email link" → **clear** (actor=User, action=resets, object=password)
- "Admin deploys ML model to production with rollback support" → **clear** (actor=Admin, action=deploys, scope hints=production + rollback)

You MUST call direct prompting with ALL selected questions in a SINGLE batched call:

| # | Header | Question | When to Ask | Options |
|---|--------|----------|-------------|---------|
| 1 | `Topic` | "What should be probed? (a goal, design, feature, or research question)" | If not provided | Free text |
| 2 | `Mode` | "Probing mode?" | If no `--mode` | "Interactive (default) — answer questions as they come", "Autonomous — self-answer using codebase inference" |
| 3 | `Depth` | "How deep?" | If no `--depth` | "Shallow (5 max rounds)", "Standard (15 max rounds — recommended)", "Deep (30 max rounds)" |
| 4 | `Personas` | "How many personas? (3-8)" | If no `--personas` | "3 — quick probe", "6 — standard (default)", "8 — thorough" |
| 5 | `Saturation-Threshold` | "Stop when net-new atoms per round drops below N (default 2)?" | If saturation matters | "1 — strict", "2 — default", "3 — lenient" |
| 6 | `Scope` | "Files to scan for codebase grounding?" | If no `--scope` | Suggested globs from project + "Entire repo top 3 dirs (default)" |
| 7 | `Chain` | "Chain to another command after probe completes?" | If no `--chain` | "predict", "plan", "reason", "scenario,debug,fix", "No chain — report only" |

**IMPORTANT:** Batch ALL selected questions into a SINGLE direct prompting call. NEVER ask one at a time — users need full context to make informed decisions together. If direct prompting only supports one question per call, include all questions in a single call with numbered headers.

## Architecture

```
$autoresearch probe
  ├── Phase 1:  Seed Capture        (parse topic / interactive setup)
  ├── Phase 2:  Persona Activation  (pick N personas)
  ├── Phase 3:  Codebase Grounding  (scan --scope for prior art)
  ├── Phase 4:  Round Generation    (each persona drafts 1-2 questions)
  ├── Phase 5:  Question Synthesis  (dedupe + batch ≤5 q/round)
  ├── Phase 6:  Answer Capture      (single direct prompting call)
  ├── Phase 7:  Constraint Extraction (classify into 7 atom types)
  ├── Phase 8:  Cross-Check         (validate vs codebase + prior answers)
  ├── Phase 9:  Saturation Check    (net-new < threshold for K rounds)
  └── Phase 10: Synthesize & Handoff (probe-spec.md + autoresearch-config.yml; optional --chain)
```

## Inline Context Parsing Rules

Parse in this order — flags take precedence:

1. **Flags first:** `--topic`, `--depth`, `--personas`, `--mode`, `--scope`, `--chain`, `--adversarial`, `--iterations`, `--saturation-threshold`
2. **YAML config block:** `Topic:`, `Iterations:`, `Mode:`, `Depth:`, `Personas:`, `Chain:`, `Scope:`
3. **Remaining text:** treat as topic if not matched to a flag or config key
4. **Flag order doesn't matter:** `--depth deep Topic: billing` = `Topic: billing --depth deep`

**Conflict resolution:** `Iterations:` overrides `--depth` preset when both are set. `--mode autonomous` skips interactive answer collection but still runs setup if topic is missing.

**Skip setup entirely when:** Topic is "clear" (actor + action + object present) AND at least `--depth` or `--mode` is provided. Proceed directly to Phase 1.

## Cancel & Interruption Handling

- If user selects "Cancel" in any direct prompting → exit cleanly: "Probe cancelled. Run `$autoresearch probe` again when ready." Output directory is NOT created — no partial files.
- Ctrl+C mid-round → persist all atoms harvested through the END of the last COMPLETED round (partial round in progress is discarded), then stop with status `USER_INTERRUPT`. Output directory IS created and contains all files populated up to that round, including `constraints.tsv`, `questions-asked.tsv`, `contradictions.md`, and `hidden-assumptions.md`. `handoff.json` is written with `status: USER_INTERRUPT`.
- Partial answer during setup → use answered fields, ask remaining in a follow-up call.
- If user answers only "TBD" or leaves fields blank → treat those fields as missing, apply adaptive defaults, proceed with reduced configuration.

## Phase 1: Seed Capture

**STOP: Have you completed the Interactive Setup above?** Complete direct prompting before entering this phase.

Parse the topic from `--topic`, a `Topic:` prefix, or trailing prose. Tokenize into seed atoms:

- **Actor** — who is doing something (user, system, service, team)
- **Action** — verb that describes the operation (build, process, query, migrate, serve, classify)
- **Object** — what is acted upon (orders, users, events, files, models, pipelines)
- **Scope hints** — modifiers that constrain the domain (real-time, multi-tenant, GDPR, on-prem, async, idempotent)

Seed atoms serve two roles: they prime each persona's question strategy for round 1, and they seed the keyword index used in Phase 3 to identify relevant codebase files. Topics with fewer than 2 scope hints trigger the Constraint Excavator to ask about implicit constraints first.

Output: ✓ Phase 1: Seed captured — [N] seed tokens, [M] scope hints

## Phase 2: Persona Activation

Select N personas from the ordered list below. Default N = 6. `--personas N` (range 3-8) picks the first N entries. `--adversarial` rotates Skeptic, Contradiction Finder, and Edge-Case Hunter to the front of the selection order before applying the N-cap.

| # | Persona | Signature focus |
|---|---------|-----------------|
| 1 | Skeptic | Challenges premises; "What if the opposite is true?" |
| 2 | Edge-Case Hunter | Boundaries, off-by-one, empty/null/max inputs |
| 3 | Scope Sentinel | "Is X in scope or out?" — forces explicit boundaries |
| 4 | Ambiguity Detective | Surfaces vague terms requiring atomic definition |
| 5 | Contradiction Finder | Detects internal inconsistencies between statements |
| 6 | Prior-Art Investigator | "Has this been tried? What broke?" — codebase + history |
| 7 | Success-Criteria Auditor | Forces mechanical, measurable success definitions |
| 8 | Constraint Excavator | Surfaces non-obvious constraints (perf, compliance, infra) |

Each persona reads the seed atoms and, after Phase 3, the prior-art ledger before generating questions. Persona role is fixed for the entire session — personas do not drift toward planning or synthesis mid-loop.

Output: ✓ Phase 2: Personas activated — [N] active, [list of names]

## Phase 3: Codebase Grounding

Scan the `--scope` glob (default: repo-relative top 3 directories). Identify the most-relevant files using two signals:

1. **Token overlap** — count seed-atom keyword hits in each file's first 200 lines
2. **Path matching** — prefer files whose paths contain seed-atom terms (e.g., `orders/`, `auth/`, `billing/`)

Read up to 20 highest-scoring files. Build a **prior-art ledger** — a structured list of decisions, constraints, and conventions already encoded in the codebase:

| Ledger entry type | Source signals |
|---|---|
| Data model constraints | Schema definitions, migration files, validation rules |
| API contracts | Route definitions, OpenAPI specs, documented SLAs |
| Implicit design decisions | Timeout values, retry counts, feature flags, env vars |
| Known limitations | TODOs, comments flagged `FIXME`, ADR decision records |
| Performance envelopes | Index definitions, cache TTLs, rate limit configs |

Each persona reads the ledger before generating questions in Phase 4. Questions that duplicate a ledger entry are deprioritized at synthesis. **This phase is MANDATORY** — without the ledger, personas ask questions already answered by the codebase, wasting rounds and frustrating users.

Output: ✓ Phase 3: Codebase grounded — [N] files read, [M] prior-art entries in ledger

## Phase 4: Round Generation

Each active persona independently drafts 1-2 candidate questions for the current round. **Cold-start rule:** no persona sees another's questions until Phase 5 synthesis. Each question must satisfy all of:

- Demands an atomic, falsifiable answer (not "sounds good" or "it depends")
- Does not duplicate a question asked in any prior round (checked by semantic hash)
- Does not duplicate a constraint inferrable from the prior-art ledger

If a persona cannot generate a new non-redundant question, it contributes 0 questions for this round (this signals potential saturation and increments the saturation window counter).

Output: ✓ Phase 4: Round [R] — [P] personas, [Q] candidate questions generated

## Phase 5: Question Synthesis

Before sending questions to the user, synthesize the candidate pool in this order:

1. **Semantic dedupe** — hash questions by intent; drop near-duplicates keeping the sharper, more specific phrasing
2. **Prior-round filter** — drop questions already answered in rounds 1 through R-1
3. **Ledger filter** — drop questions fully answerable from the prior-art ledger (log the ledger source for traceability)
4. **Cap at ≤5 per round** — if more remain after filtering, prefer questions from personas with the fewest atoms kept in the running tally (encourages persona diversity in the output)
5. **Ambiguities re-queue** — atoms classified as Ambiguity in Phase 7 are promoted to the front of the next round's question pool with a sharper clarification prompt

**Tie-breaking:** when two equally valid questions compete for the final slot, prefer the one from the persona whose domain has contributed fewest Requirement-type atoms so far.

Output: ✓ Phase 5: Synthesis — [Q] questions selected from [C] candidates, [D] dropped

## Phase 6: Answer Capture

Issue a single batched direct prompting call with the ≤5 synthesized questions. Each question is presented with its originating persona label so the user understands the interrogation angle.

**Interactive mode (default):** User answers all questions in one response. Partial answers are valid — unanswered questions re-queue.

**Autonomous mode (`--mode autonomous`):** Substitutes a self-answer step. Claude uses prior-art ledger + persona reasoning to produce best-effort answers, each marked with a confidence level:

| Confidence | Meaning | Downstream treatment |
|---|---|---|
| `high` | Ledger contains explicit evidence | Treat as confirmed constraint |
| `med` | Ledger implies the answer by convention | Flag in summary; downstream may rely on it |
| `low` | Inferred from general patterns, no codebase evidence | Flag in `hidden-assumptions.md`; require human confirmation before destructive ops |

**Vague answer handling:** Responses of "sounds good", "probably fine", "TBD", "I think so", or empty answers are NOT extracted as constraints. They are re-queued to the next round with a sharper clarification prompt citing the exact vague phrase.

Output: ✓ Phase 6: Answers captured — [Q] questions answered, [V] vague (re-queued)

## Phase 7: Constraint Extraction

Classify every atomic statement from the answers into one of 7 types:

| Type | Example | Goes to |
|------|---------|---------|
| Requirement | "Must support 1k concurrent users" | constraints.tsv |
| Assumption | "Postgres 15 is the only target DB" | constraints.tsv (flag=assumption) |
| Constraint | "No new dependencies" | constraints.tsv |
| Risk | "Vendor X may sunset API in Q3" | constraints.tsv (flag=risk) |
| Out-of-scope | "Mobile app — not this milestone" | constraints.tsv (flag=oos) |
| Ambiguity | "'Fast' undefined" | unresolved → re-queued to next round |
| Contradiction | "Synchronous AND eventually consistent" | contradictions.md |

Each row in `constraints.tsv` records: `round`, `persona`, `atom`, `type`, `flag`, `source`. The `source` field records which question and round produced this atom, enabling traceability to the persona that surfaced it.

**Classification rules:**
- One atom per row — compound answers must be split before classification
- Contradictions are extracted as two rows (both sides) and linked in `contradictions.md`
- Ambiguities are not extracted as constraints until they are resolved in a later round

Output: ✓ Phase 7: Extraction — [N] atoms classified, [A] ambiguities re-queued, [C] contradictions flagged

## Phase 8: Cross-Check

For each newly extracted atom, validate against two sources:

1. **Prior-art ledger (Phase 3):** Does this atom contradict or quietly negate an existing codebase constraint? Surface to `hidden-assumptions.md` with the ledger entry it conflicts with.
2. **Prior-round atoms:** Does this atom contradict a constraint extracted in an earlier round? Log to `contradictions.md` with round numbers and both atom texts side by side.

**Hidden assumption definition:** An atom that would silently invalidate a prior-art decision if accepted without question. These are the most valuable output of the probe because they surface implicit incompatibilities before they become bugs or rework.

**Hidden assumption example:** Round 3 produces the atom "all writes go through a message queue for durability". The prior-art ledger contains `orders/create.ts` line 44 — a direct synchronous `db.insert()` with no queue. This is a hidden assumption: the stated design contradicts the existing implementation. Logged to `hidden-assumptions.md` as: `[R3] Atom "all writes go through message queue" conflicts with prior-art: orders/create.ts:44 (direct db.insert)`.

**Contradiction example (cross-round):** Round 2 atom: "all API calls must be synchronous — latency SLA is 50ms". Round 5 atom: "order confirmation is eventually consistent — delivery time varies by region". These are mutually exclusive. Logged to `contradictions.md` as: `[R2 vs R5] "synchronous / 50ms SLA" contradicts "eventually consistent / variable delivery". Personas: Success-Criteria Auditor (R2) vs Constraint Excavator (R5). Needs explicit resolution before implementation.`

**Resolution:** Contradictions and hidden assumptions are surfaced to the user in the next round as explicit questions (Contradiction Finder and Skeptic personas own these). They are not auto-resolved — the probe asks; the user decides.

Output: ✓ Phase 8: Cross-check — [H] hidden assumptions surfaced, [C] contradictions added

## Phase 9: Saturation Check

Track the running window of net-new constraint counts per round:

```
net_new_constraints[r] = atoms classified as Requirement|Assumption|Constraint|Risk in round r
                         (Ambiguity and Out-of-scope excluded — they don't signal convergence)
```

**Stop conditions (evaluated in order each round):**

| Status | Condition | Exit code | Notes |
|--------|-----------|-----------|-------|
| `SATURATED` | `net_new_constraints[r] < saturation_threshold` for K consecutive rounds (default K=3, threshold=2) | 0 | Healthy termination — constraints fully harvested |
| `BOUNDED` | `current_round >= max_iterations` | 0 | Normal bounded run — may not be fully saturated |
| `USER_INTERRUPT` | Ctrl+C received | 1 | Atoms from completed rounds preserved; partial round discarded |
| `SCOPE_LOCKED` | All atoms classified as Out-of-scope for 2 consecutive rounds | 0 | Topic too narrow; broaden or re-topic |

If not stopped: advance to Phase 4 for round R+1 with updated ledger, re-queued ambiguities, and the saturation window shifted by one.

**Window display:** Every round prints the current saturation window so users can anticipate termination. Example: `net-new=[4, 3, 1] → 2 of 3 rounds below threshold`.

Output: ✓ Phase 9: Saturation check — round [R], net-new=[N] (window=[a,b,c])

## Phase 10: Synthesize & Handoff

Emit the following files to `probe/{YYMMDD}-{HHMM}-{topic-slug}/`:

**probe-spec.md** — narrative summary with sections: Goal, Scope, Constraints, Assumptions, Risks, Out-of-scope, Open Questions. Written in prose, not bullet lists — human-readable for stakeholders.

**autoresearch-config.yml** — the 5 autoresearch primitives synthesized from all harvested atoms:

```yaml
goal: "[one-sentence statement of what is being built/solved]"
scope: "[file globs and system boundaries from Scope Sentinel atoms]"
metric: "[mechanical success definition from Success-Criteria Auditor atoms]"
direction: "[ranked approach from Constraint + Assumption atoms]"
verify: "[test conditions from Requirement atoms]"
guard: "[hard constraints from Risk atoms — things that must NOT be violated]"
iterations: "[suggested loop depth for downstream commands]"
```

**summary.md** — composite metric breakdown, termination reason, per-persona atom contribution stats (atoms per persona per round), and a coverage matrix showing which constraint types were surfaced.

**handoff.json** — machine-readable handoff that mirrors `predict-workflow.md` handoff.json structure so any chained command can ingest without format translation. Contains: `topic`, `status`, `atoms`, `config_path`, `chain_targets`.

If `--chain <targets>` is set, hand off sequentially. Each chained command receives `handoff.json` + `autoresearch-config.yml` as its seed context.

Output: ✓ Phase 10: Handoff complete — [N] constraints, [A] assumptions, [H] hidden assumptions, status=[SATURATED|BOUNDED|USER_INTERRUPT|SCOPE_LOCKED]

## Flags

| Flag | Type | Default | Purpose |
|------|------|---------|---------|
| `--depth` | preset | standard | shallow=5, standard=15, deep=30 max rounds |
| `--personas N` | int 3-8 | 6 | active persona count |
| `--saturation-threshold N` | int | 2 | net-new atoms/round below which round counts toward saturation |
| `--scope <glob>` | string | repo-top-3 | files for codebase grounding |
| `--chain <targets>` | csv | none | sequential downstream commands |
| `--mode` | enum | interactive | interactive vs autonomous (self-answer) |
| `--adversarial` | bool | false | rotate Skeptic+Contradiction+Edge-Case to front |
| `--iterations N` | int | (depth) | hard cap on rounds (overrides `--depth`) |

## Composite Metric

```
probe_score = constraints_extracted * 10
            + contradictions_resolved * 25
            + hidden_assumptions_surfaced * 20
            + ambiguities_clarified * 15
            + (dimensions_covered / total_dimensions) * 30
            + (saturation_reached ? 100 : 0)
            + (autoresearch_config_complete ? 50 : 0)
```

**Design rationale:**

- Heaviest weight on `saturation_reached` (100) and `autoresearch_config_complete` (50) — these are terminal goals; reaching them means the probe did its job. A probe that ends early without a usable config produces zero value regardless of round count.
- Mid-weight on `contradictions_resolved` (25) and `hidden_assumptions_surfaced` (20) — surfacing these is the primary differentiator of probe vs a simple Q&A session. A contradiction found pre-implementation saves orders-of-magnitude more work than one found post-deployment.
- Lighter weight on raw counts (`constraints_extracted` × 10, `ambiguities_clarified` × 15) — prevents gaming by inflating low-value atoms to run up the score. Ten shallow constraints are worth fewer points than one contradiction resolved.

## Output Directory

Creates `probe/{YYMMDD}-{HHMM}-{topic-slug}/` containing:

| File | Description |
|------|-------------|
| `probe-spec.md` | Narrative summary: Goal, Scope, Constraints, Assumptions, Risks, Out-of-scope, Open Questions |
| `constraints.tsv` | Cols: round, persona, atom, type, flag, source |
| `questions-asked.tsv` | Cols: round, persona, question, answer, atoms_extracted |
| `contradictions.md` | All contradiction pairs with round references and resolution notes |
| `hidden-assumptions.md` | Atoms that quietly negate prior-art constraints, with ledger source |
| `autoresearch-config.yml` | The 5 primitives + guard + iterations |
| `summary.md` | Composite metric breakdown, termination reason, persona contribution stats |
| `handoff.json` | Machine-readable handoff consumed by `--chain` targets |

## Stop Conditions

| Status | Condition | Exit code | Notes |
|--------|-----------|-----------|-------|
| `SATURATED` | net-new atoms/round < threshold for K consecutive rounds | 0 | Healthy termination — constraints fully harvested |
| `BOUNDED` | current round reached max_iterations | 0 | Normal bounded run — may not be fully saturated |
| `USER_INTERRUPT` | Ctrl+C or explicit cancel | 1 | Atoms from completed rounds preserved; partial round discarded |
| `SCOPE_LOCKED` | All atoms classified as Out-of-scope for 2 consecutive rounds | 0 | Topic scope too narrow; broaden or re-topic |

Termination reason is written to `summary.md` and `handoff.json`. Only `USER_INTERRUPT` exits non-zero.

## Anti-Patterns

| Anti-Pattern | Why It Fails |
|---|---|
| **Vague questions** ("Is this complete?") | Every question must demand an atomic, falsifiable constraint. A question answerable with "yes" produces no extractable atom — it wastes a round slot and inflates the question count without advancing saturation. |
| **Persona drift** (Skeptic pivots to planning) | The Skeptic challenges premises; it does not propose solutions. The Success-Criteria Auditor defines measurable success; it does not speculate about implementation. Drift produces lower-quality atoms and skews persona contribution stats. |
| **Accepting "sounds good"** | Vague, hedged, or non-committal answers ("TBD", "probably", "I think so") are never extracted as constraints. Accepting them silently inflates the atom count with unverifiable data. Re-queue with a sharper prompt. |
| **Skipping codebase grounding** | Without the prior-art ledger, personas ask questions already answered by the existing codebase. Users feel interrogated about decisions they already made in code. Phase 3 is mandatory — no exceptions. |

## Chaining Examples

```bash
# probe → plan → autoresearch loop
# Probe synthesizes config, plan validates it, loop runs research
$autoresearch probe --depth standard
Topic: Multi-tenant SaaS billing system
```

```bash
# probe → predict
# Probe defines scope and assumptions, predict swarms it with expert personas
$autoresearch probe --chain predict
Topic: WebSocket gateway for real-time notifications
```

```bash
# probe → reason --chain probe
# Reason converges a design decision, probe interrogates the converged
# answer for missing constraints — useful when decisions are contested
$autoresearch reason
Task: Should we use event sourcing for order management?
--chain probe
```

```bash
# probe → scenario,debug,fix
# Probe surfaces assumptions → enumerate failure scenarios
# → hunt bugs in those areas → fix
$autoresearch probe --chain scenario,debug,fix
Topic: Payment processing pipeline assumptions
```

## Domain Templates

Recommended persona subsets by domain. Use `--personas 4` with `--adversarial` if the first four in the ordered list don't match the domain priorities below.

### Software / API

| Persona | Why |
|---|---|
| Edge-Case Hunter | Data contracts break at boundaries; find them before integration tests do |
| Contradiction Finder | API surfaces often have implicit assumptions that conflict with callers |
| Scope Sentinel | Feature creep in API design is expensive to roll back |
| Constraint Excavator | Performance, idempotency, and backward-compatibility constraints are rarely stated upfront |

**Focus:** Data contracts, error surfaces, idempotency, backward compatibility

### Product / UX

| Persona | Why |
|---|---|
| Ambiguity Detective | "Simple" and "intuitive" are undefined; pin them to specific behaviors |
| Scope Sentinel | Feature boundaries prevent scope creep before design handoff |
| Success-Criteria Auditor | Measurable success prevents "good enough" shipping decisions |
| Skeptic | User behavior assumptions are the most common source of product rework |

**Focus:** User goal clarity, measurable success, feature boundaries, assumption of user behavior

### Security / Compliance

| Persona | Why |
|---|---|
| Skeptic | Every trust assumption is an attack surface |
| Constraint Excavator | Compliance constraints (GDPR, SOC2, HIPAA) are non-obvious until violated |
| Contradiction Finder | Security requirements often conflict with usability — surface early |
| Edge-Case Hunter | Auth edge cases (expired tokens, concurrent sessions) are primary exploit vectors |

**Focus:** Trust boundaries, data exposure paths, compliance constraints, threat assumptions

### Business / Process

| Persona | Why |
|---|---|
| Scope Sentinel | Process automation scope creep is the leading cause of missed deadlines |
| Success-Criteria Auditor | ROI definitions must be mechanical before automation begins |
| Prior-Art Investigator | Prior process failures encode hard-won institutional knowledge |
| Constraint Excavator | Regulatory, approval-chain, and SLA constraints are rarely surfaced in initial briefs |

**Focus:** Regulatory constraints, SLA commitments, stakeholder assumptions, ROI definitions

### Content / Research

| Persona | Why |
|---|---|
| Ambiguity Detective | Audience, quality, and "done" are undefined in most content briefs |
| Success-Criteria Auditor | Content success must be measurable (engagement, accuracy, reach) |
| Skeptic | Source and methodology assumptions need explicit validation |
| Contradiction Finder | Research scope often contains conflicting objectives from different stakeholders |

**Focus:** Audience assumptions, measurable quality criteria, definitional consistency, sourcing constraints
