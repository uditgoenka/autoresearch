# Autoresearch for Codex

Codex distribution of autoresearch. Same 14 commands, same flags, same output contracts as the Claude Code version. Entry point: `$autoresearch <command>`.

---

## Install

```bash
git clone https://github.com/uditgoenka/autoresearch.git
cd autoresearch
./scripts/install.sh --codex --global
```

Maintainers regenerate the checked-in Codex packages with:

```bash
./scripts/transform.sh --codex
# Outputs plugins/autoresearch/skills/autoresearch/ and .agents/skills/autoresearch/
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

## All 14 Commands

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
| `$autoresearch improve` | 15 | Product research and PRD generation |
| `$autoresearch regression` | gate | Baseline/candidate stability verdict |

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
plugins/autoresearch/skills/autoresearch/   # plugin package
.agents/skills/autoresearch/                # direct Codex skill package
├── SKILL.md
├── autoresearch.md
├── debug.md ... regression.md
├── references/
└── scripts/
    ├── orchestrate.sh
    └── score-regression.sh
```

No `autoresearch-command-spec.json` — each command file is self-contained.

---

## Platform Differences

| Concept | Claude Code | Codex |
|---------|-------------|-------|
| Slash command | `/autoresearch:debug` | `$autoresearch debug` |
| Skills dir | `.claude/skills/` | `plugins/autoresearch/skills/` or `.agents/skills/` |
| User questions | `AskUserQuestion` | `request_user_input` or a direct question batch |
| Chain handoff | `handoff.json` | `handoff.json` (identical) |
| Results TSV | Same format | Same format |
| Output dirs | Same structure | Same structure |

`handoff.json` and all `*-results.tsv` files are identical across platforms — cross-platform chains work without modification.

Codex supports the core skill, bundled runtime, installation, and verification
surface. Claude Code hook guardrails are not claimed for Codex.

---

## Related Guides

- [getting-started.md](getting-started.md) — all 3 platform installs
- [chains-and-combinations.md](chains-and-combinations.md) — pipeline patterns (syntax-agnostic)
- [advanced-patterns.md](advanced-patterns.md) — transform.sh, CI/CD, multi-platform
