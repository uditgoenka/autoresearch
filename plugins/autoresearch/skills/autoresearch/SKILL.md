---
name: autoresearch
description: Use when the user wants autoresearch, mentions `autoresearch`, `autoresearch:plan`, `autoresearch:debug`, `autoresearch:fix`, `autoresearch:security`, `autoresearch:ship`, `autoresearch:scenario`, `autoresearch:predict`, `autoresearch:learn`, `autoresearch:reason`, `autoresearch:probe`, `$autoresearch`, `$autoresearch:<subcommand>`, `$autoresearch <subcommand>`, `$autoresearch reason --iterations N`, `/autoresearch`, or `/autoresearch:<subcommand>`, even when the invocation is embedded in prose, or asks for the same command surface in Codex with flags, inline config, chained workflows, or autonomous iteration.
---

# Autoresearch For Codex

Codex-native port of the Autoresearch command surface.

Accepted invocation forms:

- `autoresearch`
- `autoresearch:plan`
- `autoresearch:debug`
- `autoresearch:fix`
- `autoresearch:security`
- `autoresearch:ship`
- `autoresearch:scenario`
- `autoresearch:predict`
- `autoresearch:learn`
- `autoresearch:reason`
- `autoresearch:probe`

Compatibility aliases normalize to the same canonical commands:

- `$autoresearch`
- `$autoresearch:debug --fix`
- `$autoresearch debug --fix`
- `/autoresearch:debug --fix`
- `/autoresearch debug --fix`
- `autoresearch debug --fix`

Flags and inline fields follow the canonical command spec. Use `resources/autoresearch-command-spec.json` in an installed Codex skill bundle, or `../../resources/autoresearch-command-spec.json` from the repo source tree.

## Runtime translation

Translate Claude-specific assumptions to Codex as follows:

| Claude contract | Codex contract |
| --- | --- |
| Slash command | Plain-text `autoresearch[:subcommand]` or `$autoresearch` skill invocation |
| `AskUserQuestion` | `request_user_input` when available, otherwise a concise direct question batch |
| `.claude/skills/...` | This plugin's `skills/autoresearch/...` tree |
| Claude command registration | Skill-triggered routing or the wrapper CLI |

Never preserve Claude-only runtime names in user-facing execution if a Codex-native equivalent exists.

## Router

1. Detect the command from the first line or first token.
   - Strip a leading `$` or `/` from explicit skill or Claude-style invocations.
   - If a prompt embeds `$autoresearch` in prose, extract that invocation and keep surrounding text as context.
   - Treat `autoresearch debug`, `$autoresearch debug`, and `/autoresearch debug` as `autoresearch:debug`.
   - Keep root `autoresearch` when the next token is inline config or prose instead of a known subcommand.
2. Read the command spec for the exact flags, required context, outputs, and stop conditions:
   - Installed skill bundle: `resources/autoresearch-command-spec.json`
   - Repo source tree: `../../resources/autoresearch-command-spec.json`
3. Read the matching reference file from `references/`.
4. Preserve the existing command semantics:
   - same required setup gates
   - same bounded iteration behavior for `Iterations:` and `--iterations`
   - same output directory names
   - same `--chain` behavior when a command supports it
5. If required context is missing, gather it before execution.
6. Prefer Codex-native tools and file paths, not Claude-specific names.

## Setup gate

If a command is missing critical context, stop and gather it before any execution phase:

- Use `request_user_input` when the runtime exposes it.
- If structured input is unavailable, ask a concise batch of direct questions in one message.
- Do not enter the loop, audit, or chain step with incomplete setup.

## Command map

| Command | Reference |
| --- | --- |
| `autoresearch` | `references/core-loop.md` |
| `autoresearch:plan` | `references/plan.md` |
| `autoresearch:debug` | `references/debug.md` |
| `autoresearch:fix` | `references/fix.md` |
| `autoresearch:security` | `references/security.md` |
| `autoresearch:ship` | `references/ship.md` |
| `autoresearch:scenario` | `references/scenario.md` |
| `autoresearch:predict` | `references/predict.md` |
| `autoresearch:learn` | `references/learn.md` |
| `autoresearch:reason` | `references/reason.md` |
| `autoresearch:probe` | `references/probe.md` |

## Wrapper CLI

The bundled wrapper CLI preserves the existing command syntax:

```bash
python3 plugins/autoresearch/scripts/autoresearch_cli.py security --diff --fail-on critical
bin/autoresearch plan Improve test coverage to 90%
bin/autoresearch '$autoresearch:debug' --fix --scope 'src/**/*.ts'
```

The wrapper accepts plain, `$`, and `/` command aliases, converts command-line input into the canonical skill prompt, and runs `codex exec` by default.

## Quality rules

- Keep the subcommand surface stable.
- Treat the spec JSON as the single source of truth for flag validation.
- Preserve output directories such as `security/`, `ship/`, `scenario/`, `predict/`, `learn/`, and `reason/`.
- When a chain is requested, hand off using the prior command's generated artifacts and explicit context.
- If Codex cannot exactly match a Claude behavior, emulate the behavior as closely as possible and make the limitation explicit.
