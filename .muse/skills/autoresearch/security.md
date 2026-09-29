---
name: autoresearch:security
description: "STRIDE + OWASP security audit with red-team adversarial personas"
argument-hint: "[Scope: <glob>] [Focus: <area>] [Iterations: N] [--diff] [--fix] [--fail-on <severity>] [--evals]"
---

EXECUTE IMMEDIATELY.

## Parse Arguments

Extract from $ARGUMENTS:
- `Scope:` or `--scope` — file globs to audit
- `Focus:` — specific area (auth, API, data handling, etc.)
- `Depth:` or `--depth` — quick (5 iterations), standard (15), deep (30+)
- `Iterations:` or `--iterations` — default 15. "unlimited" for unbounded.
- `--diff` — delta mode: only audit files changed since last audit
- `--fix` — after audit, auto-fix Critical/High findings (chains to fix)
- `--fail-on <severity>` — exit non-zero if findings at/above threshold (CI gate)
- `--evals`, `--evals-interval N`, `--chain`, `--<subcommand>`

## Setup (if required context missing)

If Scope missing and no --diff:
1. Scan codebase for tech stack, frameworks, API routes
2. request_user_input (single batch):
   Q1 (Scope): "What to audit?" — entire codebase, API + middleware, auth, external-facing
   Q2 (Depth): "How thorough?" — quick (5), standard (15), deep (30+), unlimited
   Q3 (Action): "What to do with findings?" — report only, report + auto-fix, report + CI gate
If all provided → skip.

## Setup Phase (once, before loop)

1. **Reconnaissance** — scan: package.json/requirements.txt (deps), .env.example (secrets), Dockerfile (infra), API route files (attack surface), auth/middleware (trust boundaries), DB schemas (data assets), CI/CD configs (supply chain)
2. **Asset Identification** — catalog data stores, auth systems, external services, user inputs
3. **Trust Boundary Mapping** — browser↔server, public↔authenticated, user↔admin, CI↔prod
4. **STRIDE Threat Model** — generate threats per category. Load `references/security-checklist.md` for checklist.
5. **Attack Surface Map** — entry points, data flows, abuse paths
6. **Baseline** — count known issues, initialize coverage tracking

Create output directory: `autoresearch/security-{YYMMDD}-{HHMM}/`
Write: overview.md, threat-model.md, attack-surface-map.md
TSV header: `# metric_direction: higher_is_better\niteration\ttimestamp\tfinding\tseverity\towasp\tstride\tevidence\tfile_line`

## Iteration Loop

### Phase 1: Review
- Read results TSV + coverage tracking
- Identify untested attack vectors from threat model
- Prioritize: untested OWASP categories → untested STRIDE → depth on existing

### Phase 2: Attack
- Adopt red-team persona for this vector (rotate: Security Adversary, Supply Chain, Insider Threat, Infra Attacker)
- Deep-dive into relevant code with adversarial mindset
- Look for: code paths, input handling, auth checks, data flows

### Phase 3: Validate
- Construct proof: file:line + specific attack scenario
- Every finding MUST have code evidence — no theoretical fluff
- Classify severity: Critical/High/Medium/Low/Info
- Map to OWASP (A01-A10) and STRIDE (S/T/R/I/D/E)

### Phase 4: Log
- Append finding to TSV
- Update coverage tracking
- Print coverage every 5 iterations:
  `OWASP: [A01✓ A02✓ A03✗ ...] X/10 | STRIDE: [S✓ T✓ R✗ ...] Y/6 | Score: Z`

### Composite Metric
`score = (owasp_tested/10)*50 + (stride_tested/6)*30 + min(findings, 20)`

### Eval Checkpoint
If --evals: check if current_iteration % interval == 0 → run checkpoint.

### Bounded Check
If bounded: current_iteration >= max_iterations → exit loop.

## After Loop

1. Write `findings.md` (severity-ranked)
2. Write `owasp-coverage.md`
3. Write `recommendations.md`
4. If `--fix` → chain to fix with Critical/High findings
5. If `--fail-on` → check findings against threshold, exit non-zero if exceeded

## Summary

Print: total findings by severity, OWASP coverage X/10, STRIDE coverage Y/6, composite score.

## Eval Checkpoint (--evals flag)

If --evals present:
- Compute interval: floor(max_iterations / 3), min 1. Fixed 10 if unbounded. Override: --evals-interval N.
- Every {interval} iterations, analyze results TSV.
- Print: `--- Eval Checkpoint (iterations {X}-{Y}) ---\nScore: {start} → {end} | New findings: {n} | Coverage: OWASP {x}/10, STRIDE {y}/6\n{recommendation}\n---`
- If no new findings 3+ checkpoints → recommend early stop.
- At loop end → full evals summary to evals-summary.md.

## Chain Handoff

After completion, write handoff.json to output directory: version "2.1.0", source "security", timestamp, status (COMPLETE|USER_INTERRUPT|BOUNDED|ERROR), results_tsv path, findings = all findings with severity + OWASP + STRIDE + file:line, config{scope, focus, depth}.
Invoke next target in --chain order. Propagate --evals flag.
