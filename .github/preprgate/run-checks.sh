#!/usr/bin/env bash
# preprgate deterministic-check runner.
#   run-checks.sh          -> detect stack, run typecheck+lint+build+tests+secret grep; non-zero on any failure
#   run-checks.sh --seal   -> re-run the checks; on full pass, write .preprgate/gate-status.json PASS for HEAD
#
# This covers the mechanical phases only. The agent-driven phases (spec, review,
# regression, security reasoning, react health, verification) are done by the
# /preprgate skill; --seal is the final step it runs after ALL phases are green.
set -uo pipefail

root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$root"
# shellcheck source=preprgate-lib.sh
. "$(dirname "$0")/preprgate-lib.sh"

# Coverage floors default to 80/70 and a runner (e.g. CI) can override them via the
# PREPRGATE_COV_LINE_FLOOR / PREPRGATE_COV_BRANCH_FLOOR env vars — see run_tests below.

# Arg guard: the ONLY accepted argument is --seal. An unknown flag — a probe like
# `--help`, or a hand-rolled option an agent invents — must NOT silently fall through
# and run a full SECOND suite (that collided two Vitest/Mongo runs on fixed ports).
# Print usage and exit WITHOUT running anything.
case "${1:-}" in
  ''|--seal) : ;;
  -h|--help)
    echo "usage: run-checks.sh [--seal]"
    echo "  (no arg)  run typecheck+lint+build+tests+secret grep; non-zero on any failure"
    echo "  --seal    re-run; on full pass, write .preprgate/gate-status.json PASS for HEAD"
    exit 0 ;;
  *)
    echo "run-checks.sh: unknown argument '$1' (only --seal is accepted)" >&2
    echo "usage: run-checks.sh [--seal]" >&2
    exit 2 ;;
esac

# All linked worktrees share this fail-fast lock through their Git common dir.
preprgate_acquire_mechanical_lock || exit $?

fails=0
# Every check runs through preprgate_bounded (CI=1, stdin closed, hard timeout) so a
# watch-mode / interactive runner can never hang the gate — a stall FAILS the phase
# instead of wedging for hours. rc 124 = timed out (distinct message).
run() {
  echo "→ $*"
  local rc
  PREPRGATE_PROGRESS_LABEL="$*" preprgate_bounded "$*" 3>&1; rc=$?   # capture BEFORE any test — `if ! cmd` would mask 124
  if [ "$rc" -ne 0 ]; then
    if [ "$rc" -eq 124 ]; then echo "  ✗ TIMEOUT: $*"; exit 124; else echo "  ✗ FAILED: $*"; fi
    fails=$((fails+1)); return 1
  fi
  echo "  ✓ ok"; return 0
}
have() { command -v "$1" >/dev/null 2>&1; }
# Use the exact prepared base when context exists; independently re-resolving a
# default branch could run checks against a different diff than the final seal.
context_manifest="$root/.preprgate/context/manifest.json"
if [ -f "$context_manifest" ]; then
  node "$(dirname "$0")/context-proof.mjs" "$root" "$(cd "$(dirname "$0")/.." && pwd)" >/dev/null || exit 1
  base="$(node -e 'const fs=require("fs"); const m=JSON.parse(fs.readFileSync(process.argv[1],"utf8")); if(!m.base?.commit) process.exit(1); process.stdout.write(m.base.commit)' "$context_manifest")" || exit 1
else
  if ! preprgate_resolve_base; then exit 2; fi
  base="$PREPRGATE_BASE"
fi

# Sealing binds every phase to the prepared repository/base/head/diff/rules
# identity. Reject stale or substituted context before paying for another suite.
if [ "${1:-}" = "--seal" ]; then
  node "$(dirname "$0")/context-proof.mjs" "$root" "$(cd "$(dirname "$0")/.." && pwd)" >/dev/null || exit 1
fi

lint_counts() {
  node -e '
    const fs = require("fs");
    const text = fs.readFileSync(process.argv[1], "utf8");
    const matches = [...text.matchAll(/([0-9]+) problems \(([0-9]+) errors, ([0-9]+) warnings\)/g)];
    if (!matches.length) process.exit(1);
    const [, , errors, warnings] = matches[matches.length - 1];
    process.stdout.write(`${errors} ${warnings}`);
  ' "$1"
}

