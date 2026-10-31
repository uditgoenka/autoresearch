# Contributing to Autoresearch

Whether you're fixing a typo, adding examples, creating a new sub-command, or improving the loop protocol — this guide will get you up and running.

## Quick Start

Autoresearch is Markdown files that Claude Code, OpenCode, Codex, pi, and Muse discover from `skills/` and `commands/` directories. No build step, no compilation — edit a `.md` file, invoke the skill, see your changes.

```bash
# 1. Clone the repo
git clone https://github.com/uditgoenka/autoresearch.git
cd autoresearch

# 2. Install via guided installer
./scripts/install.sh --claude --global   # Claude Code
./scripts/install.sh --opencode --global # OpenCode
./scripts/install.sh --codex --global    # Codex
./scripts/install.sh --pi --global       # pi (coding agent)
./scripts/install.sh --muse --global     # Muse

# 3. Or symlink for live editing (recommended for development)
ln -s $(pwd)/.claude/skills/autoresearch ~/.claude/skills/autoresearch
ln -s $(pwd)/.claude/commands/autoresearch ~/.claude/commands/autoresearch
ln -s $(pwd)/.claude/commands/autoresearch.md ~/.claude/commands/autoresearch.md
```

### Multi-Platform Sync

The canonical source is `.claude/`. After making changes, run the transform to sync all platforms:

```bash
./scripts/transform.sh              # sync to OpenCode + Codex + pi + Muse
./scripts/transform.sh --opencode   # OpenCode only
./scripts/transform.sh --codex      # Codex only
./scripts/transform.sh --pi          # pi only
./scripts/transform.sh --muse       # Muse only
```

## Repository Structure (v2.2.3)

```
autoresearch/
├── .claude/                                       ← CANONICAL SOURCE — edit here first
│   ├── skills/autoresearch/
│   │   ├── SKILL.md                               ← Thin routing table
│   │   └── references/                            ← Shared routing and review references
│   └── commands/
│       ├── autoresearch.md                        ← Core loop (self-contained, ~110 lines)
│       └── autoresearch/                          ← 13 subcommand files (self-contained)
├── .opencode/                                     ← OpenCode port (generated via transform.sh)
├── .agents/ + plugins/                            ← Codex port (generated via transform.sh)
├── pi-extension/                                  ← pi (coding agent) extension (generated via transform.sh)
│   ├── src/                                       ← Guardrails ported from Claude hooks → pi events
│   ├── skills/autoresearch/                       ← Skill + references + scripts
│   └── prompts/                                   ← 14 command prompt templates
├── claude-plugin/                                 ← Distribution package (Claude Code plugin install)
├── scripts/
│   ├── install.sh                                 ← Guided installer (4 platforms)
│   ├── transform.sh                               ← .claude/ → .opencode/ + .agents/ + pi-extension/ sync
│   ├── release.sh                                 ← Release automation
│   └── release.md                                 ← Release checklist
├── guide/                                         ← Guides — one per command + advanced patterns
├── docs/                                          ← Project docs (architecture, changelog, standards)
├── COMPARISON.md                                  ← Karpathy vs Claude Autoresearch
└── CONTRIBUTING.md                                ← You are here
```

### What Each File Does

| File | Purpose | Edit when... |
|------|---------|-------------|
| `.claude/skills/autoresearch/SKILL.md` | Thin routing table — subcommand list, defaults, universal flags | Adding subcommands, changing defaults |
| `.claude/commands/autoresearch.md` | Core loop — self-contained instructions (~110 lines) | Changing loop behavior |
| `.claude/commands/autoresearch/*.md` | Subcommand files — each self-contained with full instructions | Modifying any subcommand |
| `references/security-checklist.md` | STRIDE + OWASP checklist (loaded by security command) | Adding security checks |
| `references/predict-personas.md` | 5 expert personas (loaded by predict command) | Adding/modifying personas |
| `references/reason-judge-protocol.md` | Adversarial refinement protocol (loaded by reason command) | Changing judge/critic behavior |
| `scripts/transform.sh` | Canonical transform (.claude/ → .opencode/ + .agents/ + claude-plugin/ + pi-extension/) | Adding new commands, reference files, or generated helper updates |
| `claude-plugin/` | Distribution package — synced from .claude/ during release | Don't edit directly — edit .claude/ |
| `pi-extension/` | pi extension — skills + prompts synced from .claude/ via transform.sh; guardrails in `src/` ported from Claude hooks | Edit `src/` for guardrail logic; skills/prompts are generated — edit .claude/ |

