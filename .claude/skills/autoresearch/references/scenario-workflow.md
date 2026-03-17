# Scenario Workflow — /autoresearch:scenario

Scenario-driven use case generator that autonomously explores situations, edge cases, failure modes, and derivative scenarios from a seed scenario. Doesn't stop at obvious paths — iteratively discovers what could go wrong, what's missing, and what nobody thought of.

**Core idea:** Seed scenario in → Decompose into dimensions → Generate situations → Classify (new/duplicate/variant) → Expand edge cases → Log → Repeat. Every iteration explores one unexplored combination.

## Trigger

- User invokes `/autoresearch:scenario`
- User says "explore scenarios", "generate use cases", "what could go wrong", "stress test this feature", "edge cases for", "what are all the ways this could fail"
- User wants to enumerate situations for a feature, workflow, or system

## Loop Support

```
# Unlimited — keep generating scenarios until interrupted
/autoresearch:scenario

# Bounded — exactly N exploration iterations
/autoresearch:scenario
Iterations: 25

# Focused scope
/autoresearch:scenario
Scenario: User attempts to checkout with multiple payment methods
Domain: software
Depth: deep
```

## PREREQUISITE: Interactive Setup (when invoked without scenario)

**CRITICAL — BLOCKING PREREQUISITE:** If `/autoresearch:scenario` is invoked without a scenario description, you MUST use `AskUserQuestion` to gather context BEFORE proceeding to ANY phase. DO NOT skip this step. DO NOT jump to Phase 1 without completing interactive setup.

**TOOL AVAILABILITY:** `AskUserQuestion` may be a deferred tool. If calling it fails or the schema is not available, you MUST use `ToolSearch` to fetch the `AskUserQuestion` schema first, then retry. NEVER skip interactive setup because of a tool fetch issue — resolve the tool availability, then ask the questions.

The question count adapts (4-8) based on what context is already provided:

**Adaptive question selection rules:**
- No input at all → ask all 8 questions
- Vague scenario only (≤5 words OR no verb/action) → ask questions 2-8 (skip 1)
- Clear scenario (>5 words AND contains actor + action), no domain → ask questions 2, 4, 5, 6, 7 (5 questions)
- Clear scenario + domain (via `--domain` flag or explicit domain keyword like "API", "auth", "UX") → ask questions 4, 6, 7, 8 (4 questions)

**Classification examples:**
- "checkout" → **vague** (1 word, no actor, no action)
- "API rate limiting" → **vague** (no actor, no verb)
- "User resets password" → **clear** (actor=User, action=resets, object=password)
- "Admin deploys to production with rollback" → **clear + domain=software** (skip to 4 questions)

You MUST call `AskUserQuestion` with the selected questions in ONE batched call:

| # | Header | Question | When to Ask | Options |
|---|--------|----------|-------------|---------|
| 1 | `Scenario` | "Describe the scenario you want to explore" | If not provided inline | Free text input |
| 2 | `Domain` | "What domain is this scenario in?" | If not obvious from scenario | "Software/API (code paths, error handling)", "Product/UX (user journeys, accessibility)", "Business/Process (workflows, approvals, compliance)", "Security/Compliance (threats, access control, data)", "Marketing/Sales (campaigns, funnels, conversions)", "Custom (I'll describe)" |
| 3 | `Actors` | "Who are the key actors/users in this scenario?" | If scenario doesn't mention actors | Detected from codebase/scenario + "End user", "Admin", "System/API", "External service", "Multiple (I'll list)" |
| 4 | `Goal` | "What's your primary goal for exploring this scenario?" | If intent is unclear | "Find edge cases and boundary conditions", "Generate test scenarios (Given/When/Then)", "Explore all user journeys and paths", "Stress test — find what breaks under pressure", "Map failure modes and recovery paths", "All of the above" |
| 5 | `Constraints` | "Any constraints or boundaries I should respect?" | If no scope or limits mentioned | "Technical limitations (infra, performance)", "Business rules (policies, SLAs)", "Regulatory/compliance requirements", "Time/resource constraints", "None — explore freely" |
| 6 | `Depth` | "How deep should I explore?" | Always | "Shallow scan (10 iterations — quick overview)", "Standard exploration (25 iterations — recommended)", "Deep investigation (50+ iterations — comprehensive)", "Unlimited — keep going until interrupted" |
| 7 | `Output` | "What output format is most useful?" | If domain doesn't make it obvious | "Use cases (Given/When/Then format)", "User stories (As a... I want... So that...)", "Test scenarios (input → expected → actual)", "Threat scenarios (attacker goal → vector → impact)", "Mixed — all applicable formats" |
| 8 | `Focus` | "Any specific area to stress test first?" | If scenario is broad | Suggested areas from scenario analysis + "Happy path first, then edge cases", "Jump straight to failure modes", "Explore everything equally" |

