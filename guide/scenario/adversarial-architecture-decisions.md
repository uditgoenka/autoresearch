# Scenario: Adversarial Architecture Decisions — Event Sourcing for Order Management

> Watch a contested architecture decision get refined through 8 rounds of adversarial critique. An initial proposal, a critic that finds real weaknesses, a revised alternative, and a synthesis that emerges as the winning architecture.

---

## The Command

```
/autoresearch:reason
Task: Should we use event sourcing for our order management system?
Domain: software
Iterations: 8
```

---

## What This Explores

Architecture decisions don't have a single right answer — they depend on tradeoffs the team values differently. Event sourcing is a prime example: it solves audit trails and temporal queries elegantly, but introduces eventual consistency, operational complexity, and team expertise requirements that can sink projects.

`autoresearch:reason` runs an adversarial loop: generate, critique, generate-again, synthesize, then let a judge panel pick the winner. Each round, the incumbent must survive critique or lose to the challenger. By round 8, the surviving architecture has been stress-tested against every objection the critic could raise.

**Why event sourcing is a good test case:**
- High upside: audit trail, replay, temporal queries, decoupled consumers
- Real downside: eventual consistency, schema evolution, team learning curve
- Legitimate alternatives: CDC + change log, outbox pattern, simple audit table
- No universal answer — context determines the right call

---

## Round-by-Round Walkthrough

### Round 1 — Generate-A

**Author proposes event sourcing:**

The order management system should adopt event sourcing as its core persistence model. Instead of storing current state in a mutable orders table, every state transition is stored as an immutable event: `OrderPlaced`, `OrderConfirmed`, `PaymentCaptured`, `OrderShipped`, `OrderDelivered`, `OrderCancelled`.

This approach delivers three concrete operational wins. First, a complete audit trail without extra effort — every state change is the record. Compliance queries ("show me every order that was in a pending state on March 15th") become simple event stream queries rather than requiring expensive audit table joins or log parsing. Second, temporal queries become first-class: replay the event stream up to any timestamp to reconstruct the exact system state at that moment. Debugging a production incident from two weeks ago means replaying events to that point rather than guessing from incomplete logs. Third, event replay enables powerful debugging in development and staging — reproduce any sequence of real production events to isolate a bug without needing a production data dump.

The event store also becomes a natural integration hub. Downstream systems (warehouse, shipping, analytics, customer notifications) subscribe to order events rather than polling a state table or calling APIs. Decoupling is structural, not incidental.

**Proposed stack:** Kafka as the event stream, PostgreSQL as the event store for persistence guarantees, projections to read-model tables for query patterns, Debezium for CDC where needed.

**Implementation estimate:** 6-8 weeks for core event sourcing infrastructure, 3-4 weeks per downstream consumer migration.

---

### Round 1 — Critic

**Three weaknesses identified:**

**(1) FATAL: No analysis of eventual consistency impact on real-time order status**

The proposal ignores the most operationally painful aspect of event sourcing: the consistency gap between writes and read model projections. When a customer places an order and immediately requests order status, the projection may not yet reflect the `OrderPlaced` event. The current proposal has no answer for this. In an order management context this is not academic — support teams, customer-facing APIs, and payment reconciliation all need consistent reads immediately after writes. The proposal must quantify the acceptable lag, design around it, or justify that it's not a problem.

**(2) MAJOR: No comparison with simpler alternatives**

CDC (Change Data Capture) with a change log table achieves 80% of the stated benefits with a fraction of the complexity. An `order_events` append-only table alongside a standard `orders` state table gives audit trail and replay without eventual consistency issues, without the Kafka dependency, and without requiring the team to learn event sourcing patterns. The proposal must explain why full event sourcing is justified over this simpler approach.

**(3) MAJOR: Missing discussion of team expertise required**

Event sourcing has a steep learning curve: projection management, snapshotting strategies for long-lived aggregates, schema evolution for immutable events, saga/process manager patterns for multi-step workflows. If the team has no prior event sourcing experience, the 6-8 week estimate is optimistic by a factor of 2-3x. The proposal should include a team readiness assessment and a realistic ramp-up timeline.

---

