# Contributing to Autoresearch

Thanks for wanting to make autoresearch better. Whether you're fixing a typo, adding examples, creating a new sub-command, or improving the loop protocol — this guide will get you up and running fast.

## Quick Start

Autoresearch is Markdown files that Claude Code and OpenCode discover from `skills/` and `commands/` directories. No build step, no compilation — edit a `.md` file, invoke the skill, see your changes.

```bash
# 1. Clone the repo
git clone https://github.com/uditgoenka/autoresearch.git
cd autoresearch

# 2. Copy to your local Claude Code (for testing)
cp -r claude-plugin/skills/autoresearch ~/.claude/skills/autoresearch
cp -r claude-plugin/commands/autoresearch ~/.claude/commands/autoresearch
cp claude-plugin/commands/autoresearch.md ~/.claude/commands/autoresearch.md

# 3. Copy to your local OpenCode config (for testing)
mkdir -p ~/.config/opencode/skills ~/.config/opencode/commands ~/.config/opencode/agents
cp -r .opencode/skills/autoresearch ~/.config/opencode/skills/autoresearch
cp .opencode/commands/*.md ~/.config/opencode/commands/
cp .opencode/agents/docs-manager.md ~/.config/opencode/agents/docs-manager.md

# 4. Or symlink for live editing (recommended for development)
ln -s $(pwd)/claude-plugin/skills/autoresearch ~/.claude/skills/autoresearch
ln -s $(pwd)/claude-plugin/commands/autoresearch ~/.claude/commands/autoresearch
ln -s $(pwd)/claude-plugin/commands/autoresearch.md ~/.claude/commands/autoresearch.md
ln -s $(pwd)/.opencode/skills/autoresearch ~/.config/opencode/skills/autoresearch
for f in $(pwd)/.opencode/commands/*.md; do ln -s "$f" ~/.config/opencode/commands/$(basename "$f"); done
ln -s $(pwd)/.opencode/agents/docs-manager.md ~/.config/opencode/agents/docs-manager.md
```

When done developing, replace symlinks with stable copies:
```bash
rm ~/.claude/skills/autoresearch ~/.claude/commands/autoresearch ~/.claude/commands/autoresearch.md
rm ~/.config/opencode/skills/autoresearch ~/.config/opencode/commands/autoresearch*.md ~/.config/opencode/agents/docs-manager.md
cp -r claude-plugin/skills/autoresearch ~/.claude/skills/autoresearch
cp -r claude-plugin/commands/autoresearch ~/.claude/commands/autoresearch
cp claude-plugin/commands/autoresearch.md ~/.claude/commands/autoresearch.md
cp -r .opencode/skills/autoresearch ~/.config/opencode/skills/autoresearch
cp .opencode/commands/*.md ~/.config/opencode/commands/
cp .opencode/agents/docs-manager.md ~/.config/opencode/agents/docs-manager.md
```

## Repository Structure