**IMPORTANT:** You MUST batch ALL selected questions into a SINGLE `AskUserQuestion` call. NEVER ask questions one at a time — users need full context to make informed decisions together. If `AskUserQuestion` only supports one question per call, include all questions in a single call with numbered headers.

## Architecture

```
/autoresearch:scenario
  ├── Phase 1: Seed — Capture, parse, and analyze the scenario
  ├── Phase 2: Decompose — Break into exploration dimensions
  ├── Phase 3: Generate — Create ONE new situation
  ├── Phase 4: Classify — New? Valuable? Duplicate?
  ├── Phase 5: Expand — Derive edge cases, what-ifs, failure modes
  ├── Phase 6: Log — Record to scenario-results.tsv
  └── Phase 7: Repeat — Next unexplored dimension/combination
```

## Inline Context Parsing Rules

When the user provides arguments inline, parse them in this order (flags take precedence over positional text):

1. **Flags first:** Extract `--domain`, `--depth`, `--scope`, `--format`, `--focus`, `--iterations` (or `Iterations:` inline config)
2. **Scenario text:** Everything that isn't a flag or `Iterations:` config is the scenario description
3. **`Scenario:` prefix:** If text starts with `Scenario:`, strip the prefix
4. **Flag order doesn't matter:** `--domain software User resets password` = `User resets password --domain software`
5. **Conflict resolution:** If `--depth shallow` is set but `Iterations: 50` is also set, `Iterations:` wins (explicit iteration count overrides depth presets)

**Skip setup entirely when:** Scenario text is "clear" (>5 words with actor+action) AND at least `--domain` or `--depth` is provided. Proceed directly to Phase 1.

## Cancel & Interruption Handling

- If user selects "Cancel" in any `AskUserQuestion` response → exit cleanly with message: "Scenario exploration cancelled. Run `/autoresearch:scenario` again when ready."
- If user answers only some questions and stops responding → treat answered questions as config, ask remaining questions in a follow-up call
- If Ctrl+C during setup → no state persisted, clean restart on re-invocation

## Phase 1: Seed — Capture & Analyze Scenario

**STOP: Have you completed the Interactive Setup above?** If invoked without scenario/flags, you MUST complete the `AskUserQuestion` call above BEFORE entering this phase.

Parse the scenario and build a structured understanding.

**Extract from scenario:**
- Primary actor(s) and their roles
- Goal/objective of the scenario
- Preconditions (what must be true before)
- Postconditions (expected outcomes)
- System components involved
- Data flows and transformations
- External dependencies

**If codebase context exists:**
- Read relevant source files mentioned in or related to the scenario
- Identify API routes, database models, UI components involved
- Map the technical implementation to the scenario description

**Output:** `✓ Phase 1: Seed analyzed — [N] actors, [M] components, [K] preconditions identified`

## Phase 2: Decompose — Break Into Exploration Dimensions

Map the scenario into exploration dimensions. Each dimension represents a category of situations to generate.

**Scenario Dimensions:**

| Dimension | Description | Exploration Focus |
|-----------|-------------|-------------------|
| **Happy path** | Normal successful flow | All steps complete as expected |
| **Error path** | Expected, handled failures | Validation errors, business rule violations |
| **Edge case** | Boundary conditions | Min/max values, empty inputs, unicode, huge payloads |
| **Abuse/misuse** | Adversarial or unintended behavior | Injection, privilege escalation, rate abuse |
| **Scale** | High volume/load scenarios | Concurrent users, large datasets, burst traffic |
| **Concurrent** | Race conditions and ordering | Simultaneous edits, distributed locks, eventual consistency |
| **Temporal** | Time-dependent behavior | Timeouts, expiry, scheduling, timezone edge cases |
| **Data variation** | Different input types and formats | Null, empty, unicode, special chars, max length |
| **Permission** | Access control and authorization | Role escalation, shared resources, delegation |
| **Integration** | External system interactions | API failures, timeouts, malformed responses, version mismatches |
| **Recovery** | System resilience | Crash recovery, retry logic, data consistency after failure |
| **State transition** | Object lifecycle | Invalid state transitions, partial updates, rollback |

