#!/usr/bin/env bash
# Test harness for autoresearch:regression — score-regression.sh (verdict + rubric),
# the regression.md spec, mirror parity, and manifest count.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

SCORE_SH="$REPO_ROOT/scripts/score-regression.sh"
FIX="$REPO_ROOT/tests/fixtures/regression"
SPEC="$REPO_ROOT/claude-plugin/commands/autoresearch/regression.md"
RUBRIC_TARGET="${REG_RUBRIC_TARGET:-32}"

PASS=0; FAIL=0; TOTAL=0
pass() { printf '  PASS: %s\n' "$1"; PASS=$((PASS + 1)); TOTAL=$((TOTAL + 1)); }
fail() { printf '  FAIL: %s\n' "$1"; FAIL=$((FAIL + 1)); TOTAL=$((TOTAL + 1)); }

assert_eq()       { [[ "$1" == "$2" ]] && pass "$3" || fail "$3 (expected '$1', got '$2')"; }
assert_ge()       { [[ "$1" -ge "$2" ]] && pass "$3" || fail "$3 ($1 < $2)"; }
assert_contains() { echo "$1" | grep -q "$2" && pass "$3" || fail "$3 (missing '$2')"; }

V_OUT=""; V_CODE=0; V_VERDICT=""; V_SCORE=""
run_verdict() {
  V_OUT=$(bash "$SCORE_SH" verdict "$FIX/$1" 2>/dev/null); V_CODE=$?
  V_VERDICT=$(echo "$V_OUT" | sed -n 's/^VERDICT: //p')
  V_SCORE=$(echo "$V_OUT" | sed -n 's/^score=//p')
}

# ============================================================================
printf '\n--- verdict: classification invariants (green->red only) ---\n'
# ============================================================================

run_verdict green-to-red.tsv
assert_eq "UNSTABLE" "$V_VERDICT" "green->red HARD regression => UNSTABLE"
assert_eq 1 "$V_CODE" "green->red exit 1"
assert_contains "$V_OUT" "blocking=functional" "green->red blocks on functional dim"

run_verdict red-to-red.tsv
assert_eq "STABLE" "$V_VERDICT" "red->red (pre-existing) excluded => STABLE"
assert_eq 0 "$V_CODE" "red->red exit 0"

run_verdict absent-to-red.tsv
assert_eq "STABLE" "$V_VERDICT" "absent->red (new-coverage) ungated => STABLE"
assert_eq 0 "$V_CODE" "absent->red exit 0"

run_verdict flake-to-red.tsv
assert_eq "STABLE" "$V_VERDICT" "flake->red (flaky) routed to SCORE => STABLE"
assert_eq 0 "$V_CODE" "flake->red exit 0"

# ============================================================================
printf '\n--- verdict: SCORE tier (noise-tolerant, weighted) ---\n'
# ============================================================================

run_verdict perf-in-band.tsv
assert_eq "STABLE" "$V_VERDICT" "perf within noise band => STABLE"

run_verdict perf-over-band.tsv
assert_eq "UNSTABLE" "$V_VERDICT" "perf over band drops score => UNSTABLE"
assert_eq "88.00" "$V_SCORE" "perf-over-band weighted score = 88.00"
assert_eq 1 "$V_CODE" "perf-over-band exit 1"

run_verdict score-boundary-95.tsv
assert_eq "STABLE" "$V_VERDICT" "score 95 (== threshold) => STABLE"
assert_eq "95.00" "$V_SCORE" "boundary score = 95.00"

run_verdict score-boundary-94.tsv
assert_eq "UNSTABLE" "$V_VERDICT" "score 94 (< threshold) => UNSTABLE"
assert_eq "94.00" "$V_SCORE" "boundary score = 94.00"

# ============================================================================
printf '\n--- verdict: dimension availability self-detection ---\n'
# ============================================================================

run_verdict unavailable-dim.tsv
assert_eq "STABLE" "$V_VERDICT" "unavailable dims => STABLE on present dims"
assert_contains "$V_OUT" "dims_unavailable=.*resource" "resource listed UNAVAILABLE"
assert_contains "$V_OUT" "dims_unavailable=.*visual-ui" "visual-ui listed UNAVAILABLE"

# ============================================================================
printf '\n--- verdict: empty / no-dims-ran + ERROR paths (no false-green ship) ---\n'
# ============================================================================