```
autoresearch/
├── README.md                                      ← Project overview + quick start
├── .gitignore                                     ← Excludes local Claude/OpenCode state
├── .opencode/                                     ← OpenCode runtime files checked into repo
│   ├── agents/
│   │   └── docs-manager.md                        ← Hidden doc-generation subagent for OpenCode
│   ├── commands/
│   │   ├── autoresearch.md                        ← Main /autoresearch command for OpenCode
│   │   ├── autoresearch_plan.md                   ← /autoresearch_plan registration
│   │   ├── autoresearch_security.md               ← /autoresearch_security registration
│   │   ├── autoresearch_ship.md                   ← /autoresearch_ship registration
│   │   ├── autoresearch_debug.md                  ← /autoresearch_debug registration
│   │   ├── autoresearch_fix.md                    ← /autoresearch_fix registration
│   │   ├── autoresearch_scenario.md               ← /autoresearch_scenario registration
│   │   ├── autoresearch_predict.md                ← /autoresearch_predict registration
│   │   └── autoresearch_learn.md                  ← /autoresearch_learn registration
│   └── skills/
│       └── autoresearch/
│           ├── SKILL.md                           ← Main skill (loaded by OpenCode)
│           └── references/                        ← OpenCode-native workflow references
├── .claude-plugin/
│   └── marketplace.json                           ← Plugin marketplace manifest (source: ./claude-plugin)
├── claude-plugin/                                 ← DISTRIBUTION — what users install
│   ├── .claude-plugin/
│   │   └── plugin.json                            ← Plugin metadata + version
│   ├── commands/
│   │   ├── autoresearch.md                        ← Main /autoresearch command
│   │   └── autoresearch/
│   │       ├── plan.md                            ← /autoresearch:plan registration
│   │       ├── security.md                        ← /autoresearch:security registration
│   │       ├── ship.md                            ← /autoresearch:ship registration
│   │       ├── debug.md                           ← /autoresearch:debug registration
│   │       ├── fix.md                             ← /autoresearch:fix registration
│   │       ├── scenario.md                        ← /autoresearch:scenario registration
│   │       ├── predict.md                         ← /autoresearch:predict registration
│   │       └── learn.md                           ← /autoresearch:learn registration
│   └── skills/
│       └── autoresearch/
│           ├── SKILL.md                           ← Main skill (loaded by Claude Code)
│           └── references/
│               ├── autonomous-loop-protocol.md    ← 8-phase loop protocol
│               ├── core-principles.md             ← 7 universal principles
│               ├── plan-workflow.md               ← Plan wizard protocol
│               ├── security-workflow.md           ← Security audit protocol
│               ├── ship-workflow.md               ← Ship workflow protocol
│               ├── debug-workflow.md              ← Debug loop protocol
│               ├── fix-workflow.md                ← Fix loop protocol
│               ├── scenario-workflow.md           ← Scenario exploration protocol
│               ├── predict-workflow.md            ← Multi-persona swarm prediction workflow
│               ├── learn-workflow.md              ← Learn/documentation engine protocol
│               └── results-logging.md             ← TSV tracking format
├── .claude/                                       ← LOCAL development (gitignored except autoresearch)
│   ├── commands/autoresearch/                     ← Dev copies of commands
│   └── skills/autoresearch/                       ← Dev copies of skills
├── guide/                                         ← Comprehensive guides — one per command
│   ├── README.md                                  ← Guide index
│   ├── getting-started.md                         ← Installation, core concepts, FAQ
│   ├── autoresearch.md                            ← The autonomous loop
│   ├── autoresearch-plan.md                       ← Setup wizard
│   ├── autoresearch-debug.md                      ← Bug hunter
│   ├── autoresearch-fix.md                        ← Error crusher
│   ├── autoresearch-security.md                   ← Security auditor
│   ├── autoresearch-ship.md                       ← Shipping workflow
│   ├── autoresearch-scenario.md                   ← Scenario explorer
│   ├── autoresearch-predict.md                    ← Multi-persona swarm prediction
│   ├── autoresearch-learn.md                      ← Documentation engine
│   ├── chains-and-combinations.md                 ← Multi-command pipelines
│   ├── examples-by-domain.md                      ← Real-world examples by domain
│   ├── advanced-patterns.md                       ← Guards, MCP, CI/CD, FAQ
│   └── scenario/                                  ← Scenario-specific guides
│       └── README.md                              ← Scenario guide index
├── COMPARISON.md                                  ← Feature comparison with alternatives
├── CONTRIBUTING.md                                ← You are here
├── LICENSE                                        ← MIT License
└── scripts/
    ├── install.sh                                 ← Unified installer for Claude Code and OpenCode
    ├── release.sh                                 ← Release script (version bump + PR + tag)
    └── release.md                                 ← Release process documentation
```

### What Each File Does

