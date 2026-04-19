#!/usr/bin/env bash
# Autoresearch installer — supports Claude Code, OpenCode, Codex, and Kilo.

set -euo pipefail

cyan='\033[0;36m'
green='\033[0;32m'
yellow='\033[0;33m'
dim='\033[2m'
reset='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

TOOL=""
LOCATION=""
CONFIG_DIR=""
FORCE=0

cancelled() { printf "\nInstallation cancelled\n"; exit 0; }
trap cancelled INT

usage() {
  cat <<'EOF'
Usage: ./scripts/install.sh [options]

Options:
  --claude            Install for Claude Code
  --opencode          Install for OpenCode
  --codex             Install for OpenAI Codex
  --kilo             Install for Kilo
  -g, --global        Install globally
  -l, --local         Install in the current project
  -c, --config-dir    Override the global config directory
  --force             Replace existing files without prompting
  -h, --help          Show this help message

Examples:
  ./scripts/install.sh                          # interactive
  ./scripts/install.sh --claude --global
  ./scripts/install.sh --opencode --local
  ./scripts/install.sh --codex --global
  ./scripts/install.sh --kilo --global
EOF
}

expand_path() {
  local raw="$1"
  if [[ "$raw" == ~* ]]; then
    printf '%s\n' "${raw/#\~/$HOME}"
  else
    printf '%s\n' "$raw"
  fi
}

is_interactive() { [[ -t 0 && -t 1 ]]; }

die() { printf 'Error: %s\n' "$1" >&2; exit 1; }

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --claude)
        if [[ -n "$TOOL" && "$TOOL" != "claude" ]]; then die "choose only one tool"; fi
        TOOL="claude" ;;
      --opencode)
        if [[ -n "$TOOL" && "$TOOL" != "opencode" ]]; then die "choose only one tool"; fi
        TOOL="opencode" ;;
      --codex)
        if [[ -n "$TOOL" && "$TOOL" != "codex" ]]; then die "choose only one tool"; fi
        TOOL="codex" ;;
      --kilo)
        if [[ -n "$TOOL" && "$TOOL" != "kilo" ]]; then die "choose only one tool"; fi
        TOOL="kilo" ;;
      -g|--global)
        if [[ -n "$LOCATION" && "$LOCATION" != "global" ]]; then die "choose --global or --local"; fi
        LOCATION="global" ;;
      -l|--local)
        if [[ -n "$LOCATION" && "$LOCATION" != "local" ]]; then die "choose --global or --local"; fi
        LOCATION="local" ;;
      -c|--config-dir)
        shift
        if [[ $# -eq 0 ]]; then die "--config-dir requires a path"; fi
        CONFIG_DIR="$(expand_path "$1")" ;;
      --config-dir=*)
        CONFIG_DIR="$(expand_path "${1#*=}")"
        if [[ -z "$CONFIG_DIR" ]]; then die "--config-dir requires a path"; fi ;;
      --force) FORCE=1 ;;
      -h|--help) usage; exit 0 ;;
      *) die "unknown argument: $1" ;;
    esac
    shift
  done
  if [[ -n "$CONFIG_DIR" && "$LOCATION" == "local" ]]; then
    die "--config-dir can only be used with --global"
  fi
}

get_global_dir() {
  local tool="$1"
  if [[ -n "$CONFIG_DIR" ]]; then printf '%s\n' "$CONFIG_DIR"; return; fi
  case "$tool" in
    claude)
      if [[ -n "${CLAUDE_CONFIG_DIR:-}" ]]; then
        expand_path "$CLAUDE_CONFIG_DIR"
      else
        printf '%s\n' "$HOME/.claude"
      fi ;;
    opencode)
      if [[ -n "${OPENCODE_CONFIG_DIR:-}" ]]; then expand_path "$OPENCODE_CONFIG_DIR"
      elif [[ -n "${OPENCODE_CONFIG:-}" ]]; then dirname "$(expand_path "$OPENCODE_CONFIG")"
      elif [[ -n "${XDG_CONFIG_HOME:-}" ]]; then printf '%s\n' "$(expand_path "$XDG_CONFIG_HOME")/opencode"
      else printf '%s\n' "$HOME/.config/opencode"; fi ;;
    codex)
      if [[ -n "${CODEX_HOME:-}" ]]; then expand_path "$CODEX_HOME"
      else printf '%s\n' "$HOME/.agents"; fi ;;
    kilo)
      if [[ -n "${KILO_CONFIG_DIR:-}" ]]; then expand_path "$KILO_CONFIG_DIR"
      elif [[ -n "${KILO_CONFIG:-}" ]]; then dirname "$(expand_path "$KILO_CONFIG")"
      elif [[ -n "${XDG_CONFIG_HOME:-}" ]]; then printf '%s\n' "$(expand_path "$XDG_CONFIG_HOME")/kilo"
      else printf '%s\n' "$HOME/.config/kilo"; fi ;;
  esac
}