### Round 1 — Generate-B

**Author addresses critique with hybrid approach:**

The critique correctly identifies that pure event sourcing creates an eventual consistency liability for real-time order status. The revised proposal: **event sourcing for order state transitions, traditional CRUD for inventory and user management.**

Order domain: every state transition emits an event to the event store. Projections maintain read models, but the order aggregate itself is the source of truth — reads can query the aggregate directly (bypassing the projection) for consistency-sensitive operations. This eliminates the consistency gap for critical paths while preserving the full event history.

Inventory and user management domains stay on traditional CRUD. These domains are update-heavy with low audit requirements — event sourcing would add complexity with no benefit.

**Explicit consistency analysis:**
- Order placement → immediate read from aggregate (consistent): latency +2ms vs. direct table read
- Order status widget (customer-facing, cached): eventual consistency acceptable, projection lag <500ms
- Support team order view: aggregate read, always consistent
- Payment reconciliation: event stream query, eventual consistency documented and acceptable (T+1 settlement window)

**Alternatives comparison:**
CDC + change log achieves audit trail. Event sourcing additionally provides: replay for debugging, natural event-driven consumer decoupling, and temporal queries. If the team's primary need is audit trail only, CDC wins. If the team expects to build multiple event-driven consumers (warehouse, analytics, notifications), event sourcing pays for itself by week 8.

**Team readiness criteria (go/no-go):**
- At least one engineer with prior event sourcing production experience
- Team commits 2 weeks to infrastructure setup before feature work
- Projection lag monitoring added to observability stack from day one

---

### Round 1 — Synthesize-AB

**Merged architecture:**

Version A's comprehensive event replay benefits combined with Version B's pragmatic hybrid boundary. The synthesized proposal adds an explicit decision matrix to make the tradeoff analysis actionable.

**Decision matrix:**

| Factor | Event Sourcing | CDC + Change Log | Hybrid (ES for orders only) |
|---|---|---|---|
| Audit trail | Full | Full | Full for orders |
| Temporal queries | Native | Reconstructable | Native for orders |
| Eventual consistency risk | High | None | Contained |
| Team learning curve | High | Low | Medium |
| Consumer decoupling | Structural | Requires extra work | Structural for orders |
| Schema evolution complexity | High | Low | Medium |
| Operational overhead | High | Low | Medium |

**Recommendation:** Hybrid with event sourcing scoped to the order aggregate. This contains the consistency risk, limits the learning curve to the highest-value domain, and proves the pattern before expanding it.

**Consistency strategy:**
- Aggregate reads for consistency-sensitive paths (order placement confirmation, support views)
- Projection reads for display-only paths (customer status page, analytics dashboards)
- Document which paths use which read model — enforce this in code review

---

### Round 1 — Judge Panel

Three judges evaluate versions A (Generate-A), Y (Generate-B), Z (Synthesize-AB) — labels shuffled to prevent anchoring bias.

**Judge 1 (Architecture Lead persona):** Picks **Z** (decoded: AB). "Z is the only version that makes the tradeoff visible and actionable. The decision matrix alone would save this team from a two-hour meeting. A's proposal is competent but unanswerable — you can't evaluate it without the comparison data Z provides."

**Judge 2 (Senior Engineer persona):** Picks **Z** (decoded: AB). "The consistency analysis in Z addresses the actual operational concern. I've been burned by projection lag in production — the aggregate-read-for-critical-paths pattern is the correct answer, and only Z includes it. No other version would survive the first sprint review."

**Judge 3 (Staff Engineer persona):** Picks **Y** (decoded: A, Generate-B). "Z's hybrid boundary is right, but the decision matrix creates a false precision. Those cells are all context-dependent. Y's consistency analysis is sufficient without the table. Cleaner argument."

**Winner: AB (2/3 votes).** Incumbent established.

---

### Round 2 — Abbreviated

**Critic finds new weakness in AB:** No rollback strategy. If a projection gets corrupted or a bug in the projection logic produces wrong read-model state, how does the team recover? Event sourcing's theoretical advantage (replay from events) requires the replay infrastructure to be built and tested. The proposal assumes this exists but doesn't specify it.

