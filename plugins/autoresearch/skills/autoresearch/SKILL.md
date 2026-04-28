---
name: autoresearch
description: Use when the user wants autoresearch, mentions `autoresearch`, `autoresearch:plan`, `autoresearch:debug`, `autoresearch:fix`, `autoresearch:security`, `autoresearch:ship`, `autoresearch:scenario`, `autoresearch:predict`, `autoresearch:learn`, or `autoresearch:reason`, or asks for the same command surface in Codex with flags, inline config, chained workflows, or autonomous iteration.
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

Flags and inline fields follow the canonical contract in `resources/autoresearch-command-spec.json`.

## Runtime translation

Translate Claude-specific assumptions to Codex as follows:

| Claude contract | Codex contract |
| --- | --- |
| Slash command | Plain-text `autoresearch[:subcommand]` invocation |
| `AskUserQuestion` | `request_user_input` when available, otherwise a concise direct question batch |
| `.claude/skills/...` | This plugin's `skills/autoresearch/...` tree |
| Claude command registration | Skill-triggered routing or the wrapper CLI |

Never preserve Claude-only runtime names in user-facing execution if a Codex-native equivalent exists.

## Router

1. Detect the command from the first line or first token.
2. Read `resources/autoresearch-command-spec.json` for the exact flags, required context, outputs, and stop conditions.
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

## Wrapper CLI

The bundled wrapper CLI preserves the existing command syntax:

```bash
python3 plugins/autoresearch/scripts/autoresearch_cli.py security --diff --fail-on critical
bin/autoresearch plan Improve test coverage to 90%
```

The wrapper converts command-line input into the canonical skill prompt and runs `codex exec` by default.

## Quality rules

- Keep the subcommand surface stable.
- Treat the spec JSON as the single source of truth for flag validation.
- Preserve output directories such as `security/`, `ship/`, `scenario/`, `predict/`, `learn/`, and `reason/`.
- When a chain is requested, hand off using the prior command's generated artifacts and explicit context.
- If Codex cannot exactly match a Claude behavior, emulate the behavior as closely as possible and make the limitation explicit.
