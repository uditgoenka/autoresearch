#!/usr/bin/env bash
# Transform Claude Code canonical source → OpenCode / Codex platform formats.
# Run after any change to .claude/ source files.
#
# Usage:
#   ./scripts/transform.sh              # transform to all platforms
#   ./scripts/transform.sh --opencode   # OpenCode only
#   ./scripts/transform.sh --codex      # Codex only

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

CLAUDE_SKILLS="$REPO_ROOT/.claude/skills/autoresearch"
CLAUDE_COMMANDS="$REPO_ROOT/.claude/commands"

DO_OPENCODE=1
DO_CODEX=1

while [[ $# -gt 0 ]]; do
  case "$1" in
    --opencode) DO_OPENCODE=1; DO_CODEX=0 ;;
    --codex)    DO_OPENCODE=0; DO_CODEX=1 ;;
    -h|--help)  printf 'Usage: %s [--opencode|--codex]\n' "$0"; exit 0 ;;
    *)          printf 'Unknown flag: %s\n' "$1" >&2; exit 1 ;;
  esac
  shift
done

die() { printf 'Error: %s\n' "$1" >&2; exit 1; }

[[ -d "$CLAUDE_SKILLS" ]] || die "Source not found: $CLAUDE_SKILLS"
[[ -d "$CLAUDE_COMMANDS" ]] || die "Source not found: $CLAUDE_COMMANDS"

# --- OpenCode Transform ---
# Differences: colon → underscore in command names, AskUserQuestion → question,
# .claude/ → .opencode/, command files flattened with underscore naming

