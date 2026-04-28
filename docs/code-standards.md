# Code Standards

## Language and Format

This project is entirely **markdown-based** with shell script helpers. There is no compiled code. Standards focus on markdown authoring, skill definition patterns, and shell scripting conventions.

## File Naming

- **kebab-case** for all file names: `security-workflow.md`, `score-debug-fix.sh`
- Names should be descriptive enough that an LLM can understand file purpose without reading content
- Command registration files match their command name: `debug.md` for `/autoresearch:debug`

## Markdown Conventions

### SKILL.md Pattern

The main skill file (`SKILL.md`) follows Claude Code's skill definition format:
- YAML frontmatter with `name`, `description`, `version`
- Mandatory setup gate section (interactive setup with AskUserQuestion)
- Subcommand table with purpose descriptions
- Activation triggers section
- Each subcommand documented with usage examples, flags, and composite metric

### Reference Files

Workflow reference files (`references/*.md`) follow a consistent structure:
- Trigger section -- when to activate
- Loop support -- example invocations
- Interactive setup -- AskUserQuestion batched questions
- Architecture -- phase diagram
- Phase-by-phase protocol -- detailed numbered steps
- Flags table -- all supported flags with defaults
- Composite metric formula
- Anti-patterns table -- what NOT to do
- Output directory structure

### Command Registration Files

Command files (`commands/autoresearch/*.md`) are minimal:
- YAML frontmatter: `name`, `description`, `argument-hint`
- Execution instructions: read workflow reference, ask questions if needed, execute

## Shell Script Standards

- Use `#!/bin/bash` or `#!/usr/bin/env bash`
- Quote variables: `"$VAR"` not `$VAR`
- Use `set -euo pipefail` for strict error handling where appropriate
- Scripts live in `scripts/` directory

## Documentation Standards

- Each doc file max **800 lines** (README max 300 lines)
- Include "See also" cross-reference links between related docs
- Use tables for structured comparisons
- Use Mermaid diagrams for architecture and flow visualization
- Keep content factual and specific to the codebase -- no generic boilerplate

## Commit Message Format

- Conventional commits: `feat:`, `fix:`, `docs:`, `refactor:`, `test:`, `chore:`, `style:`, `release:`
- No AI references in commit messages
- Keep commits focused on actual changes

## Version Management

- Version tracked in `claude-plugin/.claude-plugin/plugin.json`
- Version also appears in SKILL.md frontmatter and README badges
- Release script (`scripts/release.sh`) automates version bumping

## Results Logging

- All iteration results logged in TSV format
- Fields: `iteration`, `commit`, `metric`, `delta`, `status`, `description`
- Status values: `baseline`, `keep`, `discard`, `crash`
- Progress summaries printed every 10 iterations (or every 5 for learn workflow)
- Learn workflow composite metric: `learn_score = validation%*0.5 + coverage%*0.3 + size_compliance%*0.2`

## Learn Workflow Standards

- 4 modes: `init`, `update`, `check`, `summarize` -- mode auto-detected from docs/ state
- Update mode uses diff-based targeting: `git diff --name-only` maps changed files to affected docs
- Validation-fix loop capped at 3 retries before escalation
- Doc size compliance: max 800 lines per doc, README max 300 lines
- Dynamic doc discovery via `ls docs/*.md` -- no hardcoded file lists
- Scout phase is scale-aware: adjusts parallelism for 5k+ file codebases

See also: [Project Overview](project-overview-pdr.md) | [System Architecture](system-architecture.md) | [Codebase Summary](codebase-summary.md)
