---
name: autoresearch:improve
description: "Research ICP challenges, discover improvements, generate PRDs"
argument-hint: "[Goal: <text>] [--icp <text>] [--discover] [--no-discover] [--seeds <categories>] [--depth shallow|standard|deep] [Iterations: N] [--evals]"
---

EXECUTE IMMEDIATELY.

## Parse Arguments

Extract from $ARGUMENTS:
- `Goal:` — product area to improve (or full $ARGUMENTS if no keyword)
- `--icp` or `ICP:` — ideal customer profile description
- `--discover` — force inline codebase scan even when context exists
- `--no-discover` — skip auto-discover, warn instead
- `--seeds <categories>` — override default research category seeds
- `--depth` — shallow (5 iterations), standard (15), deep (30)
- `--features` — comma-separated feature names to pre-select for PRD generation
- `Iterations:` or `--iterations` — default 15. "unlimited" for unbounded.
- `--evals`, `--evals-interval N`

If upstream `handoff.json` exists in CWD → read it. Map source findings to default seed categories:
- probe → ICP challenges, UX & experience
- predict → Competitor gaps, Revenue & growth
- debug/security → Competitor gaps, ICP challenges
- Override with `--seeds`.

## Setup (if Goal or ICP missing)

request_user_input (single batch):
  Q1 (Goal): "What product area to improve?" — open text
  Q2 (ICP): "Who is your ideal customer?" — open text describing target buyer/user
  Q3 (Pain points): "Top 3 pain points your customers face?" — open text
  Q4 (Competitors): "Key competitors?" — open text, or "skip"
  Q5 (Depth): "How deep?" — shallow (5 iterations, quick scan), standard (15, recommended), deep (30+, exhaustive)
If all provided inline → skip.

## Phase 1: Product Context

Resolve product context (priority chain):
1. Learn summary (`autoresearch/learn-*/summary.md`, most recent) → read it
2. README.md (≥500 chars, non-boilerplate) → extract product description
3. `package.json` / `pyproject.toml` / `Cargo.toml` description (≥10 chars) → use it
4. If ALL above absent AND NOT `--no-discover` → auto-discover: scan 10 key files (manifest, routes, models, config), cap 1500 tokens
5. If `--discover` → force scan regardless of above
6. If nothing found → warn: "No product context. Run `$autoresearch learn --mode summarize` for better results."

## Phase 2: Research Loop

Create output directory: `autoresearch/improve-{YYMMDD}-{HHMM}/`
TSV header: `# metric_direction: higher_is_better`
Columns: `iteration|timestamp|category|research_question|status|source|insight_problem|insight_mechanism|confidence|classification`

**5 research categories:**
1. ICP challenges — pain points, jobs-to-be-done, unmet needs
2. Competitor gaps — weaknesses, missing features, technical differentiators
3. Market trends — timing signals, emerging patterns, regulatory shifts
4. UX & experience — interaction models, onboarding, retention mechanics
5. Revenue & growth — pricing, acquisition, monetization, upsell/expansion

**Iteration protocol:**
- Reserve first 5 iterations: one per category (forced breadth)
- Remaining iterations: target categories with richest signal
- Per iteration: form research question → WebSearch → synthesize → normalize to canonical insight schema → classify (new/extension/duplicate) → tag confidence (HIGH: 3+ sources, MEDIUM: 2, LOW: 1) → cross-check against codebase → log
- **Saturation:** net-new insights < 2 for 3 consecutive non-reserved iterations → SATURATED, exit loop
- Hard ceiling (Iterations flag) as infinite-loop guard

**Insight schema:** `{problem: 10-word canonical form, affected_persona: ICP segment, proposed_mechanism: how to address, expected_outcome: what success looks like}`
**Classification:** New = novel {problem, persona} pair. Extension = same pair, different mechanism. Duplicate = same pair + mechanism → skip.

### Eval Checkpoint
If --evals: check if current_iteration % interval == 0 → run checkpoint.
Print: `--- Eval Checkpoint (iterations {X}-{Y}) ---\nInsights: {total} (+{new}) | Categories: {covered}/5 | Saturation: {window}/3\n{recommendation}\n---`

## Phase 3: Feature Ranking + Selection

1. **ICP binary gate** — filter insights not serving the stated ICP
2. **3-tier bucketing** — Must-have / Nice-to-have / Moonshot
3. **Pairwise ranking** within Must-have tier only (cap 7-10 items)
4. **2-sentence rationale** per item citing research evidence
5. **Confidence indicator** per item (HIGH / MEDIUM / LOW)

Write `improvement-plan.md` with full tiered ranking.

request_user_input (multi-select): present tiered list, user selects which features become PRDs.
If `--features` provided → pre-select matching items, still show for confirmation.

## Phase 4: PRD Generation

Per selected feature, write `prd-{feature-slug}.md`:
- Top disclaimer: "Auto-generated from research findings. DECISION NEEDED items and LOW-confidence sections require your judgment."
- Problem statement (from research evidence chain)
- User stories (from ICP + persona data)
- Requirements (functional + non-functional, MoSCoW from tier)
- Acceptance criteria
- Technical approach (from codebase context, framed as "suggested starting points")
- Risks + confidence (evidence tiers: primary = codebase, secondary = web research)
- Success metrics
- `DECISION NEEDED` markers for unresolvable tradeoffs
- `Open Questions` section

Write `research-findings.md` — all insights with citations + confidence.
Write `summary.md` — overview, research stats, category coverage, saturation status.

## Summary

Print: total iterations, insights discovered (new/extension), categories covered, saturation status, PRDs generated, output directory path.

## Eval Summary (--evals flag)

If --evals: write `evals-summary.md` to output directory with full analysis.

## Handoff

Write `handoff.json`: version "2.1.0", source "improve", timestamp, status (COMPLETE|SATURATED|USER_INTERRUPT|BOUNDED|ERROR), results_tsv path, findings = improvements with tier + confidence + prd_path, config{goal, icp, depth, categories_explored, insights_total, prds_generated}.
Improve is a terminal emitter — no downstream chain invocation.