run_lint_gate() {
  local tmp base_dir head_dir base_log head_log base_status head_status
  local base_counts head_counts base_errors base_warnings head_errors head_warnings
  tmp="$(mktemp -d "${TMPDIR:-/tmp}/preprgate-lint.XXXXXX")" || return 1
  base_dir="$tmp/base"
  head_dir="$tmp/head"
  base_log="$tmp/base.log"
  head_log="$tmp/head.log"
  mkdir -p "$base_dir" "$head_dir"

  if ! git archive -o "$tmp/base.tar" "$base" \
    || ! git archive -o "$tmp/head.tar" HEAD \
    || ! tar -xf "$tmp/base.tar" -C "$base_dir" \
    || ! tar -xf "$tmp/head.tar" -C "$head_dir"; then
    rm -rf "$tmp"
    return 1
  fi
  [ -d "$root/node_modules" ] && ln -s "$root/node_modules" "$base_dir/node_modules"
  [ -d "$root/node_modules" ] && ln -s "$root/node_modules" "$head_dir/node_modules"

  # Bounded: a repo whose `lint` script watches or spawns a server would otherwise
  # hang the gate here exactly like the old unbounded test run did.
  echo "→ clean-snapshot lint (HEAD)"
  PREPRGATE_PROGRESS_LABEL="baseline-aware lint (HEAD)" PREPRGATE_PROGRESS_FILE="$head_log" \
    preprgate_bounded "cd \"$head_dir\" && \"$pm\" run lint" 3>&1 > "$head_log" 2>&1
  head_status=$?
  if [ "$head_status" -eq 124 ]; then rm -rf "$tmp"; return 124; fi
  if [ "$head_status" -eq 0 ]; then
    echo "  ✓ repository lint clean"
    rm -rf "$tmp"
    return 0
  fi

  echo "→ clean-snapshot lint (base ${base:0:12})"
  PREPRGATE_PROGRESS_LABEL="baseline-aware lint (base)" PREPRGATE_PROGRESS_FILE="$base_log" \
    preprgate_bounded "cd \"$base_dir\" && \"$pm\" run lint" 3>&1 > "$base_log" 2>&1
  base_status=$?
  if [ "$base_status" -eq 124 ]; then rm -rf "$tmp"; return 124; fi
  if [ "$base_status" -eq 0 ]; then
    tail -n 20 "$head_log"
    echo "  ✗ HEAD lint failed while base lint passed"
    rm -rf "$tmp"
    return 1
  fi

  base_counts="$(lint_counts "$base_log")" || base_counts=""
  head_counts="$(lint_counts "$head_log")" || head_counts=""
  if [ -z "$base_counts" ] || [ -z "$head_counts" ]; then
    tail -n 20 "$base_log"
    tail -n 20 "$head_log"
    echo "  ✗ unable to compare lint debt"
    rm -rf "$tmp"
    return 1
  fi
  read -r base_errors base_warnings <<< "$base_counts"
  read -r head_errors head_warnings <<< "$head_counts"
  echo "  base: $base_errors errors, $base_warnings warnings"
  echo "  HEAD: $head_errors errors, $head_warnings warnings"
  if [ "$head_errors" -le "$base_errors" ] && [ "$head_warnings" -le "$base_warnings" ]; then
    echo "  ✓ no new lint debt; changed files are clean"
    rm -rf "$tmp"
    return 0
  fi

  echo "  ✗ lint debt increased"
  rm -rf "$tmp"
  return 1
}

echo "== preprgate deterministic checks =="

