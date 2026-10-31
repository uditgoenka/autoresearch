#!/usr/bin/env bash
# preprgate shared shell helpers. Sourced by prep-context.sh and run-checks.sh so
# base resolution, stack detection, and the fail-open phase cache have ONE
# definition instead of drifting copies. No side effects on source; pure functions.
# shellcheck shell=bash

# Resolve the diff base once. An explicit PREPRGATE_BASE is an exact boundary
# (stack parents use this); normal mode uses the configured remote default branch.
# Unknown scope fails closed. The empty tree is valid only for a genuine root commit.
preprgate_resolve_base() {
  PREPRGATE_BASE_FALLBACK=0
  local requested="${PREPRGATE_BASE:-}" b remote="${PREPRGATE_REMOTE:-origin}" sym ref parents
  PREPRGATE_BASE_REF=""
  PREPRGATE_BASE_SOURCE=""

  if [ -n "$requested" ]; then
    b="$(git rev-parse --verify "${requested}^{commit}" 2>/dev/null)" || {
      echo "preprgate: explicit base '$requested' is not a commit" >&2
      return 2
    }
    PREPRGATE_BASE_REF="$requested"
    PREPRGATE_BASE_SOURCE="explicit"
  else
    sym="$(git symbolic-ref --quiet "refs/remotes/$remote/HEAD" 2>/dev/null || true)"
    if [ -n "$sym" ] && git rev-parse --verify --quiet "${sym}^{commit}" >/dev/null; then
      ref="${sym#refs/remotes/}"
      b="$(git merge-base HEAD "$ref" 2>/dev/null)" || {
        echo "preprgate: HEAD has no merge base with remote default '$ref'" >&2
        return 2
      }
      PREPRGATE_BASE_REF="$ref"
      PREPRGATE_BASE_SOURCE="remote-default"
    elif git show-ref --verify --quiet refs/heads/main; then
      b="$(git merge-base HEAD main 2>/dev/null)" || return 2
      PREPRGATE_BASE_REF="main"
      PREPRGATE_BASE_SOURCE="local-default"
    elif git show-ref --verify --quiet refs/heads/master; then
      b="$(git merge-base HEAD master 2>/dev/null)" || return 2
      PREPRGATE_BASE_REF="master"
      PREPRGATE_BASE_SOURCE="local-default"
    else
      parents="$(git rev-list --parents -n 1 HEAD 2>/dev/null)" || {
        echo "preprgate: cannot resolve HEAD; commit the branch before running the gate" >&2
        return 2
      }
      # One field means HEAD is the repository's root commit.
      if [ "$(printf '%s\n' "$parents" | awk '{print NF}')" -eq 1 ]; then
        b="$(git hash-object -t tree /dev/null)"
        PREPRGATE_BASE_REF="<empty-tree>"
        PREPRGATE_BASE_SOURCE="root-commit"
      else
        echo "preprgate: cannot resolve a trustworthy diff base; set PREPRGATE_BASE or configure the remote default branch" >&2
        return 2
      fi
    fi
  fi
  PREPRGATE_BASE="$b"
}