## What to Contribute

### High-Value

| Type | Examples | Difficulty |
|------|----------|-----------|
| **New domain examples** | Add to `guide/examples-by-domain.md` | Easy |
| **Verification script templates** | Reusable verify/guard commands for common metrics | Easy |
| **Bug fixes** | Loop edge cases, incorrect behavior | Medium |
| **New sub-commands** | `/autoresearch:refactor`, `/autoresearch:test` | Medium |
| **OWASP/STRIDE additions** | New security checks | Medium |
| **Protocol improvements** | Better stuck-detection, smarter ideation | Hard |
| **MCP integration patterns** | Database, API, analytics verification examples | Hard |

### Low-Value (Please Don't)

- Reformatting or restructuring files without functional changes
- Adding comments to explain obvious things
- Whitespace-only changes

## Adding a New Sub-Command

### 1. Create the command file

```
.claude/commands/autoresearch/yourcommand.md
```

Self-contained file with: YAML frontmatter (`name`, `description`, `argument-hint`), argument parsing, setup gate, loop/phases, output, chain handoff. Target: 80-120 lines.

### 2. Register in SKILL.md

Add one row to the subcommands table:
```markdown
| `/autoresearch:yourcommand` | Description | Default iterations |
```

### 3. Create reference file (only if needed by 3+ commands)

Only create a reference in `references/` if shared by multiple commands. Single-command logic stays in the command file.

### 4. Run transform + update docs

```bash
./scripts/transform.sh   # sync to OpenCode + Codex + pi + Muse
```

Update: README.md (commands table), guide/ (new guide file), COMPARISON.md (subcommand count).

## Commit Messages

