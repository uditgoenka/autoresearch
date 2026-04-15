---
description: Use when user types /autoresearch_security or asks for STRIDE / OWASP / red-team audit. Autonomous security audit — STRIDE threat model + OWASP Top 10 + red-team with 4 adversarial personas.
agent: build
---

EXECUTE IMMEDIATELY — do not deliberate, do not ask clarifying questions before reading the protocol.

## Argument Parsing (do this FIRST)

Extract these from $ARGUMENTS — the user may provide extensive context alongside flags. Ignore prose and extract ONLY flags/config:

- `--diff` — only audit files changed since last audit
- `--fix` — auto-fix confirmed Critical/High findings
- `--fail-on <severity>` — exit non-zero for CI/CD gating (critical/high/medium)
- `--scope <glob>` or `Scope:` — file globs to audit
- `--depth <level>` or `Depth:` — shallow (5 iterations), standard (15), deep (30+)
- `Focus:` — specific area to focus on (e.g., "authentication and authorization")
- `Iterations:` or `--iterations N` — integer for bounded mode (CRITICAL: run exactly N iterations then stop)

If `Iterations: N` or `--iterations N` is found, set `max_iterations = N`. Track `current_iteration` starting at 0. After iteration N, print final summary and STOP.

All remaining text in $ARGUMENTS is additional context — use it to understand scope but do not treat it as flags.

## Execution

1. Read the security workflow: `.opencode/skills/autoresearch/references/security-workflow.md`
2. If scope is missing — use `question` with batched questions per security-workflow.md
3. Execute the 7-step security audit
4. If bounded: after each iteration, check `current_iteration < max_iterations`. If not, STOP and print summary.

Stream all output live — never run in background.