| File | Purpose | Edit when... |
|------|---------|-------------|
| `SKILL.md` | Main entry point. Sub-command routing, setup phase, loop pseudocode, domain table. | Adding sub-commands, changing activation triggers, updating loop behavior |
| `.opencode/skills/autoresearch/SKILL.md` | OpenCode-native skill entry point. | Updating OpenCode behavior, tool names, or slash-command docs |
| `references/autonomous-loop-protocol.md` | 8-phase loop protocol with rules for each phase. | Changing how the loop works (review, ideate, modify, commit, verify, guard, decide, log) |
| `references/core-principles.md` | 7 universal principles from Karpathy's autoresearch. | Refining principles or adding new ones |
| `references/plan-workflow.md` | `/autoresearch:plan` wizard protocol. | Changing planning flow, question types, metric suggestions |
| `references/security-workflow.md` | `/autoresearch:security` audit protocol. | Adding OWASP checks, red-team personas, report structure |
| `references/ship-workflow.md` | `/autoresearch:ship` shipping workflow. | Adding ship types, checklists, rollback actions |
| `references/debug-workflow.md` | `/autoresearch:debug` bug-hunting protocol. | Adding investigation techniques, bug patterns, domain checklists |
| `references/fix-workflow.md` | `/autoresearch:fix` error repair protocol. | Adding fix strategies, anti-patterns, language-specific patterns |
| `references/scenario-workflow.md` | `/autoresearch:scenario` scenario exploration. | Adding domains, dimensions, output formats |
| `references/predict-workflow.md` | `/autoresearch:predict` multi-persona swarm prediction workflow (751 lines). | Adding prediction personas, confidence models, output formats |
| `references/learn-workflow.md` | `/autoresearch:learn` documentation engine protocol. | Adding doc types, validation checks, generation templates |
| `references/results-logging.md` | TSV log format and reporting rules. | Changing log columns, summary format, reporting intervals |
| `claude-plugin/commands/autoresearch/*.md` | Claude Code sub-command registration files. | Adding new Claude Code sub-commands |
| `.opencode/commands/autoresearch_*.md` | OpenCode command registration files. | Adding new OpenCode underscore commands |
| `.opencode/agents/docs-manager.md` | OpenCode-only documentation generation subagent. | Updating `/autoresearch_learn` OpenCode behavior |
| `scripts/install.sh` | Guided installer for Claude Code and OpenCode local/global setups. | Changing installation behavior or target paths |
| `claude-plugin/.claude-plugin/plugin.json` | Plugin metadata + version. | Version bumps (use `scripts/release.sh`) |
| `README.md` | Public overview, commands table, quick start. | Adding features, updating commands, documenting changes |
| `guide/*.md` | Individual command guides, examples, advanced patterns. | Adding scenarios, command combinations, domain examples |
| `guide/scenario/` | Scenario-specific guides and domain examples. | Adding scenario domains, edge case patterns |
| `COMPARISON.md` | Feature comparison with alternatives. | Updating subcommand count, adding new capabilities to comparison table |

## What to Contribute

### High-Value Contributions

| Type | Examples | Difficulty |
|------|----------|-----------|
| **New domain examples** | Add to `guide/examples-by-domain.md` | Easy |
| **Verification script templates** | Reusable scripts for common metrics | Easy |
| **Bug fixes** | Loop edge cases, incorrect behavior | Medium |
| **New sub-commands** | `/autoresearch:refactor`, `/autoresearch:test` | Medium |
| **New ship types** | Additional checklist types for `/autoresearch:ship` | Medium |
| **OWASP/STRIDE additions** | New security checks for `/autoresearch:security` | Medium |
| **New scenario domains** | Additional domain templates for `/autoresearch:scenario` | Medium |
| **Protocol improvements** | Better stuck-detection, smarter ideation | Hard |
| **MCP integration patterns** | Database, API, analytics verification examples | Hard |

### Low-Value (Please Don't)

