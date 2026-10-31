#!/bin/bash
# Install contract: install.sh places the right skill surface per tool and location.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PASS=0; FAIL=0; TOTAL=0
pass() { printf '  PASS: %s\n' "$1"; PASS=$((PASS + 1)); TOTAL=$((TOTAL + 1)); }
fail() { printf '  FAIL: %s\n' "$1"; FAIL=$((FAIL + 1)); TOTAL=$((TOTAL + 1)); }

TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/autoresearch-install-XXXXXX")
trap 'rm -rf "$TMP_ROOT"' EXIT

INSTALL="$REPO_ROOT/scripts/install.sh"

printf '\n--- install: muse global ---\n'
MUSE_GLOBAL="$TMP_ROOT/muse-global"
bash "$INSTALL" --muse --global --config-dir "$MUSE_GLOBAL" --force >/dev/null 2>&1 \
  && pass "--muse --global exits 0" \
  || fail "--muse --global exits 0"

SKILL="$MUSE_GLOBAL/skills/autoresearch/SKILL.md"
[[ -f "$SKILL" ]] \
  && pass "global install writes skills/autoresearch/SKILL.md" \
  || fail "global install writes skills/autoresearch/SKILL.md"

if [[ -f "$SKILL" ]]; then
  grep -q 'request_user_input' "$SKILL" \
    && pass "muse skill uses request_user_input" \
    || fail "muse skill uses request_user_input"
  ! grep -q 'AskUserQuestion' "$SKILL" \
    && pass "muse skill has no AskUserQuestion" \
    || fail "muse skill has no AskUserQuestion"
  grep -q 'autoresearch plan' "$SKILL" \
    && pass "muse skill uses keyword invocations" \
    || fail "muse skill uses keyword invocations"
  ! grep -q '/autoresearch:' "$SKILL" \
    && pass "muse skill has no slash-colon invocations" \
    || fail "muse skill has no slash-colon invocations"
fi

for helper in orchestrate.sh score-regression.sh; do
  installed="$MUSE_GLOBAL/skills/autoresearch/scripts/$helper"
  [[ -x "$installed" ]] && cmp -s "$REPO_ROOT/scripts/$helper" "$installed" \
    && pass "global install bundles canonical $helper" \
    || fail "global install bundles canonical $helper"
done

[[ -d "$MUSE_GLOBAL/commands" || -d "$MUSE_GLOBAL/hooks" ]] \
  && fail "muse install writes no commands or hooks surface" \
  || pass "muse install writes no commands or hooks surface"

printf '\n--- install: muse local ---\n'
MUSE_PROJECT="$TMP_ROOT/muse-project"
mkdir -p "$MUSE_PROJECT"
(cd "$MUSE_PROJECT" && bash "$INSTALL" --muse --local --force >/dev/null 2>&1) \
  && pass "--muse --local exits 0" \
  || fail "--muse --local exits 0"
[[ -f "$MUSE_PROJECT/.agents/skills/autoresearch/SKILL.md" ]] \
  && pass "local install writes .agents/skills/autoresearch/SKILL.md" \
  || fail "local install writes .agents/skills/autoresearch/SKILL.md"

printf '\n--- install: muse local next to a Codex npx copy ---\n'
SHARED_PROJECT="$TMP_ROOT/shared-project"
mkdir -p "$SHARED_PROJECT/.agents/skills"
cp -R "$REPO_ROOT/.agents/skills/autoresearch" "$SHARED_PROJECT/.agents/skills/"
! (cd "$SHARED_PROJECT" && bash "$INSTALL" --muse --local </dev/null >/dev/null 2>&1) \
  && pass "--muse --local refuses to replace a Codex copy" \
  || fail "--muse --local refuses to replace a Codex copy"
grep -qF '$autoresearch' "$SHARED_PROJECT/.agents/skills/autoresearch/SKILL.md" \
  && pass "Codex copy is left intact" \
  || fail "Codex copy is left intact"
(cd "$SHARED_PROJECT" && bash "$INSTALL" --muse --local --force >/dev/null 2>&1) \
  && ! grep -qF '$autoresearch' "$SHARED_PROJECT/.agents/skills/autoresearch/SKILL.md" \
  && pass "--force replaces the Codex copy" \
  || fail "--force replaces the Codex copy"

printf '\n--- install: MUSE_CONFIG_DIR override ---\n'
MUSE_ENVDIR="$TMP_ROOT/muse-envdir"
MUSE_CONFIG_DIR="$MUSE_ENVDIR" bash "$INSTALL" --muse --global --force >/dev/null 2>&1 \
  && [[ -f "$MUSE_ENVDIR/skills/autoresearch/SKILL.md" ]] \
  && pass "MUSE_CONFIG_DIR overrides the global root" \
  || fail "MUSE_CONFIG_DIR overrides the global root"

printf '\n--- install: tool exclusivity and neighbors ---\n'
! bash "$INSTALL" --muse --codex --global --config-dir "$TMP_ROOT/conflict" >/dev/null 2>&1 \
  && pass "--muse --codex is refused" \
  || fail "--muse --codex is refused"

CODEX_GLOBAL="$TMP_ROOT/codex-global"
bash "$INSTALL" --codex --global --config-dir "$CODEX_GLOBAL" --force >/dev/null 2>&1 \
  && [[ -f "$CODEX_GLOBAL/skills/autoresearch/SKILL.md" ]] \
  && pass "--codex --global still installs" \
  || fail "--codex --global still installs"

printf '\n--- install: muse validator (when muse CLI is present) ---\n'
if command -v muse >/dev/null 2>&1; then
  muse skills validate "$MUSE_GLOBAL/skills/autoresearch" >/dev/null 2>&1 \
    && pass "muse skills validate accepts the installed skill" \
    || fail "muse skills validate accepts the installed skill"
else
  pass "muse CLI absent; validator check skipped"
fi

printf '\n=== Results: %d/%d passed ===' "$PASS" "$TOTAL"
if [[ "$FAIL" -gt 0 ]]; then printf ' (%d FAILED)\n' "$FAIL"; exit 1; else printf ' (all passed)\n'; exit 0; fi
