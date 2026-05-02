# Autoresearch For Codex

Autoresearch now includes a Codex-native distribution in [`plugins/autoresearch`](../plugins/autoresearch). The goal is command-surface parity with the Claude version: same subcommands, same flags, same inline config fields, same chained workflows, and the same output directory contracts.

## What Ships

- `plugins/autoresearch/.codex-plugin/plugin.json`
- `plugins/autoresearch/skills/autoresearch/SKILL.md`
- `plugins/autoresearch/resources/autoresearch-command-spec.json`
- `plugins/autoresearch/scripts/autoresearch_cli.py`
- `plugins/autoresearch/scripts/install_local_plugin.py`
- `bin/autoresearch`

## Invocation Forms

Codex supports two entry paths:

### 1. Native skill prompt

Write the command in plain text:

```text
autoresearch:security --diff --fail-on critical

Scope: src/api/**/*.ts
Focus: authentication and authorization
Iterations: 10
```

The Codex skill treats that first line as the canonical command invocation and preserves the rest as inline config and context.

### 2. Wrapper CLI

```bash
bin/autoresearch security --diff --fail-on critical <<'EOF'
Scope: src/api/**/*.ts
Focus: authentication and authorization
Iterations: 10
EOF
```

By default the wrapper runs `codex exec`. Use `--no-exec` to print the generated prompt without launching Codex.

## Install

```bash
./scripts/install.sh --codex --global
```

That installs the Codex skill to `${CODEX_HOME:-~/.codex}/skills/autoresearch`, including the wrapper CLI and command spec. Use `python3 plugins/autoresearch/scripts/install_local_plugin.py` only when you also need the local plugin marketplace copy.

## Wrapper CLI Notes

Supported wrapper options:

- `--interactive` to launch `codex` instead of `codex exec`
- `--print-prompt` to print the generated prompt before running Codex
- `--no-exec` to stop after printing the prompt
- `--cd`, `--model`, `--profile`, `--sandbox` to pass runtime options through
- `--input-file` to append additional config or context
- `--list-commands` to print the supported autoresearch commands

Everything after the wrapper options is treated as the Autoresearch command surface. The wrapper validates flags against the canonical spec before dispatching.

## Compatibility Rules

Codex translates Claude-only runtime concepts:

| Claude | Codex |
| --- | --- |
| Slash commands | Plain-text command invocation |
| `AskUserQuestion` | `request_user_input` or a concise direct question batch |
| `.claude/skills/...` | `plugins/autoresearch/skills/...` |
| Command registration files | Skill routing and wrapper CLI |

## Shared Contract

The source of truth for Codex parity is [`plugins/autoresearch/resources/autoresearch-command-spec.json`](../plugins/autoresearch/resources/autoresearch-command-spec.json). It defines:

- supported commands
- supported flags
- required context
- workflow reference files
- output artifacts
- stop conditions

## Verification

Useful checks while developing or installing:

```bash
python3 -m unittest tests/test_autoresearch_codex.py
python3 plugins/autoresearch/scripts/install_local_plugin.py --help
python3 plugins/autoresearch/scripts/autoresearch_cli.py --list-commands
bin/autoresearch --no-exec plan Improve test coverage to 90%
```
