# Autoresearch for Codex — v2.1.0

Codex distribution of autoresearch. Same 14 commands, same flags, same output contracts as the Claude Code version. Entry point: `$autoresearch <command>`.

---

## Install

```bash
npx skills add uditgoenka/autoresearch
```

Or via transform script if self-hosting:

```bash
./scripts/transform.sh
# Outputs Codex-ready files to codex/
```

---

## Invocation Syntax

Codex uses `$autoresearch` prefix:

| Claude Code | Codex |
|-------------|-------|
| `/autoresearch` | `$autoresearch` |
| `/autoresearch:debug` | `$autoresearch debug` |
| `/autoresearch:security` | `$autoresearch security` |
| `/autoresearch:evals` | `$autoresearch evals` |
| `/autoresearch:ship` | `$autoresearch ship` |

All 14 commands follow the same pattern: `$autoresearch <command> [flags]`.

---

## All 12 Commands

| Command | Default Iterations | Purpose |
|---------|-------------------|---------|
| `$autoresearch` | 25 | Core metric optimization loop |
| `$autoresearch plan` | one-shot | Structured planning wizard |
| `$autoresearch debug` | 15 | Root cause investigation |
| `$autoresearch fix` | 20 | Root-cause-first repair |
| `$autoresearch security` | 15 | STRIDE + OWASP audit |
| `$autoresearch ship` | linear | Deployment pipeline |
| `$autoresearch scenario` | 20 | Edge case + dimension exploration |
| `$autoresearch predict` | one-shot | Multi-persona foresight |
| `$autoresearch learn` | 10 | Documentation generation |
| `$autoresearch reason` | 8 | Adversarial design refinement |
| `$autoresearch probe` | 15 | Requirements interrogation |
| `$autoresearch evals` | one-shot | Results TSV analysis |

---

## Usage Examples

### Core loop

```
$autoresearch
Iterations: 20
Goal: Reduce bundle size below 200KB
Scope: src/**/*.ts
Metric: bundle size in KB (lower is better)
Verify: npm run build 2>&1 | grep "First Load JS"
Guard: npm test
```

### Debug with auto-fix

```
$autoresearch debug --fix
Scope: src/**/*.ts
Symptom: Payment confirmations silently failing
Iterations: 20
```

### Security audit (CI mode)

```
$autoresearch security --fail-on critical --diff
Iterations: 15
```

### Evals after loop

```
$autoresearch evals --format json --recommend
```

### Full chain

```
$autoresearch predict --chain scenario,debug,fix,ship
Scope: src/**
Goal: Full quality pipeline for v2.0 release
```

---

## Universal Flags (all commands)

| Flag | Purpose |
|------|---------|
| `Iterations: N` | Hard cap on loop iterations |
| `Iterations: unlimited` | Run until goal or convergence |
| `--evals` | Run evals analysis after loop |
| `--evals-interval N` | Checkpoint analysis every N iterations |
| `--chain <targets>` | Chain to next command(s) via handoff.json |

---

## File Layout (Codex)

After `transform.sh` or install:

```
codex/
├── autoresearch.sh
├── autoresearch_debug.sh
├── autoresearch_fix.sh
├── autoresearch_security.sh
├── autoresearch_ship.sh
├── autoresearch_scenario.sh
├── autoresearch_predict.sh
├── autoresearch_learn.sh
├── autoresearch_reason.sh
├── autoresearch_probe.sh
├── autoresearch_evals.sh
└── autoresearch_plan.sh
```

No `autoresearch-command-spec.json` — each command file is self-contained.

---

## Platform Differences

| Concept | Claude Code | Codex |
|---------|-------------|-------|
| Slash command | `/autoresearch:debug` | `$autoresearch debug` |
| Skills dir | `.claude/skills/` | `codex/` |
| User questions | `AskUserQuestion` | Direct question batch |
| Chain handoff | `handoff.json` | `handoff.json` (identical) |
| Results TSV | Same format | Same format |
| Output dirs | Same structure | Same structure |

`handoff.json` and all `*-results.tsv` files are identical across platforms — cross-platform chains work without modification.

---

## Related Guides

- [getting-started.md](getting-started.md) — all 3 platform installs
- [chains-and-combinations.md](chains-and-combinations.md) — pipeline patterns (syntax-agnostic)
- [advanced-patterns.md](advanced-patterns.md) — transform.sh, CI/CD, multi-platform