- Reformatting or restructuring existing files without functional changes
- Adding comments to explain obvious things
- Changing naming conventions or style
- Whitespace-only changes

## Day-to-Day Workflow

```bash
# 1. Fork and clone
gh repo fork uditgoenka/autoresearch --clone
cd autoresearch

# 2. Create a feature branch
git checkout -b feat/your-feature-name

# 3. Symlink for live testing
ln -s $(pwd)/claude-plugin/skills/autoresearch ~/.claude/skills/autoresearch
ln -s $(pwd)/claude-plugin/commands/autoresearch ~/.claude/commands/autoresearch
ln -s $(pwd)/claude-plugin/commands/autoresearch.md ~/.claude/commands/autoresearch.md
ln -s $(pwd)/.opencode/skills/autoresearch ~/.config/opencode/skills/autoresearch
for f in $(pwd)/.opencode/commands/*.md; do ln -s "$f" ~/.config/opencode/commands/$(basename "$f"); done
ln -s $(pwd)/.opencode/agents/docs-manager.md ~/.config/opencode/agents/docs-manager.md

# 4. Make your changes
# Edit skill files, reference files, commands, docs, etc.

# 5. Test in Claude Code (changes are live via symlink)
# Open Claude Code in any project and invoke the relevant command

# 6. Commit with conventional format
git add -A
git commit -m "feat: add guard rework timeout after 60 seconds"

# 7. Push and create PR
git push -u origin feat/your-feature-name
gh pr create --title "feat: your feature" --body "## Summary\n- What changed\n- Why"
```

## Commit Messages