_preprgate_detect_project() {
  PREPRGATE_PM=none
  PREPRGATE_REACT=0
  PREPRGATE_NODE=0
  PREPRGATE_PY=0
  PREPRGATE_GO=0
  PREPRGATE_RUST=0
  if [ -f package.json ]; then
    PREPRGATE_NODE=1; PREPRGATE_PM=npm
    [ -f pnpm-lock.yaml ] && PREPRGATE_PM=pnpm
    [ -f yarn.lock ] && PREPRGATE_PM=yarn
    [ -f bun.lockb ] && PREPRGATE_PM=bun
    # React iff a react dep is declared OR a JSX/TSX file exists in the tree.
    if grep -q '"react"' package.json 2>/dev/null \
       || git ls-files '*.jsx' '*.tsx' 2>/dev/null | head -1 | grep -q .; then PREPRGATE_REACT=1; fi
  fi
  { [ -f pyproject.toml ] || [ -f requirements.txt ] || ls ./*.py >/dev/null 2>&1; } && PREPRGATE_PY=1
  [ -f go.mod ] && PREPRGATE_GO=1
  [ -f Cargo.toml ] && PREPRGATE_RUST=1
}

# Compatibility output for existing callers. "Stack" now means only a GitHub
# branch/PR graph; new context uses preprgate_project_profile instead.
preprgate_detect_stack() {
  _preprgate_detect_project
  echo "$PREPRGATE_PM react=$PREPRGATE_REACT node=$PREPRGATE_NODE py=$PREPRGATE_PY go=$PREPRGATE_GO rust=$PREPRGATE_RUST"
}

preprgate_project_profile() {
  _preprgate_detect_project
  printf '{"schema_version":1,"package_manager":"%s","react":%s,"node":%s,"python":%s,"go":%s,"rust":%s}\n' \
    "$PREPRGATE_PM" "$PREPRGATE_REACT" "$PREPRGATE_NODE" "$PREPRGATE_PY" "$PREPRGATE_GO" "$PREPRGATE_RUST"
}

# --- Fail-open phase cache (T8) -------------------------------------------------
# Caches ONLY a PASS verdict, keyed by a content hash of the exact inputs a check
# depends on. A cache MISS or any doubt always re-runs — the cache can never cause
# a skipped failing check, only skip a repeat of an already-green one. This is what
# makes the fix→re-run loop cheap without trading away the stability guarantee.
#
# Usage:
#   key="$(preprgate_hash_paths tsconfig.json $(git ls-files '*.ts'))"
#   if preprgate_cache_hit typecheck "$key"; then echo "cached PASS"; else
#     run_the_check && preprgate_cache_put typecheck "$key"
#   fi
preprgate_cache_dir() { echo "$(git rev-parse --show-toplevel 2>/dev/null || pwd)/.preprgate/cache"; }

# Hash the CONTENT of the given tracked files (order-independent). Empty/unhashable
# input yields empty → treated as a miss (re-run). Uses git's object hashing so it
# needs no external sha tool and reflects committed content exactly.
preprgate_hash_paths() {
  [ "$#" -gt 0 ] || { echo ""; return; }
  # git hash-object over existing files; sort for order-independence; hash the list.
  local list
  list="$(for p in "$@"; do [ -f "$p" ] && git hash-object "$p" 2>/dev/null; done | sort)"
  [ -n "$list" ] || { echo ""; return; }
  printf '%s' "$list" | git hash-object --stdin 2>/dev/null
}

preprgate_cache_hit() { # <check-name> <key>
  local d; d="$(preprgate_cache_dir)"
  [ -n "$2" ] && [ -f "$d/$1" ] && [ "$(cat "$d/$1" 2>/dev/null)" = "$2" ]
}

preprgate_cache_put() { # <check-name> <key>   (only call on PASS)
  local d; d="$(preprgate_cache_dir)"
  [ -n "$2" ] || return 0
  mkdir -p "$d" && printf '%s' "$2" > "$d/$1"
}

# --- Fail-open SET cache (F3: per-file review reuse on the fix-loop) -------------
# The single-key cache above proves ONE aggregate input is unchanged. Review phases
# instead clear files one at a time, so they need set membership: "have I already
# cleared THIS file's content in THIS phase?". Keyed by the file's git content hash,
# so a byte-identical slice reused across fix-loop commits is a hit regardless of
# HEAD — a fix that touches one file lets the other slices skip re-review. Same
# fail-open contract: only CLEAN (no-blocker) slices are ever marked; any content
# change misses and re-reviews; a blocker is never cached.
preprgate_cache_seen() { # <check-name> <content-hash>  -> 0 if already cleared
  local d; d="$(preprgate_cache_dir)"
  [ -n "$2" ] && [ -f "$d/$1.seen" ] && grep -qxF "$2" "$d/$1.seen" 2>/dev/null
}

preprgate_cache_mark() { # <check-name> <content-hash>   (only call on a clean slice)
  local d f; d="$(preprgate_cache_dir)"; f="$d/$1.seen"
  [ -n "$2" ] || return 0
  mkdir -p "$d"
  grep -qxF "$2" "$f" 2>/dev/null && return 0
  printf '%s\n' "$2" >> "$f"
  # Bound growth: the set appends one content-hash per distinct cleared slice and
  # never expired, so a long-lived repo's .seen grew without limit. Cap to the most
  # recent N (oldest hashes fall off — least-recently-cleared, safe to re-review).
  local cap=5000 n
  n="$(wc -l < "$f" 2>/dev/null || echo 0)"; n="${n//[!0-9]/}"
  if [ "${n:-0}" -gt "$cap" ]; then
    tail -n "$cap" "$f" > "$f.tmp.$$" && mv -f "$f.tmp.$$" "$f"
  fi
}

# --- Repository-wide mechanical lock -------------------------------------------
# Linked worktrees share one Git common directory. Lock there so separate agent
# sessions cannot run competing test/build processes against the same ports and
# databases. Contention fails immediately; this is a gate, not a scheduler.
preprgate_acquire_mechanical_lock() {
  local common lock pid
  common="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" || return 2
  mkdir -p "$common/prgate"
  lock="$common/prgate/mechanical.lock"
  if [ "${PREPRGATE_MECHANICAL_LOCK:-}" = "$lock" ] \
    && [ "$(cat "$lock/pid" 2>/dev/null || true)" = "$$" ]; then
    return 0
  fi
  PREPRGATE_MECHANICAL_LOCK=""
  if ! mkdir "$lock" 2>/dev/null; then
    pid="$(cat "$lock/pid" 2>/dev/null || true)"
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
      echo "preprgate: another gate run holds the mechanical lock${pid:+ (pid $pid)} ($lock)" >&2
    elif [ -n "$pid" ]; then
      echo "preprgate: stale mechanical lock from pid $pid requires explicit operator cleanup ($lock)" >&2
    else
      echo "preprgate: mechanical lock is acquiring or corrupt ($lock); fail closed rather than delete a possible owner" >&2
    fi
    return 3
  fi
  printf '%s\n' "$$" > "$lock/pid" || { rmdir "$lock" 2>/dev/null; return 2; }
  PREPRGATE_MECHANICAL_LOCK="$lock"
  trap 'if [ "$(cat "$PREPRGATE_MECHANICAL_LOCK/pid" 2>/dev/null || true)" = "$$" ]; then rm -f "$PREPRGATE_MECHANICAL_LOCK/pid"; rmdir "$PREPRGATE_MECHANICAL_LOCK" 2>/dev/null || true; fi; [ -z "${PREPRGATE_PHASE_LOCK:-}" ] || rmdir "$PREPRGATE_PHASE_LOCK" 2>/dev/null || true' EXIT
}

# --- Liveness backstop: bounded command execution (fixes the Phase-3 hang) ------
# Every long-running check (tests, build, typecheck) used to run with no wall-clock
# cap, inherited stdin, and no CI marker — so a watch-mode / interactive /
# open-handle runner (react-scripts, vitest, jest, CRA "test" scripts) would block
# indefinitely, wedging the gate for hours. preprgate_bounded runs a command string
# with three guards so a stalled phase FAILS fast (and the gate re-runs) instead of
# hanging forever:
#   CI=1        — watch-mode runners go single-run non-interactive.
#   </dev/null  — any prompt/TTY read gets EOF and exits.
#   hard cap    — PREPRGATE_CHECK_TIMEOUT seconds (default 900), then the runner and
#                 its whole process subtree are killed.
# Returns the command's exit code, or 124 on timeout (GNU-timeout convention), so
# callers can report TIMEOUT distinctly. Portable: uses timeout/gtimeout if present
# (Linux/CI), else the already-required Node runtime on stock macOS.
_preprgate_effective_timeout() {
  local default_timeout=480
  [ "${PREPRGATE_CI_FULL:-0}" = 1 ] && default_timeout=900
  local requested="${PREPRGATE_CHECK_TIMEOUT:-$default_timeout}" budget="${PREPRGATE_RUN_BUDGET:-900}"
  local started now remaining effective root
  case "$requested" in ''|*[!0-9]*) echo "preprgate: PREPRGATE_CHECK_TIMEOUT must be a positive integer" >&2; return 2 ;; esac
  case "$budget" in ''|*[!0-9]*) echo "preprgate: PREPRGATE_RUN_BUDGET must be a positive integer" >&2; return 2 ;; esac
  [ "$requested" -gt 0 ] && [ "$budget" -gt 0 ] || {
    echo "preprgate: timeout budgets must be greater than zero" >&2
    return 2
  }
  [ "$budget" -le 900 ] || budget=900
  effective="$requested"
  [ "$effective" -le "$budget" ] || effective="$budget"
  root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
  started="$(node -e 'const fs=require("fs");for(const f of process.argv.slice(1)){try{const n=JSON.parse(fs.readFileSync(f,"utf8")).started_at;if(Number.isFinite(n)){process.stdout.write(String(Math.floor(n/1000)));break}}catch{}}' "$root/.preprgate/attempt.json" "$root/.preprgate/phases.json" 2>/dev/null || true)"
  if [ -n "$started" ]; then
    now="$(date +%s)"
    remaining=$((budget - now + started - 10)) # reserve the existing kill grace
    [ "$remaining" -gt 0 ] || {
      echo "preprgate: local 900-second attempt budget exhausted" >&2
      return 124
    }
    [ "$effective" -le "$remaining" ] || effective="$remaining"
  fi
  printf '%s\n' "$effective"
}

_preprgate_progress_start() {
  PREPRGATE_PROGRESS_PID=""
  [ -n "${PREPRGATE_PROGRESS_LABEL:-}" ] || return 0
  local interval="${PREPRGATE_PROGRESS_INTERVAL:-60}" file="${PREPRGATE_PROGRESS_FILE:-}"
  case "$interval" in ''|*[!0-9]*) interval=60 ;; esac
  [ "$interval" -gt 0 ] || interval=60
  (
    local elapsed=0 bytes=0
    # Poll once per second so stopping the ticker cannot leave a 60-second sleep
    # holding the caller's output descriptor open after the command has finished.
    while sleep 1; do
      elapsed=$((elapsed + 1))
      [ $((elapsed % interval)) -eq 0 ] || continue
      [ -n "$file" ] && bytes="$(wc -c < "$file" 2>/dev/null || echo 0)"
      printf '  … %s: %ss elapsed, %s bytes captured\n' "$PREPRGATE_PROGRESS_LABEL" "$elapsed" "$bytes" >&3
    done
  ) &
  PREPRGATE_PROGRESS_PID=$!
}

_preprgate_progress_stop() {
  [ -n "${PREPRGATE_PROGRESS_PID:-}" ] || return 0
  kill "$PREPRGATE_PROGRESS_PID" 2>/dev/null || true
  wait "$PREPRGATE_PROGRESS_PID" 2>/dev/null || true
  PREPRGATE_PROGRESS_PID=""
}

preprgate_bounded() { # <shell-command-string>
  local t rc
  t="$(_preprgate_effective_timeout)"; rc=$?
  [ "$rc" -eq 0 ] || return "$rc"
  _preprgate_progress_start
  if command -v timeout >/dev/null 2>&1; then
    CI=1 timeout -k 10 "$t" bash -c "$1" </dev/null; rc=$?
    _preprgate_progress_stop
    return "$rc"
  fi
  if command -v gtimeout >/dev/null 2>&1; then
    CI=1 gtimeout -k 10 "$t" bash -c "$1" </dev/null; rc=$?
    _preprgate_progress_stop
    return "$rc"
  fi
  # Stock macOS has no timeout binary. Node is already required by the skill and
  # can own one detached process group without a sleeping shell child leaking the
  # output descriptor. Once the deadline fires the verdict is always 124, even if
  # the command traps TERM and exits zero.
  CI=1 node -e '
    const { spawn } = require("node:child_process");
    const seconds = Number(process.argv[1]);
    const child = spawn("bash", ["-c", process.argv[2]], {
      detached: true, env: { ...process.env, CI: "1" }, stdio: ["ignore", "inherit", "inherit"]
    });
    let timedOut = false;
    const timer = setTimeout(() => {
      timedOut = true;
      try { process.kill(-child.pid, "SIGTERM"); } catch {}
      setTimeout(() => {
        try { process.kill(-child.pid, "SIGKILL"); } catch {}
        process.exit(124);
      }, 1000);
    }, seconds * 1000);
    child.on("error", () => { clearTimeout(timer); process.exit(1); });
    child.on("exit", (code, signal) => {
      if (timedOut) return;
      clearTimeout(timer);
      process.exit(code ?? (signal ? 1 : 0));
    });
  ' "$t" "$1" </dev/null; rc=$?
  _preprgate_progress_stop
  return "$rc"
}