transform_opencode() {
  local dst_skills="$REPO_ROOT/.opencode/skills/autoresearch"
  local dst_commands="$REPO_ROOT/.opencode/commands"

  rm -rf "$dst_skills" "$dst_commands"/autoresearch*.md
  mkdir -p "$dst_skills/references" "$dst_commands"

  adapt_opencode() {
    sed \
      -e 's/`AskUserQuestion`/`question`/g' \
      -e 's/AskUserQuestion/question/g' \
      -e 's|/autoresearch:plan|/autoresearch_plan|g' \
      -e 's|/autoresearch:debug|/autoresearch_debug|g' \
      -e 's|/autoresearch:fix|/autoresearch_fix|g' \
      -e 's|/autoresearch:security|/autoresearch_security|g' \
      -e 's|/autoresearch:ship|/autoresearch_ship|g' \
      -e 's|/autoresearch:scenario|/autoresearch_scenario|g' \
      -e 's|/autoresearch:predict|/autoresearch_predict|g' \
      -e 's|/autoresearch:learn|/autoresearch_learn|g' \
      -e 's|/autoresearch:reason|/autoresearch_reason|g' \
      -e 's|/autoresearch:probe|/autoresearch_probe|g' \
      -e 's|/autoresearch:evals|/autoresearch_evals|g' \
      -e 's|/autoresearch:improve|/autoresearch_improve|g' \
      -e 's|/autoresearch:regression|/autoresearch_regression|g' \
      -e 's|name: autoresearch:plan|name: autoresearch_plan|g' \
      -e 's|name: autoresearch:debug|name: autoresearch_debug|g' \
      -e 's|name: autoresearch:fix|name: autoresearch_fix|g' \
      -e 's|name: autoresearch:security|name: autoresearch_security|g' \
      -e 's|name: autoresearch:ship|name: autoresearch_ship|g' \
      -e 's|name: autoresearch:scenario|name: autoresearch_scenario|g' \
      -e 's|name: autoresearch:predict|name: autoresearch_predict|g' \
      -e 's|name: autoresearch:learn|name: autoresearch_learn|g' \
      -e 's|name: autoresearch:reason|name: autoresearch_reason|g' \
      -e 's|name: autoresearch:probe|name: autoresearch_probe|g' \
      -e 's|name: autoresearch:evals|name: autoresearch_evals|g' \
      -e 's|name: autoresearch:improve|name: autoresearch_improve|g' \
      -e 's|\.claude/skills/|.opencode/skills/|g' \
      -e 's|\.claude/commands/|.opencode/commands/|g' \
      "$1"
  }

  # SKILL.md
  adapt_opencode "$CLAUDE_SKILLS/SKILL.md" > "$dst_skills/SKILL.md"

  # References (copy with adaptations)
  for ref in "$CLAUDE_SKILLS"/references/*.md; do
    [[ -f "$ref" ]] || continue
    adapt_opencode "$ref" > "$dst_skills/references/$(basename "$ref")"
  done

  # Core command (autoresearch.md)
  adapt_opencode "$CLAUDE_COMMANDS/autoresearch.md" > "$dst_commands/autoresearch.md"

  # Subcommand files (colon → underscore in filename)
  for cmd in "$CLAUDE_COMMANDS"/autoresearch/*.md; do
    [[ -f "$cmd" ]] || continue
    local base
    base="$(basename "$cmd")"
    adapt_opencode "$cmd" > "$dst_commands/autoresearch_${base}"
  done

  printf 'OpenCode: transformed %s → %s\n' ".claude/" ".opencode/"
}

# --- Codex Transform ---
# Differences: colon → space in invocations, /autoresearch:X → $autoresearch X,
# AskUserQuestion → request_user_input, merged into skills directory

transform_codex() {
  local dst_skills="$REPO_ROOT/plugins/autoresearch/skills/autoresearch"
  local dst_agents="$REPO_ROOT/.agents/skills/autoresearch"

  rm -rf "$dst_skills" "$dst_agents"
  mkdir -p "$dst_skills/references" "$dst_agents/references"

  adapt_codex() {
    sed \
      -e 's/`AskUserQuestion`/`request_user_input`/g' \
      -e 's/AskUserQuestion/request_user_input/g' \
      -e 's|/autoresearch:plan|\$autoresearch plan|g' \
      -e 's|/autoresearch:debug|\$autoresearch debug|g' \
      -e 's|/autoresearch:fix|\$autoresearch fix|g' \
      -e 's|/autoresearch:security|\$autoresearch security|g' \
      -e 's|/autoresearch:ship|\$autoresearch ship|g' \
      -e 's|/autoresearch:scenario|\$autoresearch scenario|g' \
      -e 's|/autoresearch:predict|\$autoresearch predict|g' \
      -e 's|/autoresearch:learn|\$autoresearch learn|g' \
      -e 's|/autoresearch:reason|\$autoresearch reason|g' \
      -e 's|/autoresearch:probe|\$autoresearch probe|g' \
      -e 's|/autoresearch:evals|\$autoresearch evals|g' \
      -e 's|/autoresearch:improve|\$autoresearch improve|g' \
      -e 's|/autoresearch:regression|\$autoresearch regression|g' \
      -e 's|/autoresearch|\$autoresearch|g' \
      -e 's|\.claude/skills/|skills/autoresearch/|g' \
      -e 's|\.claude/commands/|skills/autoresearch/|g' \
      "$1"
  }

  # Skills
  adapt_codex "$CLAUDE_SKILLS/SKILL.md" > "$dst_skills/SKILL.md"
  cp "$dst_skills/SKILL.md" "$dst_agents/SKILL.md"

  for ref in "$CLAUDE_SKILLS"/references/*.md; do
    [[ -f "$ref" ]] || continue
    local base
    base="$(basename "$ref")"
    adapt_codex "$ref" > "$dst_skills/references/$base"
    cp "$dst_skills/references/$base" "$dst_agents/references/$base"
  done

  # Command files (Codex merges commands into skills directory)
  adapt_codex "$CLAUDE_COMMANDS/autoresearch.md" > "$dst_skills/autoresearch.md"
  cp "$dst_skills/autoresearch.md" "$dst_agents/autoresearch.md"

  for cmd in "$CLAUDE_COMMANDS"/autoresearch/*.md; do
    [[ -f "$cmd" ]] || continue
    local cbase
    cbase="$(basename "$cmd")"
    adapt_codex "$cmd" > "$dst_skills/$cbase"
    cp "$dst_skills/$cbase" "$dst_agents/$cbase"
  done

  # Restore agents config
  mkdir -p "$dst_agents/agents"
  cat > "$dst_agents/agents/openai.yaml" <<'YAML'
interface:
  display_name: "Autoresearch"
  short_description: "Autonomous goal-directed iteration engine"
  brand_color: "#7C3AED"
  default_prompt: "Set a goal, define a metric, let Codex loop until done"

policy:
  allow_implicit_invocation: true
YAML

  printf 'Codex: transformed %s → plugins/ + .agents/\n' ".claude/"
}

# --- Claude Plugin Hooks Transform ---

transform_hooks() {
  local src_hooks="$REPO_ROOT/.claude/hooks/autoresearch"
  local dst_hooks="$REPO_ROOT/claude-plugin/hooks"

  [[ -d "$src_hooks" ]] || { printf 'Hooks: no source at %s, skipping\n' "$src_hooks"; return; }

  rm -rf "$dst_hooks"
  mkdir -p "$dst_hooks/lib"

  # Copy all hook files
  for f in "$src_hooks"/*.cjs "$src_hooks"/*.sh "$src_hooks"/*.json; do
    [[ -f "$f" ]] || continue
    cp "$f" "$dst_hooks/$(basename "$f")"
  done

  # Copy .ckignore baseline
  [[ -f "$src_hooks/.ckignore" ]] && cp "$src_hooks/.ckignore" "$dst_hooks/.ckignore"

  # Copy lib directory
  for f in "$src_hooks"/lib/*.cjs; do
    [[ -f "$f" ]] || continue
    cp "$f" "$dst_hooks/lib/$(basename "$f")"
  done

  # Ensure runner is executable
  [[ -f "$dst_hooks/node-hook-runner.sh" ]] && chmod +x "$dst_hooks/node-hook-runner.sh"

  printf 'Hooks: transformed %s → claude-plugin/hooks/\n' ".claude/hooks/autoresearch/"
}

# --- Main ---

if [[ $DO_OPENCODE -eq 1 ]]; then transform_opencode; fi
if [[ $DO_CODEX -eq 1 ]]; then transform_codex; fi
transform_hooks

printf 'Transform complete.\n'
