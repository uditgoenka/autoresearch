# Changelog

Generated from git history. Grouped by type using conventional commit parsing.

## v1.8.0

### Features
- `feat:` /autoresearch:learn improvements and stability fixes
- `feat:` add /autoresearch:learn — autonomous codebase documentation engine

### Documentation
- `docs:` update COMPARISON.md, plugin descriptions, scenario guide for learn subcommand

### Release
- `release:` v1.8.0 — /autoresearch:learn autonomous documentation engine

## v1.7.6

### Documentation
- `docs:` add Karpathy vs Claude Autoresearch comparison document
- `docs:` add 10 scenario-based guide examples in guide/scenario/

### Style
- `style:` separate badges into two rows for cleaner layout

### Release
- `release:` v1.7.6 — scenario guides, comparison doc, version bump

## v1.7.0 — v1.7.5

### Features
- `feat:` add /autoresearch:predict multi-persona swarm prediction (v1.7.0)

### Fixes
- `fix:` resolve ENAMETOOLONG recursive plugin caching (closes #43)
- `fix:` address 8 stability bugs from debug audit
- `fix:` add explicit argument parsing and iteration tracking to all commands
- `fix:` streamline command files for faster trigger and live streaming

### Documentation
- `docs:` add ML metrics, git memory automation, atomicity enforcement, DevOps CLI
- `docs:` add actionable implementation guidance for Context7 benchmark
- `docs:` add PayPal support badge to README
- `docs:` update star history chart legend position to bottom-right
- `docs:` add update instructions to Quick Start section
- `docs:` restructure guides into individual command files

### Chores
- `chore:` prepare release v1.7.3, v1.7.2, v1.7.1
- `chore:` sync root distribution files with .claude/ and add release sync step
- `chore:` bump version to 1.7.0 for multi-persona swarm prediction release

## v1.6.0 — v1.6.2

### Features
- `feat:` add /autoresearch:scenario subcommand (v1.6.0)
- `feat:` release workflow with PR-first flow and doc review gate

### Fixes
- `fix:` harden git-as-memory mechanism in autonomous loop (v1.6.1)
- `fix:` bump plugin.json version from 1.3.0 to 1.6.1
- `fix:` add source path to marketplace.json plugin entry
- `fix:` bump marketplace.json to 1.6.2 and add to release workflow
- `fix:` remove self-referencing source URL from marketplace.json

### Documentation
- `docs:` expand EXAMPLES.md with new domains, languages, and chains
- `docs:` update CONTRIBUTING.md to reflect current project state
- `docs:` add comprehensive GUIDE.md and bump to v1.6.2

### Chores
- `chore:` add context7.json for Context7 integration
- `chore:` add GUIDE.md and CONTRIBUTING.md to release workflow
- `chore:` add release script to auto-bump plugin.json version
- `chore:` update star history chart to timeline view

## v1.3.0 — v1.5.0

### Features
- `feat:` enforce mandatory AskUserQuestion gate for all commands (v1.5.0)
- `feat:` batched AskUserQuestion setup for all commands (v1.3.2)
- `feat:` batch AskUserQuestion calls for all commands — ask 3-4 questions at once
- `feat:` interactive AskUserQuestion setup for all commands (v1.3.1)
- `feat:` add interactive AskUserQuestion setup to security and ship workflows

### Fixes
- `fix:` replace /loop N with native Iterations: N config (v1.4.0)
- `fix:` register base /autoresearch command (v1.3.3)

See also: [Development Roadmap](development-roadmap.md) | [Project Overview](project-overview-pdr.md)