**Dimension prioritization:**
1. Start with happy path (baseline understanding)
2. Error paths (most common real-world issues)
3. Edge cases (where bugs hide)
4. Domain-specific dimensions (security → abuse, product → UX, etc.)

**Output:** `✓ Phase 2: Decomposed — [N] dimensions active, [M] exploration vectors identified`

## Phase 3: Generate — Create ONE New Situation

Pick the highest-priority unexplored dimension/combination and generate a concrete situation.

**Situation format:**
```markdown
### [DIMENSION] Situation: [descriptive title]

**Actors:** [who is involved]
**Precondition:** [what must be true]
**Trigger:** [what action initiates this]
**Flow:**
1. [step 1]
2. [step 2]
3. [step N]
**Expected outcome:** [what should happen]
**What could go wrong:** [potential failure points]
**Severity:** [Critical/High/Medium/Low — impact if this fails]
```

**Generation strategies:**

| Strategy | When to Use | Method |
|----------|-------------|--------|
| **Dimension walk** | Early iterations | Pick next unexplored dimension, generate vanilla situation |
| **Combination** | Mid iterations | Combine 2 dimensions (e.g., edge case + concurrent) |
| **Negation** | When stuck | Take a happy path step, negate it ("what if this fails?") |
| **Amplification** | Deep exploration | Take existing situation, amplify one parameter to extreme |
| **Persona shift** | Coverage gaps | Same scenario, different actor (admin vs user vs attacker) |
| **Temporal shift** | After basics covered | Same scenario at different times (peak load, maintenance window, first use) |

**Rules:**
- ONE situation per iteration (atomic — evaluate before generating more)
- Must be concrete and specific (not vague "something goes wrong")
- Must include at least one verifiable expected outcome

## Phase 4: Classify — Evaluate & Deduplicate

Before keeping a generated situation, classify it:

| Classification | Criteria | Action |
|----------------|----------|--------|
| **New** | Not covered by any existing situation | KEEP — add to scenarios |
| **Variant** | Similar to existing but meaningfully different | KEEP — add as sub-scenario |
| **Duplicate** | Already covered by existing situation | DISCARD — log as "duplicate of #N" |
| **Out of scope** | Doesn't match the seed scenario | DISCARD — log as "out of scope" |
| **Low value** | Technically possible but unrealistic | DISCARD — log as "low value" |

**Deduplication check:**
- Compare against ALL previously generated situations
- Check for semantic similarity, not just text matching
- A situation with different actors but identical flow is a variant, not new

## Phase 5: Expand — Edge Cases & Stress Tests

For each KEPT situation, derive additional scenarios:

**Expansion techniques:**

| Technique | Description | Example |
|-----------|-------------|---------|
| **What-if** | Change one variable | "What if the network drops mid-transaction?" |
| **Boundary** | Push values to limits | "What if quantity = 0? -1? MAX_INT?" |
| **Interruption** | Inject failure mid-flow | "What if power loss occurs at step 3?" |
| **Ordering** | Change sequence | "What if step 2 happens before step 1?" |
| **Missing data** | Remove expected input | "What if the required field is null?" |
| **Stale data** | Use outdated information | "What if the cached price changed 5 minutes ago?" |

**For each expansion:**
- Generate as sub-scenario under the parent situation
- Mark with severity (Critical/High/Medium/Low)
- Note if it maps to a known bug pattern

## Phase 6: Log — Record Everything

**Append to scenario-results.tsv:**
```tsv
iteration	dimension	classification	severity	title	description	parent
1	happy_path	new	-	Successful checkout	User completes standard checkout flow	-
2	error_path	new	HIGH	Payment declined	Card rejected during checkout	-
3	edge_case	new	MEDIUM	Empty cart checkout	User clicks checkout with 0 items	-
4	edge_case	variant	LOW	Single-item cart	User checks out with exactly 1 item	#1
5	concurrent	new	CRITICAL	Double-submit	User clicks pay twice rapidly	-
6	abuse	new	CRITICAL	Price manipulation	User modifies price client-side	-
```

**Every 5 iterations, print progress:**
```
=== Scenario Progress (iteration 15) ===
Scenarios generated: 12 (8 new, 3 variants, 1 discarded)
Dimensions covered: 7/12 (58%)
Edge cases found: 18
Severity breakdown: 2 Critical, 4 High, 8 Medium, 4 Low
Coverage gaps: scale, temporal, recovery — unexplored
```