# Run the suite, then guard against a green-but-empty run (a runner that exits 0
# on "no tests found" must not seal — the coverage floor would be vacuous) and
# enforce the coverage floor when a summary is actually produced (fail-closed only
# when measurable; we never fabricate coverage tooling the repo doesn't have).
run_tests() {
  local out rc test_key test_cmd selector lane command_key selection_source deferred attempt_id
  test_cmd="$pm test"
  selection_source="repository-ci"
  deferred=true
  lane="$(cat "$root/.preprgate/context/lane.txt" 2>/dev/null || true)"
  if [ "${PREPRGATE_CI_FULL:-0}" = 1 ]; then
    selection_source="exact-head-ci"
    deferred=false
  else
    selector="$(node -e '
      try { const p=require("./package.json"); const c=p.preprgate&&p.preprgate.affectedTestCommand; if(typeof c==="string") process.stdout.write(c.trim()); }
      catch {}
    ' 2>/dev/null || true)"
    if [ -n "$selector" ]; then
      test_cmd="$selector"
      selection_source="package.json#preprgate.affectedTestCommand"
      deferred=false
    fi
  fi
  mkdir -p "$root/.preprgate/context"
  TEST_CMD="$test_cmd" TEST_SOURCE="$selection_source" TEST_LANE="${lane%%:*}" TEST_DEFERRED="$deferred" node -e '
    const fs=require("fs"), e=process["env"];
    fs.writeFileSync(".preprgate/context/test-selection.json", JSON.stringify({
      schema_version:1, lane:e.TEST_LANE||"full", command:e.TEST_CMD,
      source:e.TEST_SOURCE, fallback:false, deferred:e.TEST_DEFERRED==="true"
    }, null, 2)+"\n");
  '
  if [ "$deferred" = true ]; then
    echo "→ full test suite deferred to repository CI (no repository-declared affected command)"
    return 0
  fi
  # Cache the whole suite+coverage verdict on the HEAD tree hash, like the build cache:
  # a re-seal (Phase 12 re-runs the suite) or a same-HEAD bounce replays an identical
  # tree instead of re-running. Any committed change — source, FIXTURES, config — busts
  # the key, so a hit never replays a stale green: a test asserting against
  # fixtures/expected.json is covered (a JS/TS-only file glob was not — it let a
  # fixture-only edit cache-hit a regression). $base + the coverage floors join the key:
  # patch-coverage + the base-vs-HEAD checks below depend on $base, so a moved base
  # Any base-identity change must MISS; a tightened floor must re-check, not reuse.
  # a looser pass. Fail-open: empty key (no tree, e.g. no commits yet) always re-runs;
  # only a full PASS is cached (every failure path below returns before the cache_put).
  test_key="$(git rev-parse 'HEAD^{tree}' 2>/dev/null)"
  command_key="$(printf '%s' "$test_cmd" | git hash-object --stdin 2>/dev/null || true)"
  attempt_id="$(node -e 'try{const a=require("./.preprgate/attempt.json");if(typeof a.id==="string")process.stdout.write(a.id)}catch{}' 2>/dev/null || true)"
  [ -n "$attempt_id" ] || attempt_id="direct-$$"
  [ -n "$test_key" ] && test_key="${attempt_id}:${base}:${PREPRGATE_COV_LINE_FLOOR:-80}:${PREPRGATE_COV_BRANCH_FLOOR:-70}:${command_key}:${test_key}"
  if preprgate_cache_hit test "$test_key"; then
    echo "→ $test_cmd"; echo "  ✓ cached PASS (tree + selected command unchanged)"; return
  fi
  out="$(mktemp "${TMPDIR:-/tmp}/preprgate-test.XXXXXX")" || { run "$test_cmd"; return; }
  echo "→ $test_cmd ($selection_source)"
  # Bounded: CI=1 + stdin closed + hard timeout so a watch-mode test runner
  # (react-scripts/vitest/jest) can never hang Phase 3 — it dies at the cap and fails.
  PREPRGATE_PROGRESS_LABEL="$test_cmd" PREPRGATE_PROGRESS_FILE="$out" \
    preprgate_bounded "$test_cmd" 3>&1 > "$out" 2>&1; rc=$?
  tail -n 40 "$out"
  if [ "$rc" -eq 124 ]; then echo "  ✗ TIMEOUT: $test_cmd (watch-mode/hang? runner must exit non-interactively)"; rm -f "$out"; exit 124; fi
  if [ "$rc" -ne 0 ]; then echo "  ✗ FAILED: $test_cmd"; fails=$((fails+1)); rm -f "$out"; return; fi
  # Fail a "green" run that ran ZERO tests — coverage floor would be vacuous. The
  # negative regex covers the common runners (jest "Tests: 0 total", vitest "No test
  # files found", mocha "0 passing", pytest "no tests ran"); the trailing guard means
  # any positive test count present ("42 passed") overrides it, so a real run with an
  # unusual phrasing is never false-blocked.
  if grep -qiE 'no tests? (found|ran|match|collected)|no test files? (found|match)|ran 0 tests|(^|[^0-9])0 (tests?|passing|passed|specs?|total|collected)|matched 0 test|passwithnotests' "$out" \
     && ! grep -qiE '[1-9][0-9]* (tests?|passing|passed|specs?)' "$out"; then
    echo "  ✗ FAILED: '$test_cmd' passed but ran 0 tests — a vacuous green cannot seal"; fails=$((fails+1)); rm -f "$out"; return
  fi
  if [ -f coverage/coverage-summary.json ]; then
    local cov line_floor branch_floor
    # A repo whose baseline is below 80/70 would otherwise only ever seal by NOT
    # producing a coverage summary — the floor silently skips, which reads as a pass
    # it never earned. Let a repo declare the floor it actually holds so the check
    # runs for real and blocks a backslide. Defaults unchanged.
    line_floor="${PREPRGATE_COV_LINE_FLOOR:-80}"
    branch_floor="${PREPRGATE_COV_BRANCH_FLOOR:-70}"
    cov="$(PG_L="$line_floor" PG_B="$branch_floor" node -e '
      try { const t=require("./coverage/coverage-summary.json").total;
        const l=t.lines.pct, b=t.branches.pct;
        process.stdout.write((l<+process.env.PG_L||b<+process.env.PG_B?"LOW ":"OK ")+l+" "+b);
      } catch { process.stdout.write("NA"); }' 2>/dev/null || echo NA)"
    case "$cov" in
      LOW*) echo "  ✗ FAILED: coverage below floor (line/branch ${cov#LOW }, need ≥${line_floor}/≥${branch_floor})"; fails=$((fails+1)); rm -f "$out"; return ;;
      OK*)  echo "  ✓ coverage ${cov#OK } (≥${line_floor} line / ≥${branch_floor} branch)" ;;
      *)    echo "  · coverage summary unreadable — agent must verify the floor manually" ;;
    esac
    # F1 — patch coverage. The global floor above hides a brand-new 0%-covered file
    # behind a high repo average. Also require each CHANGED source file's own line
    # coverage to clear the floor, so untested new code can't ride in on the average.
    # ponytail: per-file pct from the summary, not true per-added-line intersection —
    # catches the new-file / tanked-file case; a few uncovered new lines in a big
    # already-covered file stay under this radar (diminishing-returns tail).
    local changed
    changed="$(git diff --name-only "$base"..HEAD -- '*.js' '*.jsx' '*.mjs' '*.cjs' '*.ts' '*.tsx' 2>/dev/null)"
    if [ -n "$changed" ]; then
      local patchcov
      patchcov="$(changed="$changed" node -e '
        const fs=require("fs");
        let s; try{ s=require("./coverage/coverage-summary.json"); }catch{ process.stdout.write("NA"); process.exit(0); }
        const changed=(process.env.changed||"").split("\n").filter(Boolean);
        const bad=[];
        for(const rel of changed){
          // summary keys are absolute; match the changed file by path suffix.
          const k=Object.keys(s).find(k=>k!=="total"&&(k.endsWith("/"+rel)||k.endsWith(rel)));
          if(!k) continue;                       // not instrumented (config/types) — skip
          const pct=s[k].lines&&s[k].lines.pct;
          if(typeof pct==="number"&&pct<80) bad.push(rel+" "+pct+"%");
        }
        process.stdout.write(bad.length?"LOW "+bad.join(", "):"OK");
      ' 2>/dev/null || echo NA)"
      case "$patchcov" in
        LOW*) echo "  ✗ FAILED: changed file(s) below the 80% line floor: ${patchcov#LOW } — a new/edited file cannot ride in on the repo average"; fails=$((fails+1)); rm -f "$out"; return ;;
        OK)   echo "  ✓ patch coverage: every instrumented changed file ≥80% line" ;;
        *)    : ;;  # NA: no summary usable per-file — global check + manual note already cover it
      esac
    fi
  else
    echo "  · no coverage/coverage-summary.json — agent must verify the ≥80/≥70 floor manually"
  fi
  echo "  ✓ ok"; rm -f "$out"; preprgate_cache_put test "$test_key"
}

