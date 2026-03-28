#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

TOOL=""
LOCATION=""
CONFIG_DIR=""
FORCE=0

cancelled() {
  printf "\nInstallation cancelled\n"
  exit 0
}

trap cancelled INT

usage() {
  cat <<'EOF'
Usage: ./scripts/install.sh [options]

Options:
  --claude            Install for Claude Code
  --opencode          Install for OpenCode
  -g, --global        Install globally
  -l, --local         Install in the current project
  -c, --config-dir    Override the global config directory
  --force             Replace existing managed files without prompting
  -h, --help          Show this help message

Examples:
  ./scripts/install.sh
  ./scripts/install.sh --claude --global
  ./scripts/install.sh --claude --local
  ./scripts/install.sh --opencode --global
  ./scripts/install.sh --opencode --local
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

is_interactive() {
  [[ -t 0 && -t 1 ]]
}

die() {
  printf 'Error: %s\n' "$1" >&2
  exit 1
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --claude)
        [[ -n "$TOOL" && "$TOOL" != "claude" ]] && die "choose only one tool"
        TOOL="claude"
        ;;
      --opencode)
        [[ -n "$TOOL" && "$TOOL" != "opencode" ]] && die "choose only one tool"
        TOOL="opencode"
        ;;
      -g|--global)
        [[ -n "$LOCATION" && "$LOCATION" != "global" ]] && die "choose either --global or --local"
        LOCATION="global"
        ;;
      -l|--local)
        [[ -n "$LOCATION" && "$LOCATION" != "local" ]] && die "choose either --global or --local"
        LOCATION="local"
        ;;
      -c|--config-dir)
        shift
        [[ $# -eq 0 ]] && die "--config-dir requires a path"
        CONFIG_DIR="$(expand_path "$1")"
        ;;
      --config-dir=*)
        CONFIG_DIR="$(expand_path "${1#*=}")"
        [[ -z "$CONFIG_DIR" ]] && die "--config-dir requires a path"
        ;;
      --force)
        FORCE=1
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        die "unknown argument: $1"
        ;;
    esac
    shift
  done

  if [[ -n "$CONFIG_DIR" && "$LOCATION" == "local" ]]; then
    die "--config-dir can only be used with --global"
  fi

  return 0
}

tool_label() {
  case "$1" in
    claude) printf 'Claude Code\n' ;;
    opencode) printf 'OpenCode\n' ;;
    *) die "unsupported tool: $1" ;;
  esac
}

get_global_dir() {
  local tool="$1"

  if [[ -n "$CONFIG_DIR" ]]; then
    printf '%s\n' "$CONFIG_DIR"
    return
  fi

  case "$tool" in
    claude)
      if [[ -n "${CLAUDE_CONFIG_DIR:-}" ]]; then
        expand_path "$CLAUDE_CONFIG_DIR"
      else
        printf '%s\n' "$HOME/.claude"
      fi
      ;;
    opencode)
      if [[ -n "${OPENCODE_CONFIG_DIR:-}" ]]; then
        expand_path "$OPENCODE_CONFIG_DIR"
      elif [[ -n "${OPENCODE_CONFIG:-}" ]]; then
        dirname "$(expand_path "$OPENCODE_CONFIG")"
      elif [[ -n "${XDG_CONFIG_HOME:-}" ]]; then
        printf '%s\n' "$(expand_path "$XDG_CONFIG_HOME")/opencode"
      else
        printf '%s\n' "$HOME/.config/opencode"
      fi
      ;;
    *)
      die "unsupported tool: $tool"
      ;;
  esac
}

get_target_dir() {
  local tool="$1"
  local location="$2"

  if [[ "$location" == "local" ]]; then
    case "$tool" in
      claude) printf '%s\n' "$PWD/.claude" ;;
      opencode) printf '%s\n' "$PWD/.opencode" ;;
      *) die "unsupported tool: $tool" ;;
    esac
    return
  fi

  get_global_dir "$tool"
}

print_tool_menu() {
  cat <<'EOF'
Select the tool to install:
  1) Claude Code
  2) OpenCode
EOF
}

prompt_tool() {
  local answer
  print_tool_menu
  printf 'Choice [1]: '
  if ! read -r answer; then
    cancelled
  fi
  answer="${answer:-1}"
  case "$answer" in
    1) TOOL="claude" ;;
    2) TOOL="opencode" ;;
    *) die "invalid tool selection: $answer" ;;
  esac
}