get_target_dir() {
  local tool="$1" location="$2"
  if [[ "$location" == "local" ]]; then
    case "$tool" in
      claude) printf '%s\n' "$PWD/.claude" ;;
      opencode) printf '%s\n' "$PWD/.opencode" ;;
      codex) printf '%s\n' "$PWD/.agents" ;;
      kilo) printf '%s\n' "$PWD/.kilo" ;;
    esac
    return
  fi
  get_global_dir "$tool"
}

prompt_tool() {
  local answer
  printf 'Select the tool to install:\n  1) Claude Code\n  2) OpenCode\n  3) OpenAI Codex\n  4) Kilo\nChoice [1]: '
  read -r answer || cancelled
  case "${answer:-1}" in
    1) TOOL="claude" ;;
    2) TOOL="opencode" ;;
    3) TOOL="codex" ;;
    4) TOOL="kilo" ;;
    *) die "invalid selection: $answer" ;;
  esac
}

prompt_location() {
  local global_dir answer local_dir
  global_dir="$(get_global_dir "$TOOL")"
  case "$TOOL" in claude) local_dir="$PWD/.claude" ;; opencode) local_dir="$PWD/.opencode" ;; codex) local_dir="$PWD/.agents" ;; kilo) local_dir="$PWD/.kilo" ;; esac
  printf 'Install location:\n  1) Global (%s)\n  2) Local  (%s)\nChoice [1]: ' "$global_dir" "$local_dir"
  read -r answer || cancelled
  case "${answer:-1}" in
    1) LOCATION="global" ;;
    2) LOCATION="local" ;;
    *) die "invalid selection: $answer" ;;
  esac
}

ensure_context() {
  if [[ -z "$TOOL" ]]; then
    if is_interactive; then prompt_tool; else TOOL="claude"; fi
  fi
  if [[ -z "$LOCATION" ]]; then
    if is_interactive; then prompt_location; else LOCATION="global"; fi
  fi
}

sync_dir() { rm -rf "$2"; mkdir -p "$(dirname "$2")"; cp -R "$1" "$2"; }
sync_file() { mkdir -p "$(dirname "$2")"; cp "$1" "$2"; }

confirm_overwrite() {
  local target_root="$1"
  if [[ $FORCE -eq 1 ]]; then return 0; fi
  if [[ ! -d "$target_root/skills/autoresearch" ]]; then return 0; fi
  if ! is_interactive; then return 0; fi
  local answer
  printf 'Existing autoresearch files found in %s. Replace? [Y/n]: ' "$target_root"
  read -r answer || cancelled
  case "${answer:-Y}" in
    [yY]|[yY][eE][sS]|'') ;;
    *) printf 'Skipped.\n'; exit 0 ;;
  esac
}

install_claude() {
  local t="$1"
  mkdir -p "$t/skills" "$t/commands"
  sync_dir "$REPO_ROOT/.claude/skills/autoresearch" "$t/skills/autoresearch"
  if [[ -d "$REPO_ROOT/.claude/commands/autoresearch" ]]; then
    sync_dir "$REPO_ROOT/.claude/commands/autoresearch" "$t/commands/autoresearch"
  fi
  if [[ -f "$REPO_ROOT/.claude/commands/autoresearch.md" ]]; then
    sync_file "$REPO_ROOT/.claude/commands/autoresearch.md" "$t/commands/autoresearch.md"
  fi
}

install_opencode() {
  local t="$1" src
  mkdir -p "$t/skills" "$t/commands" "$t/agents"
  sync_dir "$REPO_ROOT/.opencode/skills/autoresearch" "$t/skills/autoresearch"
  for src in "$REPO_ROOT"/.opencode/commands/autoresearch*.md; do
    if [[ -f "$src" ]]; then
      sync_file "$src" "$t/commands/$(basename "$src")"
    fi
  done
  sync_file "$REPO_ROOT/.opencode/agents/docs-manager.md" "$t/agents/docs-manager.md"
}

install_codex() {
  local t="$1"
  mkdir -p "$t/skills"
  sync_dir "$REPO_ROOT/.agents/skills/autoresearch" "$t/skills/autoresearch"
}

install_kilo() {
  local t="$1"
  mkdir -p "$t/skills" "$t/command"
  sync_dir "$REPO_ROOT/.opencode/skills/autoresearch" "$t/skills/autoresearch"
  for src in "$REPO_ROOT"/.opencode/commands/autoresearch*.md; do
    if [[ -f "$src" ]]; then
      sync_file "$src" "$t/command/$(basename "$src")"
    fi
  done
  configure_kilo_permissions "$t"
}

