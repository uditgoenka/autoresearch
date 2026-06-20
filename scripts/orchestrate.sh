#!/usr/bin/env bash
# orchestrate.sh — deterministic seam for the autoresearch orchestrator loop.
#
#   classify   <goal-string>   → Goal archetype label (keyword heuristics)
#   next-hop   <state.json>    → Next subcommand from router decision table
#   units      <results.json>  → Units-remaining scalar (lower_is_better)
#   plateau    <history.txt>   → Exit 0 if last N computed values are flat-or-worse
#   screen-cmd <shell-string>  → "ok" exit 0 | "refuse" exit 1 safety gate
#   verdict    <state.json>    → CONVERGED|PLATEAU|CEILING|BLOCKED + ship-gate
#
# All subcommands are pure and CI-usable via exit codes.
set -uo pipefail

# ---------------------------------------------------------------------------
# classify: map a goal string to one of the 9 Goal archetype labels.
# Priority order matters: higher-stakes archetypes checked first so that
# "fix and add the broken feature" → fix-broken, not build-feature.
# ---------------------------------------------------------------------------
classify() {
  local goal="${1:?usage: classify <goal-string>}"
  local g
  g=$(printf '%s' "$goal" | tr '[:upper:]' '[:lower:]')

  # Security/hardening — above build because "secure" is higher stakes than "add"
  if printf '%s' "$g" | grep -qE '(secure|harden|vuln)'; then
    echo "harden"; return 0
  fi

  # Broken/bugfix
  if printf '%s' "$g" | grep -qE '(fix|bug|broken)'; then
    echo "fix-broken"; return 0
  fi

  # Ship/release/deploy
  if printf '%s' "$g" | grep -qE '(ship|release|deploy)'; then
    echo "ship-ready"; return 0
  fi

  # Product direction — requires a "what …" question so bare "next"/"build" in a
  # build-feature goal (e.g. "build the next-gen parser") doesn't mis-route here.
  if printf '%s' "$g" | grep -qE '(what.*build|what.*next)'; then
    echo "what-to-build"; return 0
  fi

  # Build/implement/add — "feature" alone is insufficient; any of these words qualify
  if printf '%s' "$g" | grep -qE '(build|implement|add)'; then
    echo "build-feature"; return 0
  fi

  # Metric optimization
  if printf '%s' "$g" | grep -qE '(faster|smaller|reduce|optimize|coverage)'; then
    echo "optimize-metric"; return 0
  fi

  # Documentation
  if printf '%s' "$g" | grep -qE '(document|docs)'; then
    echo "document"; return 0
  fi

  # Design decision — "should we" / "decide" / "approach"
  if printf '%s' "$g" | grep -qE '(should we|decide|approach)'; then
    echo "decide-design"; return 0
  fi

  # Default: open-ended investigation
  echo "explore"
}

# ---------------------------------------------------------------------------
# next-hop: cheap router over fields in a state JSON file.
# Decision order: errors → regression → untested gaps → ship/DONE.
# ---------------------------------------------------------------------------
next-hop() {
  local state_file="${1:?usage: next-hop <state.json>}"
  if [[ ! -f "$state_file" ]]; then
    echo "ERROR: missing state file" >&2; return 2
  fi

  # Parse with sed/grep — no jq dependency (score-regression.sh doesn't use jq)
  local errors regression gaps archetype
  errors=$(grep -o '"errors_remaining"[[:space:]]*:[[:space:]]*[0-9]*' "$state_file" \
             | grep -o '[0-9]*$')
  regression=$(grep -o '"regression_verdict"[[:space:]]*:[[:space:]]*"[^"]*"' "$state_file" \
                 | grep -o '"[^"]*"$' | tr -d '"')
  gaps=$(grep -o '"untested_gaps"[[:space:]]*:[[:space:]]*[0-9]*' "$state_file" \
           | grep -o '[0-9]*$')
  archetype=$(grep -o '"archetype"[[:space:]]*:[[:space:]]*"[^"]*"' "$state_file" \
                | grep -o '"[^"]*"$' | tr -d '"')

  # Guard: missing required fields
  if [[ -z "$errors" || -z "$regression" || -z "$gaps" ]]; then
    echo "ERROR: malformed state file" >&2; return 2
  fi

  if [[ "$errors" -gt 0 ]]; then
    echo "fix"; return 0
  fi

  if [[ "$regression" == "UNSTABLE" ]]; then
    echo "regression"; return 0
  fi

  if [[ "$gaps" -gt 0 ]]; then
    echo "debug"; return 0
  fi

  # All clear: ship if archetype has ship in the pipeline, else DONE
  if [[ "$archetype" == "ship-ready" ]]; then
    echo "ship"; return 0
  fi

  echo "DONE"
}

