#!/bin/bash
# Maintenance contract: deterministic transforms and fail-closed release preparation.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PASS=0; FAIL=0; TOTAL=0
pass() { printf '  PASS: %s\n' "$1"; PASS=$((PASS + 1)); TOTAL=$((TOTAL + 1)); }
fail() { printf '  FAIL: %s\n' "$1"; FAIL=$((FAIL + 1)); TOTAL=$((TOTAL + 1)); }

assert_success() { "$@" >/dev/null 2>&1 && pass "$*" || fail "$*"; }
assert_contains() { printf '%s' "$2" | grep -q -- "$1" && pass "$3" || fail "$3"; }
assert_not_contains() { ! printf '%s' "$2" | grep -q -- "$1" && pass "$3" || fail "$3"; }

TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/autoresearch-maintenance-XXXXXX")
trap 'rm -rf "$TMP_ROOT"' EXIT

copy_checkout() {
  local dst="$1"
  mkdir -p "$dst"
  (cd "$REPO_ROOT" && tar --exclude='./.git' --exclude='./.preprgate' -cf - .) \
    | (cd "$dst" && tar -xf -)
}

printf '\n--- transform: deterministic generated distributions ---\n'
SNAPSHOT="$TMP_ROOT/transform"
copy_checkout "$SNAPSHOT"
(
  cd "$SNAPSHOT" || exit 1
  git init -q
  git config user.name test
  git config user.email test@example.com
  git add -A && git commit -qm baseline
  bash scripts/transform.sh >/dev/null
  git diff --quiet && [[ -z "$(git status --porcelain)" ]]
) && pass "transform is idempotent with no generated drift" || fail "transform is idempotent with no generated drift"

(
  cd "$SNAPSHOT" || exit 1
  printf '\ncanonical sentinel\n' >> .claude/skills/autoresearch/scripts/orchestrate.sh
  printf '\nclaude sentinel\n' >> claude-plugin/commands/autoresearch.md
  printf '\ncodex sentinel\n' >> plugins/autoresearch/skills/autoresearch/autoresearch.md
  before=$(git hash-object .claude/skills/autoresearch/scripts/orchestrate.sh claude-plugin/commands/autoresearch.md plugins/autoresearch/skills/autoresearch/autoresearch.md)
  bash scripts/transform.sh --opencode >/dev/null
  after=$(git hash-object .claude/skills/autoresearch/scripts/orchestrate.sh claude-plugin/commands/autoresearch.md plugins/autoresearch/skills/autoresearch/autoresearch.md)
  [[ "$before" == "$after" ]]
) && pass "--opencode leaves Claude and Codex surfaces untouched" || fail "--opencode leaves Claude and Codex surfaces untouched"

git -C "$SNAPSHOT" reset --hard -q
(
  cd "$SNAPSHOT" || exit 1
  printf '\ncanonical sentinel\n' >> .claude/skills/autoresearch/scripts/orchestrate.sh
  printf '\nclaude sentinel\n' >> claude-plugin/commands/autoresearch.md
  printf '\nopencode sentinel\n' >> .opencode/commands/autoresearch.md
  before=$(git hash-object .claude/skills/autoresearch/scripts/orchestrate.sh claude-plugin/commands/autoresearch.md .opencode/commands/autoresearch.md)
  bash scripts/transform.sh --codex >/dev/null
  after=$(git hash-object .claude/skills/autoresearch/scripts/orchestrate.sh claude-plugin/commands/autoresearch.md .opencode/commands/autoresearch.md)
  [[ "$before" == "$after" ]]
) && pass "--codex leaves Claude and OpenCode surfaces untouched" || fail "--codex leaves Claude and OpenCode surfaces untouched"

for skill in \
  .claude/skills/autoresearch \
  claude-plugin/skills/autoresearch \
  .opencode/skills/autoresearch \
  .agents/skills/autoresearch \
  plugins/autoresearch/skills/autoresearch; do
  for helper in orchestrate.sh score-regression.sh; do
    generated="$REPO_ROOT/$skill/scripts/$helper"
    [[ -x "$generated" ]] && cmp -s "$REPO_ROOT/scripts/$helper" "$generated" \
      && pass "$skill bundles canonical $helper" \
      || fail "$skill bundles canonical $helper"
  done
done

printf '\n--- release: refuse before publication side effects ---\n'
make_fake_tools() {
  local root="$1"
  local bin="$root/fake-bin"
  mkdir -p "$bin"
  cat > "$bin/git" <<'EOF'
#!/bin/bash
printf 'git %s\n' "$*" >> "$FAKE_CALL_LOG"
case "$1 $2" in
  "status --porcelain") exit 0 ;;
  "branch --show-current") echo master ;;
  "config user.name") echo "${FAKE_GIT_USER:-uditgoenka}" ;;
  "remote get-url") echo "https://github.com/${FAKE_REMOTE_OWNER:-uditgoenka}/autoresearch.git" ;;
  "tag -l") exit 0 ;;
  "ls-remote --tags") exit 0 ;;
  "describe --tags") echo v2.2.1 ;;
  "diff --exit-code") [[ "${FAKE_TRANSFORM_DRIFT:-0}" == 1 ]] && exit 1 || exit 0 ;;
  "diff --cached") exit 1 ;;
  "diff --name-only") echo README.md ;;
  "log v2.2.1..HEAD") echo 'abc123 test change' ;;
