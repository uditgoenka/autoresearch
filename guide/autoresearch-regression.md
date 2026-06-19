# /autoresearch:regression — Regression Stability Gate

Prove a change is safe to push. Captures baseline behavior from an isolated `git worktree` of the base ref, re-runs the candidate across 8 dimensions, and emits a single tiered **STABLE / UNSTABLE** verdict you can wire into CI.

It is a **protocol, not a bundled framework** — it orchestrates your project's own test / bench / snapshot / migrate commands.

---

## When to Use

- Pre-push / pre-merge gate — "did my change break anything that worked before?"
- CI stage that must block a regression but tolerate noise (flaky tests, perf jitter)
- Verifying a risky refactor against the behavior it was supposed to preserve
- The final gate in a chain: `--predict --evals --fix --ship`

**Not for:** finding net-new bugs in code that never worked (use `:debug`), fixing a known error (use `:fix`), security review (use `:security`), or optimizing a metric (use `/autoresearch`). Regression only judges **green→red transitions**, not absolute quality.

---

## Quick Start

```
/autoresearch:regression
Base: origin/main
Scope: src/**
```

The agent:
1. Auto-detects per-dimension verify commands (package.json scripts, Makefile, nx, migrate/bench/snapshot config)
2. Probe-on-launch (AskUserQuestion) confirms commands + base ref + which dimensions run — auto-skips on CI / no-TTY / autonomous / complete-config
3. **Classification** — establishes the baseline green-set per dimension and tags every unit (only green→red is gateable)
4. **Baseline capture** — `git worktree` of the base SHA, cached by SHA
5. **Differential loop** — runs the candidate vs baseline per dimension × axis, computing a `regressed` bool + 0–100 subscore
6. **Hunter** — on a confirmed HARD regression, root-causes it (bisect only when 3/3 reproducible)
7. **Verdict** — any HARD green→red = UNSTABLE; else weighted SCORE ≥ 95 = STABLE; prints the score math

---

## Flags

| Flag | Purpose | Default |
|------|---------|---------|
| `Base:` / `--base <ref>` | Base ref to diff against | `git merge-base HEAD main` |
| `Scope:` / `--scope <glob>` | File globs limiting the change surface | full diff |
| `--select auto\|full\|affected` | Test selection — `auto` uses the affected-test mapper if present, else FULL. Never a silent subset | `auto` |
| `--samples N` | SCORE samples per side (independent processes) | `7` |
| `--noise-band %` | Perf tolerance band | `5%` |
| `--matrix` | Opt-in matrix axis | off |
| `--max-runs N` | Run ceiling (dims × axes × samples × cells) | `200` |
| `--baseline-cache` | Reuse `baseline/<full-sha>/` by SHA | on |
| `Baseline: <prebuilt-ref>` | Bypass capture, use a prebuilt baseline | off |
| `--probe` / `--probe deep` / `--no-probe` | Launch interrogation depth | `--probe` |
| `Iterations: N` | Repeat-axis count for repeat sweeps | per axis |
| `--predict` `--reason` `--debug` `--fix` `--fix-cycles N` `--evals` `--evals-interval N` `--chain` | Composable family flags | off |

---

## The Core Invariant

**A regression is a green→red transition ONLY.** Everything else is classified out and never counted against you:

| State | Meaning | Gated? |
|-------|---------|--------|
| `regression-eligible` | green on baseline, now red | **YES** — the only thing that gates |
| `pre-existing` | red→red (already failing) | no — excluded |
| `new-coverage` | absent→red (brand-new test) | no — new coverage, ungated |
| `flaky` | nondeterministic on baseline | no — routed to the flakiness SCORE |
| `baseline-unavailable` | dimension was never green | no — advisory only |

Units are matched by **test-id first, then path**. Flakiness is run N× on **both** baseline and candidate — a candidate failure that falls inside the baseline flake-envelope routes to the flakiness score, never to a regression. Note `5/5 green ≠ non-flaky`: detection probability is `1−(1−p)^n` (≈23% at p=5%, n=5), and the report prints it.

---

## 8 Dimensions

| Dimension | Tier | Compare |
|-----------|------|---------|
| functional | **HARD** | baseline green-set vs candidate; a new failure = regression |
| api-contract | **HARD** | schema / exports diff → breaking? |
| data-migration | **HARD** | up applies clean + idempotent re-apply + app boots / schema valid (schema+rowcount roundtrip opt-in) |
| integration-e2e | **HARD** | e2e green-set diff |
| flakiness | SCORE | run N× on baseline + candidate, count nondeterministic |
| performance | SCORE | K independent-process samples/side, Mann–Whitney U **and** effect beyond `max(noise-band%, k·stdev)` |
| resource | SCORE | memory / bundle / size delta vs budget |
| visual-ui | SCORE | containerized render; `maxDiffPixelRatio` + AA-detection, SSIM for per-page escalation |

A dimension that can't run is listed as **UNAVAILABLE** in the verdict — never silently passed.

---

## Verdict

```
Any HARD dimension green→red ............. UNSTABLE   (hard block, no score can save it)
Else stability_score = Σ(weight × subscore) over SCORE dims that ran
     weights: flakiness .30 · performance .30 · resource .20 · visual-ui .20
     (renormalized over the dims actually present)
STABLE  iff  stability_score ≥ 95          (threshold + weights overridable)
No dimension ran ......................... BASELINE_UNAVAILABLE (fail-safe, never a false green)
```

The report prints the **per-dimension contribution table** so the math is auditable, and the displayed score is floored — it can never read ≥ threshold while the verdict is UNSTABLE. Backed by `scripts/score-regression.sh verdict <results.tsv>` (exit `0` STABLE / `1` UNSTABLE).