# Node / TS
if [ -f package.json ]; then
  pm=npm; [ -f pnpm-lock.yaml ] && pm=pnpm; [ -f yarn.lock ] && pm=yarn; [ -f bun.lockb ] && pm=bun
  if [ -f tsconfig.json ]; then
    # Cache the typecheck (deterministic; crisp inputs = tsconfig + TS sources).
    # A fix that only touched docs/tests leaves this key unchanged → skip the
    # re-run. Fail-open: any miss or doubt re-runs; only a PASS is ever cached.
    # ponytail: word-splitting the file list would drop any path containing a space
    # from the hash — that file's edits then wouldn't change the key, and a stale
    # PASS could be reused (fail-OPEN on a correctness gate). If any TS path has a
    # space, skip caching entirely (empty key → always re-run tsc). Rare, cheap.
    if git ls-files '*.ts' '*.tsx' '*.mts' '*.cts' 2>/dev/null | grep -q ' '; then
      tsc_key=""
    else
      tsc_key="$(preprgate_hash_paths tsconfig.json $(git ls-files '*.ts' '*.tsx' '*.mts' '*.cts' 2>/dev/null))"
    fi
    if preprgate_cache_hit typecheck "$tsc_key"; then
      echo "→ tsc --noEmit"; echo "  ✓ cached PASS (typecheck inputs unchanged)"
    else
      if run "npx --no-install tsc --noEmit || npx tsc --noEmit"; then preprgate_cache_put typecheck "$tsc_key"; fi
    fi
  fi
  if grep -q '"lint"' package.json; then
    echo "→ baseline-aware lint"
    # Cache the (heavy: git-archive base+head + full lint ×2) gate on the HEAD tree hash,
    # like build/test: any committed change — source or eslint/tsconfig — busts it, so a
    # hit only replays an identical tree, never a stale pass. Binds $base: the blocker is
    # the base-vs-HEAD debt delta, so a moved base must MISS. Fail-open: empty key (no
    # tree) re-runs; only a clean pass caches.
    lint_key="$(git rev-parse 'HEAD^{tree}' 2>/dev/null)"
    [ -n "$lint_key" ] && lint_key="${base}:${lint_key}"
    if preprgate_cache_hit lint "$lint_key"; then
      echo "  ✓ cached PASS (lint inputs unchanged)"
    else
      run_lint_gate; lint_status=$?
      if [ "$lint_status" -eq 0 ]; then echo "  ✓ ok"; preprgate_cache_put lint "$lint_key"
      elif [ "$lint_status" -eq 124 ]; then echo "  ✗ TIMEOUT: baseline-aware lint"; exit 124
      else echo "  ✗ FAILED: baseline-aware lint"; fails=$((fails+1)); fi
    fi
  else
    have npx && run "npx --no-install eslint . || true"
  fi
  grep -q '"test"' package.json && run_tests
  if grep -q '"build"' package.json; then
    if [ "${PREPRGATE_CI_FULL:-0}" = 1 ]; then
      build_key="$(git rev-parse 'HEAD^{tree}' 2>/dev/null)"
      if preprgate_cache_hit build "$build_key"; then
        echo "→ $pm run build"; echo "  ✓ cached PASS (tree unchanged)"
      elif run "$pm run build"; then preprgate_cache_put build "$build_key"; fi
    else
      echo "→ production build deferred to repository CI"
    fi
  fi