run_verdict empty.tsv
assert_eq "BASELINE_UNAVAILABLE" "$V_VERDICT" "empty/header-only TSV (no dims ran) => BASELINE_UNAVAILABLE, not STABLE"
assert_eq 2 "$V_CODE" "empty TSV exit 2 (non-ship)"
assert_contains "$V_OUT" "blocking=no-dims-ran" "empty TSV blocks on no-dims-ran"

MISS_OUT=$(bash "$SCORE_SH" verdict "$FIX/does-not-exist.tsv" 2>/dev/null); MISS_CODE=$?
assert_contains "$MISS_OUT" "VERDICT: ERROR" "missing TSV => VERDICT: ERROR"
assert_eq 2 "$MISS_CODE" "missing TSV exit 2"

# ============================================================================
printf '\n--- verdict: determinism ---\n'
# ============================================================================

OUT1=$(bash "$SCORE_SH" verdict "$FIX/perf-over-band.tsv" 2>/dev/null)
OUT2=$(bash "$SCORE_SH" verdict "$FIX/perf-over-band.tsv" 2>/dev/null)
assert_eq "$OUT1" "$OUT2" "verdict deterministic across runs"

# ============================================================================
printf '\n--- rubric: spec quality gate ---\n'
# ============================================================================

RSCORE=$(bash "$SCORE_SH" rubric "$SPEC" | sed -n 's/^SCORE: //p')
assert_ge "${RSCORE:-0}" "$RUBRIC_TARGET" "rubric score >= $RUBRIC_TARGET (got ${RSCORE:-0})"

# ============================================================================
printf '\n--- spec: required invariants/sections present ---\n'
# ============================================================================

spec_has() { grep -qiE -- "$1" "$SPEC" && pass "$2" || fail "$2 (spec missing /$1/)"; }
spec_has "green.{0,3}red transition only|green.{0,3}red"          "spec: green->red invariant"
spec_has "classification"                                         "spec: classification phase"
spec_has "baseline-unavailable|BASELINE_UNAVAILABLE"              "spec: baseline-unavailable state"
spec_has "git worktree add --detach"                              "spec: worktree --detach"
spec_has "submodule update --init"                                "spec: submodule init"
spec_has "forward-only"                                           "spec: migration forward-only default"
spec_has "Mann.?Whitney"                                          "spec: perf Mann-Whitney"
spec_has "independent.process"                                    "spec: perf independent-process samples"
spec_has "maxDiffPixelRatio|pixel.ratio"                          "spec: visual pixel-ratio default"
spec_has "--max-runs"                                             "spec: --max-runs ceiling"
spec_has "fix-cycles|3 cycles"                                    "spec: fix-cycle bound"
spec_has "verdict.*STABLE|STABLE.*UNSTABLE"                       "spec: verdict field"
spec_has "COMPLETE.*CONVERGED.*SATURATED|family enum"             "spec: handoff family status enum"

# ============================================================================
printf '\n--- distribution: mirror parity (5 surfaces byte-identical) ---\n'
# ============================================================================

MIRRORS=(
  "$REPO_ROOT/.claude/commands/autoresearch/regression.md"
  "$REPO_ROOT/.agents/skills/autoresearch/regression.md"
  "$REPO_ROOT/plugins/autoresearch/skills/autoresearch/regression.md"
  "$REPO_ROOT/.opencode/commands/autoresearch_regression.md"
)
for m in "${MIRRORS[@]}"; do
  if [[ -f "$m" ]] && diff -q "$SPEC" "$m" >/dev/null 2>&1; then
    pass "mirror parity: ${m#$REPO_ROOT/}"
  else
    fail "mirror parity: ${m#$REPO_ROOT/} (missing or diverged)"
  fi
done

# ============================================================================
printf '\n--- distribution: manifest command count = 14 + regression listed ---\n'
# ============================================================================

for mf in "$REPO_ROOT/.claude-plugin/marketplace.json" "$REPO_ROOT/claude-plugin/.claude-plugin/plugin.json" "$REPO_ROOT/plugins/autoresearch/.codex-plugin/plugin.json"; do
  name="${mf#$REPO_ROOT/}"
  grep -q "14 commands" "$mf" && pass "manifest count 14: $name" || fail "manifest count 14: $name"
  grep -q "regression" "$mf"  && pass "manifest lists regression: $name" || fail "manifest lists regression: $name"
done

# ============================================================================
printf '\n=== Results: %d/%d passed ===' "$PASS" "$TOTAL"
if [[ "$FAIL" -gt 0 ]]; then printf ' (%d FAILED)\n' "$FAIL"; exit 1; else printf ' (all passed)\n'; exit 0; fi