# ---------------------------------------------------------------------------
# units: compute Units-remaining scalar from a results JSON file.
# Formula: failing_tests + open_hard_regressions + (metric_delta / metric_target)
# Prints "unknown" and exits 2 when inputs are missing or uncomputable.
# ---------------------------------------------------------------------------
units() {
  local results_file="${1:?usage: units <results.json>}"
  if [[ ! -f "$results_file" ]]; then
    echo "unknown"; return 2
  fi

  local ft regressions delta target
  ft=$(grep -o '"failing_tests"[[:space:]]*:[[:space:]]*[0-9.]*' "$results_file" \
         | grep -o '[0-9.]*$')
  regressions=$(grep -o '"open_hard_regressions"[[:space:]]*:[[:space:]]*[0-9.]*' "$results_file" \
                  | grep -o '[0-9.]*$')
  delta=$(grep -o '"metric_delta"[[:space:]]*:[[:space:]]*[0-9.]*' "$results_file" \
            | grep -o '[0-9.]*$')
  target=$(grep -o '"metric_target"[[:space:]]*:[[:space:]]*[0-9.]*' "$results_file" \
             | grep -o '[0-9.]*$')

  if [[ -z "$ft" || -z "$regressions" || -z "$delta" || -z "$target" ]]; then
    echo "unknown"; return 2
  fi

  # Integer check: metric_target must be non-zero to avoid divide-by-zero
  if [[ "$target" == "0" || "$target" == "0.0" ]]; then
    echo "unknown"; return 2
  fi

  # awk handles floating point; strip trailing .0 for clean integer output
  awk -v ft="$ft" -v r="$regressions" -v d="$delta" -v t="$target" '
    BEGIN {
      val = ft + r + (d / t)
      # Strip unnecessary trailing zeros (e.g. 4.500 → 4.5, 0.000 → 0)
      if (val == int(val)) printf "%d\n", val
      else printf "%g\n", val
    }
  '
}

# ---------------------------------------------------------------------------
# plateau: read newline list of unit values; determine if progress has stalled.
# Skips interleaved "unknown" cycles; N=5 consecutive trailing unknowns = BLOCKED.
# Exit 0 = plateau (no net progress); exit 1 = still improving; exit 3 = BLOCKED.
# ---------------------------------------------------------------------------
plateau() {
  local history_file="${1:?usage: plateau <history.txt>}"
  local n=5

  if [[ ! -f "$history_file" ]]; then
    echo "BLOCKED"; return 3
  fi

  awk -v n="$n" '
    {
      line = $0
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
      if (line == "unknown") { trailing_unknown++; next }            # crash/uncomputable cycle
      if (line ~ /^[0-9]/)   { vals[++count] = line + 0; trailing_unknown = 0 }
    }
    END {
      # A runner stuck emitting "unknown" must not read as progress: n consecutive
      # trailing unknowns (or no computed value at all) → BLOCKED, not "improving".
      if (trailing_unknown >= n) { print "BLOCKED"; exit 3 }
      if (count == 0)            { print "BLOCKED"; exit 3 }

      # Need at least n computed values before a plateau call.
      if (count < n) { exit 1 }

      # Net progress over the window = last value strictly below the first
      # (lower_is_better). Any oscillation that nets flat-or-worse is a plateau,
      # so a thrashing loop stops instead of running to the ceiling.
      start = count - n + 1
      if (vals[count] < vals[start]) { exit 1 }   # net improvement → still working
      exit 0                                       # flat or worse → plateau
    }
  ' "$history_file"
}