configure_kilo_permissions() {
  local kilo_dir="$1"
  local config_file
  if [[ -f "$kilo_dir/kilo.jsonc" ]]; then
    config_file="$kilo_dir/kilo.jsonc"
  elif [[ -f "$kilo_dir/kilo.json" ]]; then
    config_file="$kilo_dir/kilo.json"
  else
    config_file="$kilo_dir/kilo.json"
  fi

  # Determine the Autoresearch path to permit
  local ar_path
  ar_path="$kilo_dir/autoresearch/*"
  if [[ "$kilo_dir" == "$HOME/.config/kilo" ]]; then
    ar_path="~/.config/kilo/autoresearch/*"
  elif [[ "$kilo_dir" == "$PWD/.kilo" ]]; then
    ar_path="./.kilo/autoresearch/*"
  else
    ar_path="${kilo_dir}/autoresearch/*"
  fi

  # Create default config if missing
  if [[ ! -f "$kilo_dir/kilo.json" && ! -f "$kilo_dir/kilo.jsonc" ]]; then
    config_file="$kilo_dir/kilo.jsonc"
    cat > "$config_file" <<'CONFIGEOF'
{
  // Autoresearch permissions - allows reading skills and reference docs
  "permission": {
    "read": {},
    "external_directory": {}
  }
}
CONFIGEOF
  fi

  # Use JSONC if exists, otherwise JSON
  if [[ -f "$kilo_dir/kilo.jsonc" ]]; then
    config_file="$kilo_dir/kilo.jsonc"
  else
    config_file="$kilo_dir/kilo.json"
  fi

  # Python script to validate and update JSONC (handles both .json and .jsonc)
  local tmp_file
  tmp_file=$(mktemp) || return 1

  python3 - "$config_file" "$ar_path" "$tmp_file" <<'PYEOF'
import json
import sys
import re

config_path = sys.argv[1]
ar_path = sys.argv[2]
tmp_path = sys.argv[3]

# Read and strip JSONC comments and parse
with open(config_path, 'r') as f:
    content = f.read()

# Strip single-line comments (only at start of line after whitespace)
content = re.sub(r'^(\s*)//.*$', r'\1', content, flags=re.MULTILINE)
# Strip multi-line comments
content = re.sub(r'/\*.*?\*/', '', content, flags=re.DOTALL)
# Remove trailing commas before } or ]
content = re.sub(r',(\s*[}\]])', r'\1', content)

try:
    config = json.loads(content)
except Exception as e:
    print(f'Error: {e}')
    sys.exit(1)

if 'permission' not in config:
    config['permission'] = {}
if 'read' not in config['permission']:
    config['permission']['read'] = {}
if ar_path not in config['permission']['read']:
    config['permission']['read'][ar_path] = 'allow'
if 'external_directory' not in config['permission']:
    config['permission']['external_directory'] = {}
if ar_path not in config['permission']['external_directory']:
    config['permission']['external_directory'][ar_path] = 'allow'

with open(tmp_path, 'w') as f:
    json.dump(config, f, indent=2)
PYEOF

  if [[ -f "$tmp_file" ]] && [[ -s "$tmp_file" ]]; then
    mv "$tmp_file" "$config_file"
    printf '  %s✓%s  Configured read permission for Autoresearch skills\n' "$green" "$reset"
  else
    printf '  %s⚠%s  Could not parse kilo.json - skipping permission config\n' "$yellow" "$reset"
  fi
  rm -f "$tmp_file"
}

main() {
  parse_args "$@"
  ensure_context
  local target_root
  target_root="$(get_target_dir "$TOOL" "$LOCATION")"
  confirm_overwrite "$target_root"

  local label
  case "$TOOL" in claude) label="Claude Code" ;; opencode) label="OpenCode" ;; codex) label="OpenAI Codex" ;; kilo) label="Kilo" ;; esac
  printf 'Installing Autoresearch for %s (%s)\nTarget: %s\n' "$label" "$LOCATION" "$target_root"

  case "$TOOL" in
    claude) install_claude "$target_root" ;;
    opencode) install_opencode "$target_root" ;;
    codex) install_codex "$target_root" ;;
    kilo) install_kilo "$target_root" ;;
  esac

  case "$TOOL" in
    codex) printf 'Done. Use $autoresearch in Codex to start.\n' ;;
    kilo) printf 'Done. Run /autoresearch in Kilo to start.\n' ;;
    *) printf 'Done. Run /autoresearch to start.\n' ;;
  esac
}

main "$@"