---

## Baseline Capture

`git worktree add --detach <full-sha>` → `baseline/<full-sha>/` (detached SHA avoids "branch already checked out" when `Base == HEAD`). Per worktree: `git submodule update --init` + a SHA-pinned dependency install, so `--baseline-cache` stays sound across reuse. Per-dimension **setup tiers** keep it cheap — `api-contract` is a file-diff with no build; `functional` / `integration-e2e` / `data-migration` get a full env. The worktree is removed + pruned on completion **or** crash. `Baseline: <prebuilt-ref>` skips capture entirely.

---

## Noise Discipline

The SCORE tier is built to survive a noisy CI box without crying wolf:

- **performance** — each sample is an **independent process launch** (warmups discarded), never an in-process loop; autocorrelation / GC / thermal drift otherwise break Mann–Whitney's independence assumption. A delta is flagged only when it's both statistically significant **and** beyond `max(noise-band%, k·stdev)`. At `--samples 7` the test catches roughly ≳1σ regressions — raise it for tight gates.
- **visual-ui** — renders in a container, compares with `maxDiffPixelRatio` and anti-aliasing detection, and escalates to SSIM per page so font-hinting jitter doesn't read as a diff.
- **--max-runs** — projected `dims × axes × samples × matrix-cells`; over the ceiling (default 200) it warns and asks to confirm (CI aborts with a message instead of stalling).

---

## data-migration Guard

Opt-in and **forward-only by default**. Before any migration runs, the DB URL must pass an **anchored** allowlist — the host is exactly `localhost` / `127.0.0.1` / a container or service hostname, **or** the database name carries a `_test` / `_ci` suffix. A bare substring (`test` inside `latest`, `ci` inside `precision`) does **not** qualify. Anything else is refused — ephemeral targets only, never dev/prod — and even an allowlisted URL requires explicit confirmation before applying. A missing down-migration is a forward-only advisory, **never a finding**.

---

## --fix Re-gate

`--fix` repairs the blocking regressions, max **3 cycles** (`--fix-cycles N`). Each cycle MUST strictly shrink the blocking-set or it STOPs with "fix not converging". Intermediate re-gates scope to the failing + touched dimensions; the final cycle runs the full battery. There is **no HARD-gate bypass** — a fix has to actually make the gate green.

---

## Chain Integration

### Composable flags (in-command)

```
--predict     # 5-persona pre-empt of likely regressions before the gate runs
--reason      # adversarial root-cause when a regression's cause is ambiguous
--debug       # force the Hunter even on SCORE / non-deterministic findings
--fix         # repair blocking regressions, then re-gate (≤ 3 cycles)
--evals       # mid-run checkpoints + evals-summary.md
```

### Downstream (terminal gate)

`handoff.json` exposes `verdict ∈ {STABLE, UNSTABLE, BASELINE_UNAVAILABLE}` — `ship` reads it for its deploy-gate.

```
/autoresearch:regression --predict --evals --fix --ship
```

predict → gate → (Hunter on HARD) → fix(≤3) → re-gate → ship **iff** STABLE. Shipping still needs explicit deploy approval — the gate never auto-deploys.

---

## Output Structure

```
autoresearch/regression-{YYMMDD}-{HHMM}/
├── stability-report.md       ← verdict + per-dimension score math
├── regression-results.tsv    ← one row per dim × axis × run
├── dimensions/<dim>.md        ← per-dimension detail
├── baseline/<full-sha>/       ← cached baseline worktree artifacts
├── evals-summary.md           ← if --evals
└── handoff.json               ← chain integration (verdict + findings)
```

TSV columns: `iteration · timestamp · dimension · axis · tier · classification · baseline · candidate · delta · regressed · subscore · severity · status · file_line · description`.

---

## Examples

### Pre-push gate on a feature branch

```
/autoresearch:regression
Base: origin/main
Scope: src/**
```

### Tight perf gate with more samples

```
/autoresearch:regression
Base: origin/main
--samples 15
--noise-band 2
```

### Hard-stakes full run (no affected-test subset)

```
/autoresearch:regression
Base: v2.1.3
--select full
--matrix
```

### Gate, auto-fix, then ship

```
/autoresearch:regression --predict --evals --fix --ship
Base: origin/main
```

---

## Tips

- **Trust the green→red invariant.** A failing brand-new test or a pre-existing failure will NOT mark you UNSTABLE — only behavior you actually broke does.
- **`--select full` for releases.** The `auto` mapper (`jest --findRelatedTests`, `nx affected`) is best-effort static-import analysis and is blind to dynamic / runtime / global-setup couplings; a STABLE earned on a subset prints a caveat.
- **Raise `--samples` before tightening `--noise-band`.** At 7 samples the perf test only catches ≳1σ effects; a tighter band without more samples just adds false positives.
- **Cache survives across runs.** `--baseline-cache` keys on the full SHA, so repeated gates against the same base ref skip recapture.
- **Read the score math, not just the verdict.** The per-dimension contribution table tells you which SCORE dimension is dragging you under 95.

---

## Related

- [/autoresearch:debug](autoresearch-debug.md) — the Hunter engine regression reuses for root cause
- [/autoresearch:fix](autoresearch-fix.md) — the repair engine behind `--fix`
- [/autoresearch:ship](autoresearch-ship.md) — reads the regression verdict for its deploy-gate
- [/autoresearch:predict](autoresearch-predict.md) — pre-empt likely regressions before the gate
- [/autoresearch:evals](autoresearch-evals.md) — analyze the results TSV
- [Chains & Combinations](chains-and-combinations.md) — multi-command pipelines