We use [conventional commits](https://www.conventionalcommits.org/):

| Prefix | When |
|--------|------|
| `feat:` | New feature or sub-command |
| `fix:` | Bug fix in existing behavior |
| `docs:` | Documentation-only changes |
| `refactor:` | Restructuring without behavior change |
| `chore:` | Maintenance (CI, config, tooling, version bumps) |

## Pull Request Guidelines

1. **One PR = one feature.** Don't bundle unrelated changes.
2. **Branch from `master`.** Target `master` as base.
3. **Descriptive title.** Use conventional commit format.
4. **Write a good body.** Explain what changed, why, and how to test it.
5. **Update docs.** If you add a feature, update the relevant docs:
   - `SKILL.md` — register sub-commands, update activation triggers
   - `README.md` — commands table, quick decision guide, repo structure, FAQ
   - `guide/` — add individual command guide or update existing ones
   - `guide/scenario/` — update scenario guides if adding new domains or patterns
   - `guide/examples-by-domain.md` — add copy-paste examples for new features
   - `COMPARISON.md` — update subcommand count and feature comparison table
6. **Don't bump the version.** Maintainers handle version bumps via `scripts/release.sh`.
7. **Keep files focused.** Don't modify files unrelated to your change.

### PR Template

```markdown
## Summary
- What changed and why

## Files Changed
| File | Change |
|------|--------|
| `references/fix-workflow.md` | Added Rust-specific fix strategies |
| `EXAMPLES.md` | Added Rust examples section |

## How to Test
1. Symlink the Claude or OpenCode runtime files into your local config
2. Run `/autoresearch:fix` in Claude Code or `/autoresearch_fix` in OpenCode
3. Verify Rust-specific strategies are applied
```

## Adding a New Sub-Command

Follow this pattern when adding a command like `/autoresearch:yourcommand` in Claude Code and `/autoresearch_yourcommand` in OpenCode:

### 1. Create the reference file

```
claude-plugin/skills/autoresearch/references/your-workflow.md
```

Contains: full protocol, phases, rules, examples, flags, error recovery, composite metric, output directory structure.

### 2. Create the command registration file

```
claude-plugin/commands/autoresearch/yourcommand.md
```

This thin wrapper tells Claude Code to load SKILL.md + your reference file and execute the workflow.

Create the matching OpenCode command too:

```
.opencode/commands/autoresearch_yourcommand.md
```

This registers the OpenCode command `/autoresearch_yourcommand`.

### 3. Register in both SKILL.md files

Add to the subcommands table in `.claude/skills/autoresearch/SKILL.md` and `.opencode/skills/autoresearch/SKILL.md`:
```markdown
| `/autoresearch:yourcommand` | Description of what it does |
```

And add the OpenCode underscore form to the OpenCode skill:
```markdown
| `/autoresearch_yourcommand` | Description of what it does |
```

Add a full sub-command section with:
- `Load: references/your-workflow.md` directive
- Numbered phase summary
- Usage examples with flags
- Key behaviors and composite metric

Add to the "When to Activate" section:
```markdown
- User invokes `/autoresearch:yourcommand` → run your workflow
- User says "relevant trigger phrases" → run your workflow
```

Add to the interactive setup gate table.

### 4. Update all docs

| Doc | What to Update |
|-----|---------------|
| `README.md` | Commands table, Quick Decision Guide, dedicated section, repo structure, FAQ |
| `guide/` | Individual command guide, chains-and-combinations, examples-by-domain, advanced-patterns |
| `guide/scenario/` | Scenario guide chain suggestions (if relevant to scenario workflows) |
| `COMPARISON.md` | Update subcommand count and feature comparison table |
| `CONTRIBUTING.md` | Repo structure tree, "What Each File Does" table |

## Testing Your Changes

No automated test suite — autoresearch is Markdown instructions, not code. Testing means using it:

1. **Symlink your working tree** (see Quick Start)
2. **Open Claude Code in a real project**
3. **Open OpenCode in a real project** (`opencode`)
4. **Invoke the skill** (`/autoresearch`, `/autoresearch:plan`, `/autoresearch_plan`, etc.)
5. **Verify behavior matches your changes**
6. **Try edge cases** — wrong metric? Scope matches 0 files? Guard always fails?

### What to Check

- Do Claude Code and OpenCode both follow your updated instructions?
- Does the output format match your specification?
- Are error cases handled gracefully?
- Does backward compatibility hold? (Existing commands still work)
- Does the interactive setup ask the right questions?

## Release Process

Maintainers use `scripts/release.sh` to handle releases. See `scripts/release.md` for full documentation.

```bash
# Patch release (bugfixes, docs updates)
./scripts/release.sh 1.7.1 --title "Fix scenario timeout"

# Minor release (new features, new commands)
./scripts/release.sh 1.7.0 --title "New Sub-Command Name"
```

The script: creates release branch → bumps plugin.json + README badge → pauses for doc review → commits → creates PR → waits for merge confirmation → tags → creates GitHub release.

**Contributors don't need to bump versions** — maintainers handle this during release.

## Things to Know

- **No build step.** Everything is Markdown. Edit → test → commit.
- **SKILL.md is the entry point.** Claude Code and OpenCode both load it. References are loaded on demand.
- **References are lazy-loaded.** Only loaded when the relevant sub-command is invoked. Keeps context usage low.
- **claude-plugin/commands/ directory is required.** Without it, sub-commands (`/autoresearch:plan`, etc.) won't register as slash commands.
- **.opencode/commands/ directory is required for OpenCode.** Without it, underscore commands (`/autoresearch_plan`, etc.) won't register.
- **Plugin system.** Users can install via `/plugin install` — the `.claude-plugin/marketplace.json` at root points to `./claude-plugin` as the distribution source.
- **The repo is MIT licensed.** Your contributions will be under the same license.

## Getting Help

- **Questions?** Open an [issue](https://github.com/uditgoenka/autoresearch/issues)
- **Ideas?** Open an issue with `[Idea]` prefix
- **Bug reports?** Open an issue with reproduction steps
- **Discussion?** Tag [@uditgoenka](https://github.com/uditgoenka) in your PR

Thanks for contributing!
