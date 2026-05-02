# Probe

Use for `autoresearch:probe`.

Setup gate:
- Require a `Topic`.
- Optional `Scope` narrows codebase interrogation.

Flow:
1. Identify the decision, feature, or ambiguous goal being probed.
2. Interrogate assumptions through product, architecture, security, operations, UX, data, edge-case, and adversarial lenses.
3. Ask only questions that can produce net-new constraints.
4. Stop when new constraints saturate or bounded iterations end.
5. Emit an autoresearch-ready config with Goal, Scope, Metric, Direction, Verify, and Guard when enough constraints exist.
6. If `--chain` is present, hand the generated config to the requested next workflow.

Rules:
- Treat user answers and code evidence as constraints, not suggestions.
- Preserve contradictions and unresolved assumptions explicitly.
- Do not begin implementation during probing.