**Generate-C** (challenger to AB) adds: explicit projection reset procedure (truncate read model → replay from event 0), blue/green projections for zero-downtime projection upgrades, and circuit breaker to fall back to aggregate reads if projection lag exceeds threshold.

**Synthesize-AB-C** merges AB's decision matrix with C's operational runbook additions.

**Judge panel:** AB-C wins 3/3. New incumbent.

---

### Round 3 — Abbreviated

**Critic finds new weakness in AB-C:** No migration path from the current system. The proposal assumes greenfield. If there's an existing `orders` table with 2 years of history, how does the team bootstrap the event store? Migrating historical state into event streams is non-trivial and often produces synthetic events that break the event sourcing invariant ("events should reflect what actually happened, not a state snapshot").

**Generate-D** addresses this with a strangler fig migration: run old system and event sourcing in parallel, new orders flow through event sourcing, old orders remain in legacy system until a defined cutover date. Read model aggregates both sources during transition.

**Synthesize-AB-C-D** adds migration phases to the architecture doc.

**Judge panel:** AB-C-D wins 2/3. New incumbent.

---

### Rounds 4–6 — Convergence Forming

**Round 4:** Critic raises team readiness criteria as too vague ("one engineer with prior experience" is not verifiable). Challenger adds concrete readiness checklist (list of 5 specific skills to assess). Judge panel: incumbent AB-C-D wins 2/3 — critique was valid but the improvement was incremental, not structural.

**Round 5:** Critic challenges projection lag threshold (500ms stated in Round 1 — where does this number come from?). Challenger proposes SLO-driven threshold: measure actual customer behavior, set lag budget based on P95 customer patience. Judge panel: incumbent wins 3/3 — critique is valid as an operational concern but doesn't change the architecture; it's a configuration parameter.

**Round 6:** Critic proposes async saga pattern for multi-step workflows (order → payment → warehouse → shipping). Challenger adds saga to the implementation phases. Judge panel: incumbent wins 3/3. Saga was already implied by the event-driven consumer model — the architecture absorbs it without structural change.

---

### Rounds 7–8 — Convergence Achieved

**Round 7:** Incumbent wins 3/3 consecutive. The critic raises observability requirements (distributed tracing across event consumers, event store metrics). The challenger adds an observability checklist. Judge panel unanimous: the addition is operational hygiene, not an architectural objection. Incumbent retains.

**Round 8:** Incumbent wins 3/3 again. Three consecutive unanimous wins — convergence criteria met. Loop exits.

---

## Final Converged Architecture

The surviving design after 8 rounds of adversarial refinement:

**Core decision:** Event sourcing scoped to the order aggregate. All other domains (inventory, users, payments) on traditional CRUD.

**Consistency strategy:**
- Aggregate reads for: order placement confirmation, support team views, payment reconciliation
- Projection reads for: customer status display, analytics, warehouse feeds
- Fallback: circuit breaker falls back to aggregate reads if projection lag >500ms

**Operational runbook:**
- Projection reset: truncate read model → replay from event 0 (tested quarterly)
- Blue/green projections for zero-downtime projection upgrades
- Event store metrics: lag, throughput, replay time — all in primary observability dashboard

**Migration path (strangler fig):**
- Phase 1: New orders flow through event sourcing; legacy orders remain in `orders` table
- Phase 2: Read model aggregates both sources (event store + legacy table)
- Phase 3: Backfill legacy orders as synthetic `OrderStateSnapshot` events (clearly labeled, not treated as history)
- Phase 4: Legacy table read path removed after 90-day parallel run

**Team readiness checklist (must pass before Phase 1):**
- [ ] At least one engineer can explain projection snapshotting and why it's needed for long-lived aggregates
- [ ] Team has read and discussed the CQRS + ES chapter of "Implementing Domain-Driven Design"
- [ ] Projection reset procedure documented and dry-run in staging
- [ ] Observability dashboards for event lag live in staging
- [ ] On-call runbook updated with event sourcing failure modes

