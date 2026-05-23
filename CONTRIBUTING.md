# Contributing to Autoresearch

Whether you're fixing a typo, adding examples, creating a new sub-command, or improving the loop protocol — this guide will get you up and running.

## Quick Start

Autoresearch is Markdown files that Claude Code, OpenCode, and Codex discover from `skills/` and `commands/` directories. No build step, no compilation — edit a `.md` file, invoke the skill, see your changes.

```bash
# 1. Clone the repo
git clone https://github.com/uditgoenka/autoresearch.git
cd autoresearch

# 2. Install via guided installer
./scripts/install.sh --claude --global   # Claude Code
./scripts/install.sh --opencode --global # OpenCode
./scripts/install.sh --codex --global    # Codex

# 3. Or symlink for live editing (recommended for development)
ln -s $(pwd)/.claude/skills/autoresearch ~/.claude/skills/autoresearch
ln -s $(pwd)/.claude/commands/autoresearch ~/.claude/commands/autoresearch
ln -s $(pwd)/.claude/commands/autoresearch.md ~/.claude/commands/autoresearch.md
```

### Multi-Platform Sync

The canonical source is `.claude/`. After making changes, run the transform to sync all platforms:

```bash
./scripts/transform.sh              # sync to OpenCode + Codex
./scripts/transform.sh --opencode   # OpenCode only
./scripts/transform.sh --codex      # Codex only
```

## Repository Structure (v2.1.0)

```
autoresearch/
├── .claude/                                       ← CANONICAL SOURCE — edit here first
│   ├── skills/autoresearch/
│   │   ├── SKILL.md                               ← Thin routing table (41 lines)
│   │   └── references/                            ← 3 focused reference files
│   └── commands/
│       ├── autoresearch.md                        ← Core loop (self-contained, ~110 lines)
│       └── autoresearch/                          ← 12 subcommand files (self-contained)
├── .opencode/                                     ← OpenCode port (generated via transform.sh)
├── .agents/ + plugins/                            ← Codex port (generated via transform.sh)
├── claude-plugin/                                 ← Distribution package (Claude Code plugin install)
├── scripts/
│   ├── install.sh                                 ← Guided installer (3 platforms)
│   ├── transform.sh                               ← .claude/ → .opencode/ + .agents/ sync
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
| `scripts/transform.sh` | Platform transform (.claude/ → .opencode/ + .agents/) | Adding new commands or reference files |
| `claude-plugin/` | Distribution package — synced from .claude/ during release | Don't edit directly — edit .claude/ |

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
./scripts/transform.sh   # sync to OpenCode + Codex
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

No automated tests — autoresearch is Markdown instructions. Testing means using it:

1. Symlink your working tree (see Quick Start)
2. Open Claude Code in a real project
3. Invoke the command (`/autoresearch`, `/autoresearch:plan`, etc.)
4. Verify behavior matches your changes
5. Try edge cases — wrong metric? 0 files in scope? Guard always fails?

## Release Process

Maintainers use `scripts/release.sh`. See `scripts/release.md` for details.

```bash
./scripts/release.sh 2.2.0 --title "New Feature"
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
5. Run `bash scripts/transform.sh` to update the plugin distribution
6. Run `bash tests/test-hooks.sh` to verify

### Hook Rules

- **Fail-open:** Always wrap in try/catch, always exit 0 on error
- **No console.log:** Corrupts stdout JSON. Use `process.stderr.write()` for debug
- **No external deps:** Pure Node.js builtins only (exception: vendored `lib/ignore.cjs`)
- **Exit codes:** 0 = allow/inject, 2 = block. No other exit codes
- **State:** Use `/tmp/ar-session-{hash}.json` via `loadSessionState()` / `saveSessionState()`

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