## Phase 7: Repeat — Next Exploration Vector

**Prioritization for next iteration:**
1. Unexplored dimensions with highest expected severity
2. Combinations of dimensions not yet tested together
3. Expansions of high-severity situations
4. Domain-specific patterns not yet covered
5. Coverage gaps identified in progress summary

**When to stop (unbounded mode):**
- Never stop automatically — user interrupts
- Print "diminishing returns" warning after 5 iterations with no new unique situations

**When to stop (bounded mode):**
- After N iterations, print final summary and stop

## Flags

| Flag | Purpose |
|------|---------|
| `--domain <type>` | Set domain context (software, product, business, security, marketing) |
| `--depth <level>` | Set exploration depth (shallow=10, standard=25, deep=50+) |
| `--scope <glob>` | Limit to specific files/features for codebase-aware generation |
| `--format <type>` | Output format (use-cases, user-stories, test-scenarios, threat-scenarios, mixed) |
| `--focus <area>` | Prioritize specific dimension (edge-cases, failures, security, scale) |

## Composite Metric

For bounded loops, scenario exploration thoroughness:

```
scenario_score = scenarios_generated * 10
              + edge_cases_found * 15
              + (dimensions_covered / total_dimensions) * 30
              + unique_actors_explored * 5
              + (high_severity_found * 3)
```

Higher = more thorough. Incentivizes breadth (cover dimensions) AND depth (find edge cases).

## Output Directory

Creates `scenario/{YYMMDD}-{HHMM}-{scenario-slug}/` with:
- `scenarios.md` — all generated scenarios grouped by dimension, with full situation format
- `use-cases.md` — formal use cases (Given/When/Then) derived from scenarios
- `edge-cases.md` — edge cases and failure modes with severity ratings
- `scenario-results.tsv` — iteration log
- `summary.md` — executive summary with coverage matrix, dimension heatmap, recommendations

## Domain-Specific Templates

When a domain is specified (or detected), load domain-specific dimension priorities:

### Software/API Domain
**Priority dimensions:** error_path, edge_case, concurrent, integration, data_variation
**Default format:** test-scenarios
**Extra checks:** API contract violations, backward compatibility, idempotency

### Product/UX Domain
**Priority dimensions:** happy_path, error_path, permission, temporal, state_transition
**Default format:** user-stories
**Extra checks:** Accessibility, mobile responsiveness, offline behavior, onboarding

### Business/Process Domain
**Priority dimensions:** happy_path, error_path, permission, temporal, recovery
**Default format:** use-cases
**Extra checks:** Approval chains, SLA violations, audit trail, escalation paths

### Security/Compliance Domain
**Priority dimensions:** abuse, permission, data_variation, integration, concurrent
**Default format:** threat-scenarios
**Extra checks:** OWASP Top 10 mapping, data exposure, privilege escalation, injection vectors

### Marketing/Sales Domain
**Priority dimensions:** happy_path, data_variation, temporal, scale, state_transition
**Default format:** user-stories
**Extra checks:** A/B test interference, attribution edge cases, funnel drop-offs, localization

## Chaining Patterns

```bash
# Explore scenarios, then hunt for bugs in those areas
/autoresearch:scenario
Iterations: 25

/autoresearch:debug --scope src/checkout/**
Symptom: edge cases from scenario exploration

# Explore, then security audit the weak spots
/autoresearch:scenario --domain security
Iterations: 15

/autoresearch:security --scope src/auth/**

# Generate test scenarios, then use them to write tests
/autoresearch:scenario --format test-scenarios --domain software
Iterations: 20

# Output can feed into test generation workflows
```

## What NOT to Do — Anti-Patterns

| Anti-Pattern | Why It Fails |
|---|---|
| **Generate 50 happy paths** | No value — one happy path reveals the baseline, then explore what breaks |
| **Stay in one dimension** | Missing coverage — force dimension rotation after 3 consecutive same-dimension iterations |
| **Vague situations** | "Something bad happens" is not a scenario — require specific trigger, flow, and outcome |
| **Skip classification** | Duplicates waste iterations and inflate metrics without adding value |
| **Ignore domain context** | A security scenario needs threat-focused dimensions, not UX-focused ones |
| **Abstract without concrete** | "User might experience issues" — name the issue, the trigger, and the impact |
