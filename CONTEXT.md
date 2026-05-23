# Autoresearch Domain Glossary

Terms meaningful to domain experts. Implementation details live in code, not here.

## Output Types (per subcommand)

| Term | Subcommand | Definition |
|------|-----------|------------|
| **Constraint** | probe | A requirement extracted from persona interrogation. Atomic, deduplicated, has confidence and evidence. Constraints are things the product MUST NOT violate. |
| **Finding** | predict, security | A code-derived observation from expert personas or STRIDE/OWASP analysis. Has severity, confidence, and file:line evidence. Findings describe what IS (current state). |
| **Hypothesis** | debug | A falsifiable claim about a bug's root cause. Tested via investigation, classified as confirmed/disproven/inconclusive. |
| **Scenario** | scenario | An edge case generated across 12 dimensions. Classified as new/extension/duplicate with severity. |
| **Insight** | improve | An externally-researched product improvement opportunity, structured as {problem, affected_persona, proposed_mechanism, expected_outcome}. Unlike findings (code-derived) or hypotheses (falsifiable bug claims), insights originate from market data, user research, or competitive analysis and represent synthesized-but-unvalidated understanding. |

## Loop Shapes

| Shape | Subcommands | Pattern | Notes |
|-------|------------|---------|-------|
| **Metric loop** | core, fix | commit → verify metric → keep/discard based on direction | |
| **Saturation loop** | probe | iterate until net-new output drops below threshold for N consecutive rounds | Internal extraction |
| **Saturation loop** | improve | iterate until net-new output drops below threshold for N consecutive rounds | External research; LLM-judged dedup; triangulation replaces git-as-memory |
| **Hypothesis loop** | debug, security | form hypothesis → investigate → classify → repeat | |
| **Refinement loop** | reason | generate candidates → critique → judge → converge | |
| **Exploration loop** | scenario, learn | generate → classify → check coverage/saturation | |
| **One-shot** | plan, predict, evals, ship | No iteration loop. Phased pipeline or single-pass analysis. | |

## Scoring Systems

| System | Subcommand | How it works |
|--------|-----------|--------------|
| **Severity ranking** | debug, security, predict | Critical/High/Medium/Low/Info per finding |
| **Composite metric** | security | `score = (owasp_tested/10)*50 + (stride_tested/6)*30 + min(findings, 20)` |
| **Tiered ranking** | improve | ICP binary gate → Must-have/Nice-to-have/Moonshot tiers → pairwise within Must-have → confidence indicator |
| **Convergence** | reason | Incumbent wins N consecutive judge rounds → converged |
| **Saturation** | probe, improve | Net-new below threshold for 3 consecutive rounds → saturated |

## Key Concepts

| Term | Definition |
|------|------------|
| **ICP** | Ideal Customer Profile. The specific customer segment the product targets. Used by improve to filter and prioritize insights by relevance to the target buyer. |
| **Product context** | Background understanding of what a product does, derived from existing docs. Sourced (in priority order) from: learn summary (`autoresearch/learn-*/summary.md`), README.md (≥500 chars), package manifest description (≥10 chars), or conditional auto-discover scan. NOT `docs/codebase-summary.md` which is autoresearch's own doc. |
| **Chain** | Sequential handoff between subcommands via `handoff.json`. Each command reads upstream findings and passes its own downstream. |
| **Terminal emitter** | A command whose output is consumed by humans or external tools, not by other autoresearch subcommands. Writes handoff.json for protocol consistency but is the last autoresearch link. Example: improve produces PRDs for `/ck:plan` and `/ck:cook`, not for autoresearch re-entry. |
| **Guard** | An optional safety command (e.g., `npm test`) that must pass for a "keep" decision. Reverts on failure regardless of metric improvement. |
| **Metric direction** | `higher_is_better` or `lower_is_better`. Written as TSV comment on line 1. Determines whether improvement means going up or down. |
| **Saturation** | The state where a loop produces diminishing returns. Detected when net-new output drops below a threshold for N consecutive iterations. |
| **Keep/discard (improve)** | Improve reuses the standard keep/discard vocabulary but applies it to insights, not code commits. A novel insight is "kept" (logged as `keep`); a duplicate is "discarded" (logged as `discard`). This preserves evals compatibility. |
