# Security

Use for `autoresearch:security`.

Setup gate:
- Require `Scope` unless `--diff` fully defines a safe delta audit.

Flow:
1. Recon the stack and dependencies.
2. Identify assets and trust boundaries.
3. Build a STRIDE threat model.
4. Sweep the attack surface against OWASP categories.
5. Log only findings with code evidence.
6. Produce structured reports and coverage output.

Outputs:
- `security/{YYMMDD}-{HHMM}-{slug}/overview.md`
- `security/{YYMMDD}-{HHMM}-{slug}/findings.md`
- `security/{YYMMDD}-{HHMM}-{slug}/security-audit-results.tsv`

Rules:
- `--fix` only applies to confirmed high-value findings.
- `--fail-on` is a gating threshold, not a scoring hint.