**Implementation phases:**
1. Event store schema + basic append/read (1 week)
2. Order aggregate with event-sourced state (2 weeks)
3. First projection + read model (1 week)
4. Projection reset + blue/green infrastructure (1 week)
5. First downstream consumer (warehouse) migrated (1 week)
6. Legacy migration (strangler fig Phase 1-2) (2 weeks)
7. Observability + SLOs (1 week)

**Architecture Decision Record:** The `lineage.md` generated by the reason loop captures every round's winner, the critiques that forced changes, and the final rationale. It functions as the ADR without additional documentation effort.

---

## Chain Suggestions

```
# After convergence, validate the design
/autoresearch:predict --chain debug
Scope: src/orders/**
Goal: Validate event sourcing proposal from reason loop

# Explore edge cases in the proposed design
/autoresearch:scenario
Scenario: Event sourcing for order management with hybrid CRUD
Domain: software
Depth: deep

# If implementing, plan it out
/autoresearch:reason --chain plan
Task: Implement the converged event sourcing architecture
```

---

## Key Takeaways

**1. Round 1's Version A was good but incomplete — the critic forced the improvement.**
The initial proposal was reasonable but untestable: no consistency analysis, no alternatives comparison, no team readiness criteria. These aren't nice-to-haves — they're the actual decision inputs. The critic made them mandatory.

**2. Synthesis (AB) consistently won because it combined multiple perspectives.**
Version A had depth. Version B had pragmatism. Neither alone was as strong as the merge. This is the core mechanic of adversarial refinement: generate from different angles, then synthesize. The synthesis isn't an average — it's the union of the strongest parts.

**3. Convergence took 5 rounds — the first 3 were significant quality jumps, rounds 4–8 were marginal.**
Rounds 1–3 forced structural changes (consistency strategy, rollback, migration path). Rounds 4–8 added operational detail. The architecture was essentially correct by round 4 — the final rounds were validation, not transformation. This pattern is typical: front-load your iteration budget for architecture decisions, set `Iterations: 6` if operational detail matters less.

**4. The `lineage.md` file becomes an Architecture Decision Record automatically.**
Every round is logged: which version won, what the critique was, what changed. The final `lineage.md` contains the full decision history. Share it directly with stakeholders instead of writing a separate ADR document. This is the artifact most teams lose when making architecture decisions under time pressure.

**5. Judge personas calibrated for the `software` domain caught implementation-specific issues that generic judges would miss.**
The Architecture Lead persona flagged the missing decision matrix. The Senior Engineer persona flagged projection lag from personal production experience. Generic "evaluator" personas would have scored on clarity and completeness — not on whether the design would survive a real on-call rotation. Domain-specific personas are the mechanism that makes the critique technically grounded.

---

## Domain Adaptation

The adversarial refinement loop is not specific to software architecture. Change the domain and judge personas to shift what the critic attacks and what the judges value.

**Product strategy — which feature to build next:**
```
/autoresearch:reason
Task: Should we build a native mobile app or optimize the web experience?
Domain: product
Iterations: 6
```
The critic will attack market sizing assumptions, competitive dynamics, and resource allocation. Judge personas focus on user value and business impact.

**Business decisions — pricing model:**
```
/autoresearch:reason
Task: Should we move from per-seat to usage-based pricing?
Domain: business
Judges: 5
Iterations: 8
```
Five judges simulate board-level disagreement. Convergence requires broader consensus — expect more rounds.

**Security approach — authentication architecture:**
```
/autoresearch:reason --chain security
Task: Should we implement passkeys or stick with password + TOTP?
Domain: security
Iterations: 6
```
The `--chain security` flag routes the converged design directly into a security audit loop. The reason loop produces the architecture; the security loop attacks it for vulnerabilities.

**Content refinement — technical blog post:**
```
/autoresearch:reason
Task: Draft a technical explanation of event sourcing for engineering candidates
Domain: content
Mode: creative
Iterations: 4
```
In `creative` mode, the critic targets clarity, audience fit, and engagement rather than technical correctness. Fewer iterations needed — content decisions converge faster than architecture decisions.

---

<div align="center">

**[Scenario Guides](README.md)** | **[Chains & Combinations](../chains-and-combinations.md)** | **[Guide Index](../README.md)**

</div>