prompt_location() {
  local claude_global opencode_global answer
  claude_global="$(get_global_dir claude)"
  opencode_global="$(get_global_dir opencode)"

  printf 'Select the installation location for %s:\n' "$(tool_label "$TOOL")"
  case "$TOOL" in
    claude)
      printf '  1) Global (%s)\n' "$claude_global"
      printf '  2) Local  (%s)\n' "$PWD/.claude"
      ;;
    opencode)
      printf '  1) Global (%s)\n' "$opencode_global"
      printf '  2) Local  (%s)\n' "$PWD/.opencode"
      ;;
  esac
  printf 'Choice [1]: '
  if ! read -r answer; then
    cancelled
  fi
  answer="${answer:-1}"
  case "$answer" in
    1) LOCATION="global" ;;
    2) LOCATION="local" ;;
    *) die "invalid location selection: $answer" ;;
  esac
}

ensure_context() {
  if [[ -z "$TOOL" ]]; then
    if is_interactive; then
      prompt_tool
    else
      TOOL="claude"
    fi
  fi

  if [[ -z "$LOCATION" ]]; then
    if is_interactive; then
      prompt_location
    else
      LOCATION="global"
    fi
  fi
}

managed_paths() {
  local tool="$1"
  local target_root="$2"
  local src

  case "$tool" in
    claude)
      printf '%s\n' \
        "$target_root/skills/autoresearch" \
        "$target_root/commands/autoresearch" \
        "$target_root/commands/autoresearch.md"
      ;;
    opencode)
      printf '%s\n' \
        "$target_root/skills/autoresearch" \
        "$target_root/agents/docs-manager.md" \
        "$target_root/commands/autoresearch"
      for src in "$REPO_ROOT"/.opencode/commands/*.md; do
        printf '%s\n' "$target_root/commands/$(basename "$src")"
      done
      ;;
  esac
}

confirm_reinstall_if_needed() {
  local tool="$1"
  local target_root="$2"
  local existing=0
  local answer path

  while IFS= read -r path; do
    if [[ -e "$path" ]]; then
      existing=1
      break
    fi
  done < <(managed_paths "$tool" "$target_root")

  if [[ $existing -eq 0 || $FORCE -eq 1 ]]; then
    return
  fi

  if ! is_interactive; then
    return
  fi

  printf 'Existing Autoresearch files were found in %s. Replace the managed files? [Y/n]: ' "$target_root"
  if ! read -r answer; then
    cancelled
  fi
  answer="${answer:-Y}"
  case "$answer" in
    y|Y|yes|YES|'') return ;;
    n|N|no|NO)
      printf 'Skipped installation.\n'
      exit 0
      ;;
    *) die "invalid choice: $answer" ;;
  esac
}

sync_dir() {
  local src="$1"
  local dest="$2"
  rm -rf "$dest"
  mkdir -p "$(dirname "$dest")"
  cp -R "$src" "$dest"
}

sync_file() {
  local src="$1"
  local dest="$2"
  mkdir -p "$(dirname "$dest")"
  cp "$src" "$dest"
}

install_claude() {
  local target_root="$1"

  mkdir -p "$target_root/skills" "$target_root/commands"
  sync_dir "$REPO_ROOT/claude-plugin/skills/autoresearch" "$target_root/skills/autoresearch"
  sync_dir "$REPO_ROOT/claude-plugin/commands/autoresearch" "$target_root/commands/autoresearch"
  sync_file "$REPO_ROOT/claude-plugin/commands/autoresearch.md" "$target_root/commands/autoresearch.md"
}

install_opencode() {
  local target_root="$1"
  local src

  mkdir -p "$target_root/skills" "$target_root/commands" "$target_root/agents"
  sync_dir "$REPO_ROOT/.opencode/skills/autoresearch" "$target_root/skills/autoresearch"
  rm -rf "$target_root/commands/autoresearch"
  for src in "$REPO_ROOT"/.opencode/commands/*.md; do
    sync_file "$src" "$target_root/commands/$(basename "$src")"
  done
  sync_file "$REPO_ROOT/.opencode/agents/docs-manager.md" "$target_root/agents/docs-manager.md"
}

main() {
  local target_root

  parse_args "$@"
  ensure_context
  target_root="$(get_target_dir "$TOOL" "$LOCATION")"

  confirm_reinstall_if_needed "$TOOL" "$target_root"

  printf 'Installing Autoresearch for %s (%s)\n' "$(tool_label "$TOOL")" "$LOCATION"
  printf 'Target: %s\n' "$target_root"

  case "$TOOL" in
    claude) install_claude "$target_root" ;;
    opencode) install_opencode "$target_root" ;;
    *) die "unsupported tool: $TOOL" ;;
  esac

  printf 'Done.\n'
}

main "$@"