[Conventional commits](https://www.conventionalcommits.org/):

| Prefix | When |
|--------|------|
| `feat:` | New feature or sub-command |
| `fix:` | Bug fix |
| `docs:` | Documentation-only |
| `refactor:` | Restructuring without behavior change |
| `chore:` | Maintenance, version bumps |

## Pull Request Guidelines

1. **One PR = one feature.** Don't bundle unrelated changes.
2. **Branch from `master`.** Target `master` as base.
3. **Run `scripts/transform.sh`** after any changes to `.claude/`.
4. **Update docs** — README, guide, COMPARISON as needed.
5. **Don't bump the version.** Maintainers handle via `scripts/release.sh`.

## Testing

The repo includes shell-based verification for the generated distributions and hook/runtime contracts:

1. Symlink your working tree (see Quick Start)
2. Open Claude Code in a real project
3. Invoke the command (`/autoresearch`, `/autoresearch:plan`, etc.)
4. Verify behavior matches your changes
5. Try edge cases — wrong metric? 0 files in scope? Guard always fails?

For maintainer workflows, the canonical checks are:

- `bash scripts/transform.sh` — regenerate platform distributions and bundled runtime helpers
- `bash tests/test-maintenance.sh` — transform idempotence and release-prep guards
- `bash tests/test-hooks.sh` — Claude hook contracts and fail-open behavior
- `bash tests/test-pi.sh` — pi extension guardrail contracts (ported hooks) and TypeScript type-check

## Release Process

Maintainers use `scripts/release.sh`. See `scripts/release.md` for details.

```bash
./scripts/release.sh 2.2.3 --title "Release 2.2.3"
```

Contributors don't need to bump versions.

## Getting Help

- **Questions?** Open an [issue](https://github.com/uditgoenka/autoresearch/issues)
- **Ideas?** Open an issue with `[Idea]` prefix
- **Discussion?** Tag [@uditgoenka](https://github.com/uditgoenka) in your PR

Thanks for contributing!

## Hook Development

### Adding a New Hook

1. Create `.claude/hooks/autoresearch/{name}.cjs`
2. Use the shared library: `require('./lib/ar-hook-utils.cjs')`
3. Follow the pattern:
   ```js
   'use strict';
   const { isEnabled, safeParseStdin, log, block, allow, inject } = require('./lib/ar-hook-utils.cjs');
   try {
     if (!isEnabled('hook-name')) process.exit(0);
     const stdin = safeParseStdin();
     if (!stdin) process.exit(0);
     // ... hook logic ...
     process.exit(0);
   } catch {
     process.exit(0); // fail-open
   }
   ```
4. Register in `hooks.json` under the correct event
5. Run `bash scripts/transform.sh` to update the plugin distribution and bundled runtime helpers
6. Run `bash tests/test-hooks.sh` to verify

### Hook Rules

- **Fail-open:** Always wrap in try/catch, always exit 0 on error, and emit a visible redacted diagnostic when available
- **No console.log:** Corrupts stdout JSON. Use `process.stderr.write()` for debug
- **No external deps:** Pure Node.js builtins only (exception: vendored `lib/ignore.cjs`)
- **Exit codes:** 0 = allow/inject, 2 = block. No other exit codes
- **State:** Use the OS temporary directory via `loadSessionState()` / `saveSessionState()`; this is not a repo path

### Testing Hooks

```bash
# Syntax check
node --check .claude/hooks/autoresearch/my-hook.cjs

# Manual test
echo '{"tool_name":"Read","tool_input":{"file_path":"test.txt"}}' | node .claude/hooks/autoresearch/my-hook.cjs
echo "Exit code: $?"

# Full test suite
bash tests/test-hooks.sh
```

## pi Hook Development

The pi extension ports the Claude hooks to pi's extension event system. Guardrail logic lives in `pi-extension/src/hooks/*.ts` as pure functions (no stdin/stdout — pi passes events in-process); `pi-extension/src/guardrails.ts` wires them to pi events (`tool_call`, `before_agent_start`, `input`, `session_start`, `session_shutdown`). Shared helpers are in `pi-extension/src/lib/`.

### Adding a New pi Hook

1. Create `pi-extension/src/hooks/{name}.ts` exporting a pure function that returns a `{ block?, reason?, warning?, needsConfirm?, text? }` result.
2. Wire it to the matching pi event in `pi-extension/src/guardrails.ts`.
3. Guard with `isHookEnabled("{name}")` (honors `AR_DISABLE_{NAME}`).
4. Fail open — wrap logic in try/catch, never throw to the event handler.
5. Add cases to `tests/test-pi.sh`.
6. Run `bash tests/test-pi.sh` (and `tsc --strict` is covered by the suite's type-check step).

### pi Hook Rules

- **Fail-open:** wrap in try/catch; a guardrail malfunction never blocks work
- **No external deps:** Node.js builtins only (vendored `lib/ignore.ts`)
- **No stdin/stdout:** pi passes events in-process; return an object, don't `process.exit`
- **State:** use `loadSessionState()` / `saveSessionState()` (OS temp dir, keyed by cwd + session id)
- **Logs:** `~/.pi/agent/autoresearch/.logs/<projectHash>/hook-log.jsonl` (bounded metadata only — no paths, commands, or secrets). Do NOT write under `~/.pi/agent/hooks/` — pi renamed hooks→extensions and warns on a legacy `hooks/` dir.

### Testing pi Hooks

```bash
# Full test suite (53 cases: guardrail logic + tsc --strict type-check)
bash tests/test-pi.sh

# Type-check only (needs pi-coding-agent types resolvable)
cd pi-extension && npx -y -p typescript@5.6 tsc --noEmit --strict --moduleResolution Bundler --module ESNext --target ES2022 --skipLibCheck --esModuleInterop --lib ES2022 --types "[]" src/index.ts
```
