#!/usr/bin/env bash
# Prepare a release branch, verify it, push it, and open a PR. This script never
# merges, tags, or publishes; those are separate owner-approved operations.
set -euo pipefail

VERSION=""
TITLE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --title) [[ $# -ge 2 ]] || { echo "Error: --title requires text" >&2; exit 1; }; TITLE="$2"; shift 2 ;;
    -h|--help) echo 'Usage: ./scripts/release.sh <X.Y.Z> [--title "Release title"]'; exit 0 ;;
    *) [[ -z "$VERSION" ]] || { echo "Error: unexpected argument: $1" >&2; exit 1; }; VERSION="${1#v}"; shift ;;
  esac
done

[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
  echo "Error: version must be X.Y.Z" >&2
  exit 1
}

TAG="v$VERSION"
BRANCH="release/$VERSION"
OWNER="uditgoenka"

die() { printf 'Error: %s\n' "$1" >&2; exit 1; }
replace_line() {
  local file="$1" expression="$2"
  sed "$expression" "$file" > "$file.tmp"
  mv "$file.tmp" "$file"
}

[[ -f claude-plugin/.claude-plugin/plugin.json ]] || die "run from the repository root"
command -v gh >/dev/null 2>&1 || die "gh CLI not found"
[[ -z "$(git status --porcelain)" ]] || die "working tree is dirty"
[[ "$(git branch --show-current)" == master ]] || die "must run from master"
[[ "$(git config user.name)" == "$OWNER" ]] || die "Git author must be $OWNER"

REMOTE_URL="$(git remote get-url origin)"
case "$REMOTE_URL" in
  https://github.com/$OWNER/*|git@github.com:$OWNER/*|ssh://git@github.com/$OWNER/*) ;;
  *) die "origin must belong to $OWNER" ;;
esac
[[ "$(gh api user --jq .login)" == "$OWNER" ]] || die "GitHub account must be $OWNER"

for helper in scripts/orchestrate.sh scripts/score-regression.sh; do
  [[ -x "$helper" ]] || die "missing executable runtime helper: $helper"
done

git pull --ff-only origin master --quiet

# Refuse pre-existing generated drift before creating a release branch.
bash scripts/transform.sh >/dev/null
git diff --exit-code >/dev/null || die "generated distributions were stale; review and commit the transform first"
[[ -z "$(git status --porcelain)" ]] || die "transform produced untracked drift"

[[ -z "$(git tag -l "$TAG")" ]] || die "tag $TAG already exists locally"
[[ -z "$(git ls-remote --tags origin "refs/tags/$TAG")" ]] || die "tag $TAG already exists remotely"

CURRENT="$(node -p "require('./claude-plugin/.claude-plugin/plugin.json').version")"
LAST_TAG="$(git describe --tags --abbrev=0 2>/dev/null || true)"

git checkout -b "$BRANCH"

node - "$VERSION" <<'NODE'
const fs = require('fs');
const version = process.argv[2];
for (const file of ['claude-plugin/.claude-plugin/plugin.json', '.claude-plugin/marketplace.json']) {
  const value = JSON.parse(fs.readFileSync(file, 'utf8'));
  value.version = version;
  if (Array.isArray(value.plugins)) value.plugins.forEach((plugin) => { plugin.version = version; });
  fs.writeFileSync(file, `${JSON.stringify(value, null, 2)}\n`);
}
const codexFile = 'plugins/autoresearch/.codex-plugin/plugin.json';
const codex = JSON.parse(fs.readFileSync(codexFile, 'utf8'));
codex.version = `${version}-codex.0`;
fs.writeFileSync(codexFile, `${JSON.stringify(codex, null, 2)}\n`);
NODE

replace_line .claude/skills/autoresearch/SKILL.md "s/^version: .*/version: $VERSION/"
for file in README.md guide/README.md; do
  replace_line "$file" "s/version-[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*-blue/version-$VERSION-blue/"
done

bash scripts/transform.sh >/dev/null

for file in \
  .claude/skills/autoresearch/SKILL.md \
  claude-plugin/skills/autoresearch/SKILL.md \
  .opencode/skills/autoresearch/SKILL.md \
  .agents/skills/autoresearch/SKILL.md \
  plugins/autoresearch/skills/autoresearch/SKILL.md; do
  grep -qx "version: $VERSION" "$file" || die "version drift: $file"
done
node - "$VERSION" <<'NODE'
const version = process.argv[2];
const checks = [
  [require('./claude-plugin/.claude-plugin/plugin.json').version, version],
  [require('./.claude-plugin/marketplace.json').version, version],
  [require('./.claude-plugin/marketplace.json').plugins[0].version, version],
  [require('./plugins/autoresearch/.codex-plugin/plugin.json').version, `${version}-codex.0`],
];
if (checks.some(([actual, expected]) => actual !== expected)) process.exit(1);
NODE

for suite in test-hooks.sh test-orchestrator.sh test-regression.sh test-maintenance.sh; do
  bash "tests/$suite"
done

git add -A
git commit -m "chore(release): prepare $TAG for explicit publication" \
  -m "Release preparation aligns versions, regenerates every distribution, and records a green local release gate. Merge, tag creation, and publication remain separate owner actions." \
  -m "Constraint: All release artifacts must be created by uditgoenka" \
  -m "Confidence: high" \
  -m "Scope-risk: moderate" \
  -m "Directive: Do not merge, tag, or publish from release preparation automation" \
  -m "Tested: hooks, orchestrator, regression, maintenance, transform parity, version parity" \
  -m "Not-tested: cross-platform matrix runs after PR creation"

git push -u origin "$BRANCH"

CHANGELOG="No previous tag found."
if [[ -n "$LAST_TAG" ]]; then
  CHANGELOG="$(git log "$LAST_TAG"..HEAD --oneline --no-decorate | sed 's/^/- /')"
fi

PR_TITLE="${TITLE:-Release $TAG}"
[[ ${#PR_TITLE} -le 70 ]] || PR_TITLE="Release $TAG"
PR_URL="$(gh pr create --base master --head "$BRANCH" --title "$PR_TITLE" --body "$(cat <<EOF
## Release $TAG

**Version bump:** \`$CURRENT\` → \`$VERSION\`

### Changes since ${LAST_TAG:-the initial release}
$CHANGELOG

### Verified before publication
- [x] Canonical transform produced no pre-existing drift
- [x] Claude, OpenCode, and Codex versions agree
- [x] Hook, orchestrator, regression, and maintenance suites pass
- [x] Disposable clean installs execute bundled helpers
- [ ] Pull-request matrix passes on Linux, macOS, and Windows/Git Bash
- [ ] Owner explicitly approves merge
- [ ] Owner separately creates immutable tag and GitHub release

Preparation stops here. This script cannot merge, tag, or publish.
EOF
)" )"

printf 'Release PR created: %s\n' "$PR_URL"
printf 'Next: wait for the release-readiness matrix, review, and approve merge separately.\n'