fi
# Python
if [ -f pyproject.toml ] || [ -f requirements.txt ] || ls ./*.py >/dev/null 2>&1; then
  have ruff && run "ruff check ." || { have flake8 && run "flake8 ."; }
  if [ "${PREPRGATE_CI_FULL:-0}" = 1 ]; then
    if have pytest; then run "pytest -q"; else echo "  ✗ FAILED: pytest is required for the exact-head CI suite"; fails=$((fails+1)); fi
  else echo "→ Python full suite deferred to repository CI"; fi
fi
# Go
if [ -f go.mod ]; then
  run "go vet ./..."; run "go build ./..."
  if [ "${PREPRGATE_CI_FULL:-0}" = 1 ]; then run "go test ./... -cover"; else echo "→ Go full suite deferred to repository CI"; fi
fi
# Rust
if [ -f Cargo.toml ]; then
  run "cargo check"
  if [ "${PREPRGATE_CI_FULL:-0}" = 1 ]; then run "cargo test"; else echo "→ Rust full suite deferred to repository CI"; fi
fi
# Flutter
if [ -f pubspec.yaml ]; then
  if have flutter; then
    run "flutter analyze"
    if [ "${PREPRGATE_CI_FULL:-0}" = 1 ]; then run "flutter test"; else echo "→ Flutter full suite deferred to repository CI"; fi
  elif [ "${PREPRGATE_CI_FULL:-0}" = 1 ]; then
    echo "  ✗ FAILED: flutter is required for the exact-head CI suite"; fails=$((fails+1))
  else echo "→ Flutter full suite deferred to repository CI"; fi
fi

# Secret grep over the committed diff vs merge-base (redacted; presence only).
secret_re='(AKIA[0-9A-Z]{16})|(ghp_[A-Za-z0-9]{36})|(sk_(live|test)_[A-Za-z0-9]{24,})|(-----BEGIN [A-Z ]*PRIVATE KEY-----)|(eyJ[A-Za-z0-9_-]+\.eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+)'
# Exclude test/fixture *files* by name (not by line content — a real key on a
# line that merely says "example" must still block). NUL-delimited end to end so
# paths with spaces are safe and the file list can't overflow ARG_MAX on a huge
# diff (xargs -0 batches the git invocations).
secret_hit=0
if git diff -z --name-only "$base"..HEAD 2>/dev/null \
     | { grep -zEiv '(test|spec|example|mock|fixture|sample)|\.md$' || true; } \
     | xargs -0 -r git diff "$base"..HEAD -- 2>/dev/null \
     | grep -E '^\+' | grep -Eq "$secret_re"; then
  secret_hit=1
fi
if [ "$secret_hit" -eq 1 ]; then
  echo "  ✗ FAILED: possible secret in committed diff (value redacted) — rotate & remove"; fails=$((fails+1))
else echo "→ secret grep"; echo "  ✓ ok"; fi

# --- Hermeticity / CI-parity probe (F2) -----------------------------------------
# The gate runs in the local (possibly dirty) env; CI runs from a clean checkout.
# A PASS here that dies in CI defeats the gate. HARD: a lockfile present but not
# committed makes CI `npm ci` fail outright. INFO: lockfile likely out of sync,
# env vars a test references but no committed example declares, and untracked files
# under test dirs the suite might read. INFO goes to the PR body, not a block.
echo "→ hermeticity (CI-parity) probe"
for lf in package-lock.json pnpm-lock.yaml yarn.lock bun.lockb go.sum Cargo.lock poetry.lock; do
  [ -f "$lf" ] || continue
  if ! git ls-files --error-unmatch "$lf" >/dev/null 2>&1; then
    echo "  ✗ FAILED: $lf exists but is not committed — a clean CI checkout cannot reproduce the dep tree"; fails=$((fails+1))
  elif git diff --name-only "$base"..HEAD 2>/dev/null | grep -qx 'package.json' \
       && ! git diff --name-only "$base"..HEAD 2>/dev/null | grep -qx "$lf"; then
    echo "  · INFO: package.json changed in this diff but $lf did not — verify the lockfile is in sync (CI runs a frozen install)"
  fi
done
# env refs used in committed source/tests but absent from a committed example file.
if [ -f package.json ] || ls ./*.py >/dev/null 2>&1; then
  envkeys="$(git grep -hoE 'process\.env\.[A-Z_][A-Z0-9_]+|os\.environ(\.get\()?\[?["'"'"'][A-Z_][A-Z0-9_]+' HEAD -- 2>/dev/null \
             | grep -oE '[A-Z_][A-Z0-9_]{2,}' | sort -u || true)"
  declared="$( { for e in .env.example .env.sample .env.template env.example; do [ -f "$e" ] && cat "$e"; done; } 2>/dev/null \
             | grep -oE '^[A-Z_][A-Z0-9_]+' | sort -u || true)"
  if [ -n "$envkeys" ]; then
    missing="$(comm -23 <(printf '%s\n' "$envkeys") <(printf '%s\n' "$declared") 2>/dev/null | grep -vE '^(NODE_ENV|CI|PATH|HOME|PWD|TZ|PORT)$' || true)"
    [ -n "$missing" ] && echo "  · INFO: env vars referenced in code but not in any committed .env.example: $(printf '%s' "$missing" | paste -sd, -) — CI must provide them or tests may fail"
  fi
fi
# untracked files under test dirs the suite might silently depend on.
untracked_tests="$(git ls-files --others --exclude-standard 2>/dev/null | grep -iE '(^|/)(test|tests|spec|__tests__|fixtures?)/' | head -20 || true)"
[ -n "$untracked_tests" ] && echo "  · INFO: untracked files under test dirs (CI won't have them): $(printf '%s' "$untracked_tests" | paste -sd' ' -)"
echo "  ✓ hermeticity probe done"

if [ "${1:-}" = "--seal" ]; then
  if [ "$fails" -eq 0 ]; then
    mkdir -p "$root/.preprgate"
    phase_lock="$root/.preprgate/.phases.lock"
    phase_lock_deadline=$(( $(date +%s) + 5 ))
    until mkdir "$phase_lock" 2>/dev/null; do
      if [ "$(date +%s)" -ge "$phase_lock_deadline" ]; then
        echo "== NOT SEALED: phase ledger lock remained busy; no marker was written =="
        exit 1
      fi
      sleep 0.05
    done
    PREPRGATE_PHASE_LOCK="$phase_lock"
    sha="$(git rev-parse HEAD)"
    # Tree stays in the ledger for diagnostics. External authorization below is
    # bound to the exact prepared commit rather than tree equivalence.
    tree="$(git rev-parse 'HEAD^{tree}' 2>/dev/null || echo)"

    # Phase-evidence gate: refuse to seal unless every HARD phase has a PASS/SKIP
    # verdict recorded for THIS HEAD (see scripts/record-phase.mjs). This is what
    # stops a judgment phase (spec/review/security) being skipped before push.
    # node is already a skill dependency; parse exactly rather than grep loosely.
    ledger="$root/.preprgate/phases.json"
    hardphases="$(dirname "$0")/hard-phases.json"
    contextfile="$root/.preprgate/context/manifest.json"
    missing="$(sha="$sha" tree="$tree" ledger="$ledger" hardphases="$hardphases" contextfile="$contextfile" node -e '
      const fs = require("fs");
      const { createHash } = require("crypto");
      // Single source of truth for the HARD set (shared with record-phase.mjs).
      const REQUIRED = JSON.parse(fs.readFileSync(process.env.hardphases, "utf8")).required;
      const JUDGMENT = new Set(["1", "5", "6", "8", "9"]);
      let j;
      try { j = JSON.parse(fs.readFileSync(process.env.ledger, "utf8")); }
      catch { console.log("NO_LEDGER"); process.exit(0); }
      if (j.sha !== process["env"]["sha"]) { console.log("STALE " + (j.sha||"none").slice(0,12)); process.exit(0); }
      // The exact-SHA check above intentionally runs before the legacy tree
      // diagnostic below; tree equivalence never authorizes external mutation.
      const t = process.env.tree;
      if (j.sha !== process.env.sha && !(t && j.tree === t)) { console.log("STALE " + (j.sha||"none").slice(0,12)); process.exit(0); }
      let manifest;
      try { manifest = JSON.parse(fs.readFileSync(process["env"]["contextfile"], "utf8")); }
      catch { console.log("STALE_CONTEXT"); process.exit(0); }
      const identity = JSON.stringify({
        repository: manifest.repository, base: manifest.base, head: manifest.head,
        diff: manifest.diff, gate_rules: manifest.gate_rules,
      });
      const contextDigest = createHash("sha256").update(identity).digest("hex");
      if (j.context_digest !== contextDigest) { console.log("STALE_CONTEXT"); process.exit(0); }
      const bad = REQUIRED.filter(n => {
        const p = j.phases && j.phases[n];
        return !p || (p.verdict !== "PASS" && p.verdict !== "SKIP");
      });
      if (bad.length) { console.log("MISSING " + bad.join(",")); process.exit(0); }
      // A judgment PASS or SKIP must still have its exact evidence file
      // NOW (not just at record time — the artifact could have been deleted since).
      const noev = REQUIRED.filter(n => {
        const p = j.phases[n];
        if (!JUDGMENT.has(n) || !["PASS", "SKIP"].includes(p.verdict)) return false;
        try {
          const value = fs.readFileSync(p.evidence || "");
          const current = createHash("sha256").update(value).digest("hex");
          return !value.length || !p.evidence_digest || current !== p.evidence_digest;
        } catch { return true; }
      });
      console.log(noev.length ? "NOEVIDENCE " + noev.join(",") : "OK");
    ' 2>/dev/null || echo "NODE_ERR")"

    case "$missing" in
      OK) : ;;
      NO_LEDGER) echo "== NOT SEALED: no phase ledger — run the gate phases and record each with scripts/record-phase.mjs =="; exit 1 ;;
      STALE*) echo "== NOT SEALED: phase ledger is stale (${missing#STALE }, HEAD ${sha:0:12}) — re-run the gate =="; exit 1 ;;
      MISSING*) echo "== NOT SEALED: HARD phases missing a PASS/SKIP verdict: ${missing#MISSING } =="; exit 1 ;;
      NOEVIDENCE*) echo "== NOT SEALED: judgment phase(s) ${missing#NOEVIDENCE } has missing or changed PASS/SKIP evidence — write findings + re-record with --evidence =="; exit 1 ;;
      *) echo "== NOT SEALED: phase ledger unreadable (fail closed) =="; exit 1 ;;
    esac

    ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    # Atomic write, bound to the complete prepared proof identity.
    gs="$root/.preprgate/gate-status.json"
    if ! node - "$root/.preprgate/context/manifest.json" "$gs.tmp.$$" "$ts" <<'NODE'
const fs = require('fs');
const [manifestFile, output, sealedAt] = process.argv.slice(2);
const manifest = JSON.parse(fs.readFileSync(manifestFile, 'utf8'));
fs.writeFileSync(output, JSON.stringify({
  schema_version: 1,
  repository: manifest.repository,
  base: manifest.base,
  head: manifest.head,
  diff: manifest.diff,
  gate_rules: manifest.gate_rules,
  verdict: 'PASS',
  sealed_at: sealedAt,
}, null, 2) + '\n');
NODE
    then
      rm -f "$gs.tmp.$$"
      echo "== NOT SEALED: exact marker could not be rendered =="
      exit 1
    fi
    if ! mv -f "$gs.tmp.$$" "$gs"; then
      rm -f "$gs.tmp.$$"
      echo "== NOT SEALED: exact marker could not be written =="
      exit 1
    fi
    if ! rmdir "$phase_lock" 2>/dev/null; then
      rm -f "$gs"
      echo "== NOT SEALED: phase ledger lock could not be released =="
      exit 1
    fi
    PREPRGATE_PHASE_LOCK=""
    echo "== SEALED: PASS for ${sha:0:12} =="
    # Final 100% snapshot inline — the seal is the last state change, so render the
    # bar once here (never a backgrounded --watch; that never surfaced live).
    bash "$(dirname "$0")/heartbeat.sh" 2>/dev/null || true
  else
    echo "== NOT SEALED: $fails deterministic check(s) failed =="
    exit 1
  fi
fi

[ "$fails" -eq 0 ] || exit 1
echo "== all deterministic checks passed =="
