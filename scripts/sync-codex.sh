#!/usr/bin/env bash
# Sync .claude/skills/autoresearch/ → .agents/skills/autoresearch/
# Applies Codex-specific adaptations (tool names, command syntax, paths)
# Run this after any change to the Claude Code source files.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

SRC="$REPO_ROOT/.claude/skills/autoresearch"
DST="$REPO_ROOT/.agents/skills/autoresearch"

if [[ ! -d "$SRC" ]]; then
  printf 'Error: source directory not found: %s\n' "$SRC" >&2
  exit 1
fi

mkdir -p "$DST/references"

adapt_file() {
  local src_file="$1"
  local dst_file="$2"

  sed \
    -e 's/`AskUserQuestion`/direct prompting/g' \
    -e 's/AskUserQuestion/direct prompting/g' \
    -e 's|/autoresearch:plan|$autoresearch plan|g' \
    -e 's|/autoresearch:debug|$autoresearch debug|g' \
    -e 's|/autoresearch:fix|$autoresearch fix|g' \
    -e 's|/autoresearch:security|$autoresearch security|g' \
    -e 's|/autoresearch:ship|$autoresearch ship|g' \
    -e 's|/autoresearch:scenario|$autoresearch scenario|g' \
    -e 's|/autoresearch:predict|$autoresearch predict|g' \
    -e 's|/autoresearch:learn|$autoresearch learn|g' \
    -e 's|/autoresearch:reason|$autoresearch reason|g' \
    -e 's|/autoresearch:probe|$autoresearch probe|g' \
    -e 's|`/autoresearch`|`$autoresearch`|g' \
    -e 's| /autoresearch | $autoresearch |g' \
    -e 's|^/autoresearch$|$autoresearch|g' \
    -e 's|^/autoresearch |$autoresearch |g' \
    -e 's|`Agent tool`|Codex subagent|g' \
    -e 's|`Agent` tool|Codex subagent|g' \
    -e 's|\.claude/skills/autoresearch|.agents/skills/autoresearch|g' \
    -e 's|\.opencode/skills/autoresearch|.agents/skills/autoresearch|g' \
    "$src_file" > "$dst_file"
}

# Sync reference files
for f in "$SRC"/references/*.md; do
  basename=$(basename "$f")
  adapt_file "$f" "$DST/references/$basename"
  printf '  synced: references/%s\n' "$basename"
done

# Sync and adapt SKILL.md (requires extra frontmatter changes)
adapt_file "$SRC/SKILL.md" "$DST/SKILL.md"

# Patch frontmatter: remove version, add metadata block
python3 -c "
import re, sys, os

dst = sys.argv[1]
skill_path = os.path.join(dst, 'SKILL.md')

with open(skill_path, 'r') as f:
    content = f.read()

content = content.replace('# Claude Autoresearch', '# Codex Autoresearch', 1)

content = re.sub(
    r'^(---\nname: autoresearch\ndescription:.*?)version: ([\d.]+)\n(---)',
    r'\1metadata:\n  source: claude-port\n  version: \2\n  short-description: Autonomous goal-directed iteration engine\n\3',
    content,
    count=1,
    flags=re.DOTALL
)

with open(skill_path, 'w') as f:
    f.write(content)
" "$DST" 2>/dev/null || {
  printf 'Warning: python3 frontmatter patch failed, SKILL.md may need manual review\n' >&2
}

printf '  synced: SKILL.md\n'

# Create agents/openai.yaml for UI metadata
mkdir -p "$DST/agents"
cat > "$DST/agents/openai.yaml" << 'YAML'
interface:
  display_name: "Autoresearch"
  short_description: "Autonomous goal-directed iteration engine"
  brand_color: "#7C3AED"
  default_prompt: "Set a goal, define a metric, let Codex loop until done"

policy:
  allow_implicit_invocation: true
YAML
printf '  created: agents/openai.yaml\n'

# Count results
total=$(find "$DST" -name '*.md' -o -name '*.yaml' | wc -l | tr -d ' ')
printf 'Sync complete: %s files updated in %s\n' "$total" "$DST"