# ---------------------------------------------------------------------------
# screen-cmd: safety gate for shell strings before execution.
# Prints "ok" / "refuse". Anchored DB-host allowlist: only localhost,
# 127.0.0.1, or a plain hostname (no dots) with a _test or _ci dbname suffix.
# Bare substring "test" inside words like "latest" or "precision" must NOT qualify.
# ---------------------------------------------------------------------------
screen-cmd() {
  local cmd="${1:?usage: screen-cmd <shell-string>}"

  # rm with recursive AND force, in any flag arrangement: bundled (-rf/-Rf/-fr),
  # separate (-r -f), or long (--recursive --force). Both flags must be present.
  # The optional path prefix catches path-qualified invocations (/bin/rm, ./rm,
  # /usr/local/bin/rm) that a bare command-name anchor would miss.
  if printf '%s' "$cmd" | grep -qE '(^|[[:space:]])([^[:space:]]*/)?rm([[:space:]]|$)'; then
    local rm_rec=0 rm_force=0
    printf '%s' "$cmd" | grep -qE -- '(^|[[:space:]])-[a-zA-Z]*[rR]|--recursive' && rm_rec=1
    printf '%s' "$cmd" | grep -qE -- '(^|[[:space:]])-[a-zA-Z]*[fF]|--force'     && rm_force=1
    if [[ "$rm_rec" -eq 1 && "$rm_force" -eq 1 ]]; then
      echo "refuse"; return 1
    fi
  fi

  # curl/wget piped to an interpreter (sh/bash/zsh/dash/fish/ksh/python/perl/ruby/
  # node/php), including a path-qualified one (| /bin/bash). Enumerated interpreters
  # rather than "refuse any curl pipe" so a legitimate derived predicate that pipes
  # curl output to a parser (jq/grep/awk) is not falsely refused.
  if printf '%s' "$cmd" | grep -qE '(curl|wget)[^|]*\|[[:space:]]*([^[:space:]]*/)?(sh|bash|zsh|dash|fish|ksh|python[0-9.]*|perl|ruby|node|php)([[:space:]]|$)'; then
    echo "refuse"; return 1
  fi

  # Fork bomb pattern
  if printf '%s' "$cmd" | grep -qF ':(){ :|:'; then
    echo "refuse"; return 1
  fi
  if printf '%s' "$cmd" | grep -qE ':\(\)\{'; then
    echo "refuse"; return 1
  fi

  # AWS credential patterns (key IDs start with AKIA, secret keys are 40-char base64)
  if printf '%s' "$cmd" | grep -qE 'AKIA[0-9A-Z]{16}'; then
    echo "refuse"; return 1
  fi

  # PASSWORD= credential pattern
  if printf '%s' "$cmd" | grep -qE 'PASSWORD[[:space:]]*='; then
    echo "refuse"; return 1
  fi

  # Private key headers — pattern starts with dashes so pass -- to avoid flag misparse
  if printf '%s' "$cmd" | grep -qE -- 'BEGIN (RSA |EC |OPENSSH |DSA )?PRIVATE KEY'; then
    echo "refuse"; return 1
  fi

  # Database URL safety: extract host and dbname from postgres:// or postgresql:// URIs
  # Pattern: postgres(ql)://user:pass@HOST/DBNAME or postgres(ql)://HOST/DBNAME
  if printf '%s' "$cmd" | grep -qE 'postgres(ql)?://'; then
    # Extract the host portion (after @ or after ://)
    local db_host db_name
    db_host=$(printf '%s' "$cmd" \
      | grep -oE 'postgres(ql)?://[^[:space:]]+' \
      | sed -E 's|postgres(ql)?://([^@]+@)?([^/:]+)[:/].*|\3|')
    db_name=$(printf '%s' "$cmd" \
      | grep -oE 'postgres(ql)?://[^[:space:]]+' \
      | sed -E 's|postgres(ql)?://[^/]*/([^?[:space:]]+).*|\2|')

    # Allowed hosts: localhost, 127.0.0.1, or a single-label hostname (no dots = container)
    local host_ok=0
    if [[ "$db_host" == "localhost" || "$db_host" == "127.0.0.1" ]]; then
      host_ok=1
    elif printf '%s' "$db_host" | grep -qvE '\.'; then
      # No dots = plain container hostname → allowed
      host_ok=1
    fi

    if [[ "$host_ok" -eq 0 ]]; then
      # Non-allowlisted host: dbname must end with _test or _ci (anchored suffix, not substring)
      if printf '%s' "$db_name" | grep -qE '_test$|_ci$'; then
        echo "ok"; return 0
      fi
      echo "refuse"; return 1
    fi
  fi

  echo "ok"; return 0
}

# ---------------------------------------------------------------------------
# verdict: synthesize a convergence verdict from state JSON.
# Reads: units, plateau, ceiling fields. Prints verdict + ship-gate line.
# Exit 0 = CONVERGED; exit 1 = not converged; exit 2 = error.
# ---------------------------------------------------------------------------
verdict() {
  local state_file="${1:?usage: verdict <state.json>}"
  if [[ ! -f "$state_file" ]]; then
    echo "BLOCKED"; echo "ship=no"; return 2
  fi

  local units_val plateau_val ceiling_val
  units_val=$(grep -o '"units"[[:space:]]*:[[:space:]]*[0-9.]*' "$state_file" \
                | grep -o '[0-9.]*$')
  plateau_val=$(grep -o '"plateau"[[:space:]]*:[[:space:]]*[a-z]*' "$state_file" \
                  | grep -o '[a-z]*$')
  ceiling_val=$(grep -o '"ceiling"[[:space:]]*:[[:space:]]*[a-z]*' "$state_file" \
                  | grep -o '[a-z]*$')

  if [[ -z "$units_val" ]]; then
    echo "BLOCKED"; echo "ship=no"; return 2
  fi

  if [[ "$plateau_val" == "true" ]]; then
    echo "PLATEAU"; echo "ship=no"; return 1
  fi

  if [[ "$ceiling_val" == "true" ]]; then
    echo "CEILING"; echo "ship=no"; return 1
  fi

  # units==0 with no plateau/ceiling → converged
  if awk -v u="$units_val" 'BEGIN { exit (u == 0 ? 0 : 1) }'; then
    echo "CONVERGED"; echo "ship=yes"; return 0
  fi

  # units > 0, no plateau/ceiling signal yet → still running
  echo "BLOCKED"; echo "ship=no"; return 1
}

case "${1:-}" in
  classify)   shift; classify   "$@" ;;
  next-hop)   shift; next-hop   "$@" ;;
  units)      shift; units      "$@" ;;
  plateau)    shift; plateau    "$@" ;;
  screen-cmd) shift; screen-cmd "$@" ;;
  verdict)    shift; verdict    "$@" ;;
  *) echo "usage: $0 {classify|next-hop|units|plateau|screen-cmd|verdict}" >&2; exit 64 ;;
esac