esac
exit 0
EOF
  cat > "$bin/gh" <<'EOF'
#!/bin/bash
printf 'gh %s\n' "$*" >> "$FAKE_CALL_LOG"
if [[ "$1 $2" == "api user" ]]; then echo "${FAKE_GH_USER:-uditgoenka}"; exit 0; fi
if [[ "$1 $2" == "pr create" ]]; then echo 'https://github.com/uditgoenka/autoresearch/pull/999'; exit 0; fi
exit 0
EOF
  cat > "$bin/bash" <<'EOF'
#!/bin/bash
script="${1:-}"
printf 'bash %s\n' "$*" >> "$FAKE_CALL_LOG"
if [[ "$script" == */transform.sh ]]; then
  [[ "${FAKE_TRANSFORM_FAIL:-0}" == 1 ]] && exit 1
  [[ "${FAKE_RUN_REAL_TRANSFORM:-0}" == 1 ]] && exec /bin/bash "$@"
  exit 0
fi
if [[ "$script" == */test-*.sh || "$script" == tests/test-*.sh ]]; then
  [[ "${FAKE_FAIL_SUITE:-}" == "$(basename "$script")" ]] && exit 1
  exit 0
fi
exec /bin/bash "$@"
EOF
  chmod +x "$bin/git" "$bin/gh" "$bin/bash"
}

run_release_case() {
  local name="$1" version="$2"; shift 2
  local root="$TMP_ROOT/$name" out code=0
  copy_checkout "$root"
  make_fake_tools "$root"
  : > "$root/calls.log"
  out=$(cd "$root" && env \
    PATH="$root/fake-bin:$PATH" \
    FAKE_CALL_LOG="$root/calls.log" \
    "$@" \
    /bin/bash scripts/release.sh "$version" --title Test 2>&1) || code=$?
  RELEASE_OUT="$out"
  RELEASE_CODE=$code
  RELEASE_CALLS=$(cat "$root/calls.log")
}

assert_refused_before_publish() {
  local label="$1"
  [[ "$RELEASE_CODE" -ne 0 ]] && pass "$label is refused" || fail "$label is refused"
  assert_not_contains 'git push' "$RELEASE_CALLS" "$label does not push"
  assert_not_contains 'gh pr create' "$RELEASE_CALLS" "$label does not create a PR"
  assert_not_contains 'gh pr merge\|gh release create\|git tag -a' "$RELEASE_CALLS" "$label cannot merge, tag, or publish"
}

run_release_case malformed-version 2.2 RELEASE_OUT=1
assert_refused_before_publish "malformed version"

run_release_case wrong-git-user 2.2.2 FAKE_GIT_USER=udit-fs
assert_refused_before_publish "wrong Git author"

run_release_case wrong-remote-owner 2.2.2 FAKE_REMOTE_OWNER=udit-fs
assert_refused_before_publish "wrong origin owner"

run_release_case wrong-gh-user 2.2.2 FAKE_GH_USER=udit-fs
assert_refused_before_publish "wrong GitHub account"

run_release_case stale-transform 2.2.2 FAKE_TRANSFORM_DRIFT=1
assert_refused_before_publish "stale generated output"

run_release_case failed-suite 2.2.2 FAKE_RUN_REAL_TRANSFORM=1 FAKE_FAIL_SUITE=test-hooks.sh
assert_refused_before_publish "failed test suite"

run_release_case failed-install-smoke 2.2.2 FAKE_RUN_REAL_TRANSFORM=1 FAKE_FAIL_SUITE=test-maintenance.sh
assert_refused_before_publish "failed install smoke"

MISSING_ROOT="$TMP_ROOT/missing-helper"
copy_checkout "$MISSING_ROOT"
rm -f "$MISSING_ROOT/scripts/orchestrate.sh"
make_fake_tools "$MISSING_ROOT"
: > "$MISSING_ROOT/calls.log"
RELEASE_CODE=0
RELEASE_OUT=$(cd "$MISSING_ROOT" && env PATH="$MISSING_ROOT/fake-bin:$PATH" \
  FAKE_CALL_LOG="$MISSING_ROOT/calls.log" /bin/bash scripts/release.sh 2.2.2 --title Test 2>&1) || RELEASE_CODE=$?
RELEASE_CALLS=$(cat "$MISSING_ROOT/calls.log")
assert_refused_before_publish "missing runtime helper"

run_release_case success 9.9.9 FAKE_RUN_REAL_TRANSFORM=1
[[ "$RELEASE_CODE" -eq 0 ]] && pass "green release preparation succeeds" || fail "green release preparation succeeds"
assert_contains 'git push' "$RELEASE_CALLS" "green release preparation pushes its branch"
assert_contains 'gh pr create' "$RELEASE_CALLS" "green release preparation opens a PR"
assert_contains 'bash scripts/transform.sh' "$RELEASE_CALLS" "green release preparation invokes the canonical transform"
assert_not_contains 'gh pr merge\|gh release create\|git tag -a' "$RELEASE_CALLS" "release preparation stops before merge, tag, and publication"

printf '\n=== Results: %d/%d passed ===' "$PASS" "$TOTAL"
if [[ "$FAIL" -gt 0 ]]; then printf ' (%d FAILED)\n' "$FAIL"; exit 1; else printf ' (all passed)\n'; exit 0; fi
