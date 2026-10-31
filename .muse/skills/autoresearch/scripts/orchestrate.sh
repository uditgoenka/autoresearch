#!/usr/bin/env bash
# orchestrate.sh — deterministic seam for the autoresearch orchestrator loop.
#
#   classify   <goal-string>   → Goal archetype label (keyword heuristics)
#   next-hop   <state.json>    → Next subcommand from router decision table
#   units      <results.json>  → Units-remaining scalar (lower_is_better)
#   plateau    <state.json>    → Exit 0 if last N computed values are flat-or-worse
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
  # Keywords match at a word start, so "prefix" is not "fix" and "address" is not "add".
  # Compounds that should still match (debug, hotfix, rebuild) are listed by name.

  # Security/hardening — above build because "secure" is higher stakes than "add"
  if printf '%s' "$g" | grep -qE '(^|[^[:alnum:]_])(secure|insecure|harden|vuln)'; then
    echo "harden"; return 0
  fi

  # Broken/bugfix
  if printf '%s' "$g" | grep -qE '(^|[^[:alnum:]_])(fix|bug|broken|hotfix|bugfix)|^[[:space:]]*debug'; then
    echo "fix-broken"; return 0
  fi

  # debug anywhere else, with no build verb present, is still a bug hunt
  if printf '%s' "$g" | grep -qE '(^|[^[:alnum:]_])debug' \
    && ! printf '%s' "$g" | grep -qE '(^|[^[:alnum:]_])((re)?(build|implement)|add(s|ed|ing)?([^[:alnum:]_]|$))'; then
    echo "fix-broken"; return 0
  fi

  # Ship/release/deploy
  if printf '%s' "$g" | grep -qE '(^|[^[:alnum:]_])(re)?(ship|release|deploy)'; then
    echo "ship-ready"; return 0
  fi

  # Product direction — requires a "what …" question so bare "next"/"build" in a
  # build-feature goal (e.g. "build the next-gen parser") doesn't mis-route here.
  if printf '%s' "$g" | grep -qE '(^|[^[:alnum:]_])(what.*build|what.*next)'; then
    echo "what-to-build"; return 0
  fi

  # Build/implement/add — "feature" alone is insufficient; any of these words qualify
  if printf '%s' "$g" | grep -qE '(^|[^[:alnum:]_])((re)?(build|implement)|add(s|ed|ing)?([^[:alnum:]_]|$))'; then
    echo "build-feature"; return 0
  fi

  # Metric optimization
  if printf '%s' "$g" | grep -qE '(^|[^[:alnum:]_])(faster|smaller|reduce|optimize|coverage)'; then
    echo "optimize-metric"; return 0
  fi

  # Documentation
  if printf '%s' "$g" | grep -qE '(^|[^[:alnum:]_])(document|docs)'; then
    echo "document"; return 0
  fi

  # Design decision — "should we" / "decide" / "approach"
  if printf '%s' "$g" | grep -qE '(^|[^[:alnum:]_])(should we|decide|approach)'; then
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

  # Optional: pending_verify gates an independent acceptance check before DONE/ship.
  # Absent (or false) → routing is identical to prior behavior.
  local pending
  pending=$(grep -o '"pending_verify"[[:space:]]*:[[:space:]]*[a-z]*' "$state_file" \
              | grep -o '[a-z]*$')

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

  # Gaps clear but an accepted high-impact change still needs a fresh, independent
  # acceptance check (separate from the signal used to choose it) → verify first.
  if [[ "$pending" == "true" ]]; then
    echo "verify"; return 0
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
  if awk -v t="$target" 'BEGIN { exit !(t + 0 == 0) }'; then
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
# plateau: read state.units_remaining; determine if progress has stalled.
# Skips interleaved "unknown" cycles; N=5 consecutive trailing unknowns = BLOCKED.
# Exit 0 = plateau (no net progress); exit 1 = still improving; exit 3 = BLOCKED.
# ---------------------------------------------------------------------------
plateau() {
  local state_file="${1:?usage: plateau <state.json>}"

  node - "$state_file" <<'NODE'
const fs = require('fs');
const n = 5;
const blocked = () => { console.log('BLOCKED'); process.exit(3); };
let history;
try {
  const state = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
  history = state.units_remaining;
  if (!Array.isArray(history) || history.some(value =>
    value !== 'unknown' && (typeof value !== 'number' || !Number.isFinite(value) || value < 0))) {
    blocked();
  }
} catch {
  blocked();
}

let trailingUnknown = 0;
for (let i = history.length - 1; i >= 0 && history[i] === 'unknown'; i--) trailingUnknown++;
const values = history.filter(value => value !== 'unknown');
// An uncomputable runner is BLOCKED; unknown cycles never count as zero progress.
if (trailingUnknown >= n || values.length === 0) blocked();
if (values.length < n) process.exit(1);
// Lower is better. Oscillation with no net improvement is a plateau too.
process.exit(values[values.length - 1] < values[values.length - n] ? 1 : 0);
NODE
}

# ---------------------------------------------------------------------------
# screen-cmd: safety gate for shell strings before execution.
# Prints "ok" / "refuse". Database hosts other than localhost, 127.0.0.1 or a
# single-label name that starts with a letter need a _test or _ci dbname suffix.
# Bare substring "test" inside words like "latest" or "precision" must NOT qualify.
# ---------------------------------------------------------------------------
screen-cmd() {
  local cmd="${1:?usage: screen-cmd <shell-string>}"
  # A control byte (other than tab and newline) can confuse the readers below, and a
  # backslash before a newline joins two lines into one word (r\<newline>m is rm).
  # Both are refused as a whole kind.
  if printf '%s' "$cmd" | tr -d '\t\n' | LC_ALL=C grep -q '[[:cntrl:]]' \
    || [[ "$cmd" == *\\$'\n'* ]]; then
    echo "refuse"; return 1
  fi
  # The shell drops quotes and backslashes before it runs a name, so 'rm' and \rm are rm.
  local bare=${cmd//[\"\'\\]/}
  # $IFS and brace lists ({rm,-rf,/}) turn into spaces when bash runs them.
  bare=${bare//\$\{IFS\}/ }
  bare=${bare//\$IFS/ }
  bare=${bare//[\{\},]/ }

  # This check cannot expand variables, substitutions or brace lists, and each one can
  # build a name (${X}m, $X, r``m, `printf rm`, $'\x72m', r{m,}). So it refuses the whole
  # kind: any backtick, and any $ outside single quotes unless a closing double quote, a
  # space or the line end follows it (grep "ok$" is fine). A brace list outside quotes is
  # refused too. The scan below reads quotes the way bash does: a backslash escapes the
  # next character, and a single quote inside double quotes is just a character.
  # $"..." is a quoted string to bash, so it is marked like a backtick and refused.
  # Each quoted part is also kept (joined by \002) so a script passed to a nested shell
  # can be checked on its own.
  local scan live unquoted parts
  scan=$(printf '%s' "$cmd" | awk -v sq="'" -v dq='"' -v bs='\\' 'BEGIN { RS = "\001" } {
    q = ""; a = ""; b = ""; part = ""; parts = ""
    for (i = 1; i <= length($0); i++) {
      c = substr($0, i, 1)
      if (q == sq) { if (c == sq) { q = ""; a = a c; b = b c; parts = parts part "\002"; part = "" } else part = part c; continue }
      if (c == bs) { i++; a = a "_"; if (q == "") b = b "_"; else part = part c substr($0, i, 1); continue }
      if (q == dq) { a = a c; if (c == dq) { q = ""; b = b c; parts = parts part "\002"; part = "" } else part = part c; continue }
      if (c == "$" && substr($0, i + 1, 1) == dq) a = a "`"
      if (c == sq || c == dq) q = c
      a = a c; b = b c
    }
    printf "%s\001%s\001%s", a, b, parts part
  }')
  live=${scan%%$'\001'*}
  unquoted=${scan#*$'\001'}
  parts=${unquoted#*$'\001'}
  unquoted=${unquoted%%$'\001'*}
  if printf '%s' "$live" | grep -qE '`|\$[^"[:space:]]' \
    || printf '%s' "$unquoted" | grep -qE '\{[^[:space:]{}]*(,|\.\.)[^[:space:]{}]*\}'; then
    echo "refuse"; return 1
  fi

  # A glob in a command name (r?, /bin/r[m], sudo r*) can match any program, so a glob
  # in the first word of a command, after assignments, reserved words, flags and
  # numbers, is refused. After a launcher, every later word is checked, because an
  # option value (sudo -u root) can come before the name. Globs in arguments
  # (ls *.txt) and the test commands [ and [[ stay fine.
  # Every line is read, and a redirect target (>x, 2>/dev/null) is dropped first so it
  # cannot stand in for the command name.
  if printf '%s' "$unquoted" | awk '{
    line = $0; gsub(/[0-9]*[<>]+[&|]?[[:space:]]*[^[:space:];&|(){}<>]*/, " ", line)
    n = split(line, segs, /[;&|(){}<>]/)
    for (s = 1; s <= n; s++) {
      w = split(segs[s], words, /[[:space:]]+/)
      launched = 0
      for (k = 1; k <= w; k++) {
        x = words[k]
        if (x == "" || x ~ /^[A-Za-z_][A-Za-z0-9_]*=/ || x ~ /^-/ || x ~ /^[0-9]+$/) continue
        if (x ~ /^(if|then|else|elif|do|while|until|!)$/) continue
        y = x; sub(/^[^[:space:]]*[\/]/, "", y)
        if (y ~ /^(sudo|doas|env|exec|command|builtin|nohup|time|nice|ionice|timeout|xargs|stdbuf|chrt|taskset|eval)$/) { launched = 1; continue }
        if (x == "[" || x == "[[") break
        if (x ~ /[*?[]/) found = 1
        if (!launched) break
      }
    }
  }
  END { exit !found }'; then
    echo "refuse"; return 1
  fi

  # A shell or eval runs its quoted script as a new command, so each quoted part is
  # screened on its own too: bash -c 'X=rm; $X -rf /' and eval 'r? -rf /' are seen.
  # The outer shell drops the backslash in \$ and \`, so the inner script sees a live
  # expansion; those are refused outright when a nested shell is present.
  if printf '%s' "$bare" | grep -qE '(^|[[:space:];&|(){`<>])([^[:space:];&|(){`<>]*/)?(eval|sh|bash|zsh|dash|ksh|fish|source|su)([[:space:];&|()<>]|$)' \
    || printf '%s' "$bare" | grep -qE '(^|[;&|(){`])[[:space:]]*\.[[:space:]]'; then
    if [[ "$cmd" == *'\$'* || "$cmd" == *'\`'* ]]; then echo "refuse"; return 1; fi
    local part
    while IFS= read -r -d $'\002' part; do
      [[ -n "${part//[[:space:]]/}" ]] || continue
      screen-cmd "$part" >/dev/null || { echo "refuse"; return 1; }
    done <<< "$parts"$'\002'
  fi

  # env -S splits one argument into a new command line that the matchers cannot read.
  if printf '%s' "$bare" | grep -qE '(^|[[:space:];&|(){`<>])([^[:space:];&|(){`<>]*/)?env([[:space:]]+[^[:space:];&|()<>]+)*[[:space:]]+(-[a-zA-Z]*S|--split-string)'; then
    echo "refuse"; return 1
  fi

  # Each command matcher below starts at a space, ; & | ( ) { ` $ < or >, so `true;rm -rf /`
  # and `$(rm -rf ~)` are seen too. Flags are read from $bare, so rm "-rf" / is too.
  # rm with recursive AND force, in any flag arrangement: bundled (-rf/-Rf/-fr),
  # separate (-r -f), or long (--recursive --force). Both flags must be present.
  # The optional path prefix catches path-qualified invocations (/bin/rm, ./rm,
  # /usr/local/bin/rm) that a bare command-name anchor would miss.
  if printf '%s' "$bare" | grep -qE '(^|[[:space:];&|(){`\\$<>])([^[:space:];&|(){`<>]*/)?rm([[:space:];&|()<>]|$)'; then
    local rm_rec=0 rm_force=0
    printf '%s' "$bare" | grep -qE -- '(^|[[:space:]])-[a-zA-Z]*[rR]|(^|[[:space:]])--r(e(c(u(r(s(i(ve?)?)?)?)?)?)?)?([^[:alnum:]_-]|$)' && rm_rec=1
    printf '%s' "$bare" | grep -qE -- '(^|[[:space:]])-[a-zA-Z]*[fF]|(^|[[:space:]])--f(o(r(ce?)?)?)?([^[:alnum:]_-]|$)'     && rm_force=1
    if [[ "$rm_rec" -eq 1 && "$rm_force" -eq 1 ]]; then
      echo "refuse"; return 1
    fi
  fi

  # curl/wget piped to an interpreter (sh/bash/zsh/dash/fish/ksh/python/perl/ruby/
  # node/php), including a path-qualified one (| /bin/bash). Enumerated interpreters
  # rather than "refuse any curl pipe" so a legitimate derived predicate that pipes
  # curl output to a parser (jq/grep/awk) is not falsely refused.
  if printf '%s' "$bare" | grep -qE '(curl|wget)[^|]*\|[[:space:]]*([^[:space:]]*/)?(sh|bash|zsh|dash|fish|ksh|python[0-9.]*|perl|ruby|node|php)([[:space:];&|()<>]|$)'; then
    echo "refuse"; return 1
  fi

  # curl/wget piped through a launcher (sudo, env, exec, ...) into an interpreter.
  if printf '%s' "$bare" | grep -qE '(curl|wget)[^|]*\|[[:space:]]*(sudo|doas|env|exec|command|nohup|time)([[:space:]]+[^[:space:]|]+)*[[:space:]]+([^[:space:]]*/)?(sh|bash|zsh|dash|fish|ksh|python[0-9.]*|perl|ruby|node|php)([[:space:];&|()<>]|$)'; then
    echo "refuse"; return 1
  fi

  # A remote payload run without a pipe: bash <(curl ...), source <(curl ...),
  # bash -c "$(curl ...)", eval "$(curl ...)".
  if printf '%s' "$bare" | grep -qE '((sh|bash|zsh|dash|fish|ksh|python[0-9.]*|perl|ruby|node|php)|source|\.)[[:space:]]+(<[[:space:]]*)?<\([[:space:]]*(curl|wget)'; then
    echo "refuse"; return 1
  fi
  if printf '%s' "$bare" | grep -qE '((sh|bash|zsh|dash|fish|ksh|python[0-9.]*|perl|ruby|node|php)([[:space:]]+([^[:space:];&|]|[<>]&|&>)+)*[[:space:]]+-[a-zA-Z]*c[a-zA-Z]*|eval)[[:space:]]+["'"'"']?(\$\(|`)[[:space:]]*(curl|wget)'; then
    echo "refuse"; return 1
  fi

  # curl/wget routed through xargs into an interpreter. The xargs wrapper sidesteps the
  # direct pipe matcher above, so a remote payload still reaches a shell.
  if printf '%s' "$bare" | grep -qE '(curl|wget)[^|]*\|.*xargs.*[[:space:]]([^[:space:]]*/)?(sh|bash|zsh|dash|ksh|python[0-9.]*|perl|ruby|node|php)([[:space:];&|()<>]|$)'; then
    echo "refuse"; return 1
  fi

  # Output piped to netcat exfiltrates data off-host.
  if printf '%s' "$bare" | grep -qE '\|[[:space:]]*([^[:space:]]*/)?(nc|ncat|netcat)([[:space:];&|()<>]|$)'; then
    echo "refuse"; return 1
  fi

  # Raw block-device write — dd target or shell redirect onto a disk device wipes it.
  # Scoped to real device families (incl. SD/eMMC mmcblk, mdadm md, device-mapper dm-)
  # so dd/redirect to /dev/null or a regular file stays ok.
  if printf '%s' "$bare" | grep -qE '(of=|>[[:space:]]*)/dev/(sd|hd|vd|nvme|disk|mapper|loop|xvd|mmcblk|md|dm-)'; then
    echo "refuse"; return 1
  fi

  # Filesystem format destroys everything on a partition. Optional path prefix catches a
  # path-qualified invocation (/sbin/mkfs.ext4) that a bare-name anchor would miss.
  if printf '%s' "$bare" | grep -qE '(^|[[:space:];&|(){`\\$<>])([^[:space:];&|(){`<>]*/)?(mkfs|mke2fs)'; then
    echo "refuse"; return 1
  fi

  # find ... -delete mass-removes matched files. Both tokens required so a plain find
  # search (no -delete) is not refused; optional path prefix catches /usr/bin/find.
  if printf '%s' "$bare" | grep -qE '(^|[[:space:];&|(){`\\$<>])([^[:space:];&|(){`<>]*/)?find([[:space:];&|()<>]|$)' \
     && printf '%s' "$bare" | grep -qE '[[:space:]]-delete([[:space:];&|()<>]|$)'; then
    echo "refuse"; return 1
  fi

  # shred overwrites then unlinks — irrecoverable.
  if printf '%s' "$bare" | grep -qE '(^|[[:space:];&|(){`\\$<>])([^[:space:];&|(){`<>]*/)?shred([[:space:];&|()<>]|$)'; then
    echo "refuse"; return 1
  fi

  # truncate to zero size destroys file contents in place. Non-zero sizes are allowed.
  # Optional path prefix catches /usr/bin/truncate; size matcher covers -s 0, -s0,
  # --size 0, and --size=0.
  if printf '%s' "$bare" | grep -qE '(^|[[:space:];&|(){`\\$<>])([^[:space:];&|(){`<>]*/)?truncate([[:space:];&|()<>]|$)' \
     && printf '%s' "$bare" | grep -qE '(-s[[:space:]]*0|--size[[:space:]]*=?[[:space:]]*0)([[:space:];&|()<>]|$)'; then
    echo "refuse"; return 1
  fi

  # Recursive chmod to a zero mode locks an entire tree out of access. Scoped to the
  # zero lock-out (000/00/0 octal short forms) so ordinary recursive permission changes
  # are not refused; optional path prefix catches /bin/chmod.
  if printf '%s' "$bare" | grep -qE '(^|[[:space:];&|(){`\\$<>])([^[:space:];&|(){`<>]*/)?chmod([[:space:];&|()<>]|$)' \
     && printf '%s' "$bare" | grep -qE '(-R|--recursive)([[:space:];&|()<>]|$)' \
     && printf '%s' "$bare" | grep -qE '(^|[[:space:]])(000|00|0)([[:space:];&|()<>]|$)'; then
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
  # A quote or backslash inside the scheme ('postgres'ql://) still gives the shell a URL,
  # so every URL the shell sees must also appear as plain text here.
  local seen_urls plain_urls
  seen_urls=$(printf '%s' "$bare" | grep -oE 'postgres(ql)?://' | wc -l)
  plain_urls=$(printf '%s' "$cmd" | grep -oE 'postgres(ql)?://' | wc -l)
  if [[ "$seen_urls" -ne "$plain_urls" ]]; then
    echo "refuse"; return 1
  fi
  if printf '%s' "$cmd" | grep -qE 'postgres(ql)?://'; then
    # Check every URL: one safe URL must not vouch for a second, real one.
    # A URL ends at whitespace, quotes or shell punctuation, so `A=url1;B=url2` is two URLs.
    # Each URL is read twice: cut at the first punctuation, and with the user:pass part kept
    # whole. `p&ss@prod` and `prod;x@localhost` each fail one of the two readings.
    # Known limit: a dotted user name with & in the password is refused too; run it by hand.
    # Refuse what this check cannot read safely: encoded text (%), several hosts (,),
    # a backslash (the shell drops it, so ho\st= is host=), and query keys that move
    # the connection (host, hostaddr, dbname, service).
    if printf '%s' "$cmd" | grep -qE 'postgres(ql)?://[^[:space:];|<>()]*[%,#\\]' \
      || printf '%s' "$cmd" | grep -qiE 'postgres(ql)?://[^[:space:];|<>()]*[?&](host|hostaddr|dbname|service)='; then
      echo "refuse"; return 1
    fi
    # A URL with nothing after the scheme leaves the host to PGHOST or -h, and a quoted
    # URL with a space in it (a password such as "p ss") is cut before its real host.
    if printf '%s' "$cmd" | grep -qE 'postgres(ql)?://([[:space:];&|<>()"'"'"'`]|$)' \
      || printf '%s' "$cmd" | grep -qE '["'"'"']postgres(ql)?://[^"'"'"']*[[:space:]]'; then
      echo "refuse"; return 1
    fi
    # A quote inside the URL (not just around it) hides where the host really ends.
    if printf '%s' "$cmd" | grep -qE 'postgres(ql)?://[^[:space:];&|<>()]*["'"'"'`][^[:space:];&|<>()"'"'"'`]'; then
      echo "refuse"; return 1
    fi
    local url rest authority db_path db_host db_name host_ok
    while IFS= read -r url; do
      # Split scheme://[user@]host[:port][/dbname][?query]; the query never feeds dbname.
      rest=${url#*://}
      authority=${rest%%/*}
      # Two @ signs leave it unclear which part is the host.
      if [[ "$authority" == *@*@* ]]; then echo "refuse"; return 1; fi
      # Some URL parsers end the host part at ? or #, so prod?@localhost may mean prod.
      if [[ "$authority" == *[?#]*@* ]]; then echo "refuse"; return 1; fi
      db_host=${authority##*@}
      # A ? after the host starts the query, so any later / is not a dbname path.
      if [[ "$db_host" == *\?* ]]; then db_path=""; else db_path=${rest:${#authority}}; fi
      db_host=${db_host%%[:?]*}
      db_path=${db_path%%\?*}
      db_name=${db_path#/}
      # Shell expansion in the name ($_test is an empty variable) hides the real name.
      if [[ "$db_name" == *[\$\{\}\*\[~]* ]]; then echo "refuse"; return 1; fi

      # Allowed hosts: localhost, 127.0.0.1, or a plain single-label name that starts
      # with a letter, such as a container. Anything else is remote: IPv6, a number
      # (2130706433 and 0x7f000001 are IPv4 addresses), and an empty host, which psql
      # fills from PGHOST or -h.
      host_ok=0
      if [[ "$db_host" == "localhost" || "$db_host" == "127.0.0.1" ]]; then
        host_ok=1
      elif [[ "$db_host" =~ ^[A-Za-z][A-Za-z0-9_-]*$ ]]; then
        host_ok=1
      fi

      # Non-allowlisted host: dbname must end with _test or _ci (anchored suffix, not substring)
      if [[ "$host_ok" -eq 0 ]] && ! printf '%s' "$db_name" | grep -qE '_test$|_ci$'; then
        echo "refuse"; return 1
      fi
    done < <(printf '%s' "$cmd" | grep -oE 'postgres(ql)?://[^[:space:];&|<>()"'"'"'`]+'
             printf '%s' "$cmd" | grep -oE 'postgres(ql)?://([^[:space:]/@]*@)?[^[:space:];&|<>()"'"'"'`]+')
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

# ---------------------------------------------------------------------------
# validate-state: schema gate for orchestrator-state.json. The ledger is the
# loop's evidence trail; a malformed one must not be trusted to route from.
# Prints "valid" exit 0 | "invalid" exit 2. Node is a checked installation
# prerequisite, so use its JSON parser rather than approximating JSON with grep.
# ---------------------------------------------------------------------------
validate-state() {
  local state_file="${1:?usage: validate-state <state.json>}"
  if [[ ! -f "$state_file" ]]; then
    echo "invalid"; return 2
  fi

  if ! node -e '
    const fs = require("fs");
    const state = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
    const strings = ["goal", "archetype", "predicate", "terminal_choice"];
    if (!strings.every((key) => typeof state[key] === "string" && state[key].length > 0)) process.exit(1);
    if (!Number.isInteger(state.cycle) || state.cycle < 0) process.exit(1);
    if (!Array.isArray(state.units_remaining) || !Array.isArray(state.pipeline_log)) process.exit(1);
  ' "$state_file" 2>/dev/null; then
    echo "invalid"; return 2
  fi

  echo "valid"; return 0
}

# ---------------------------------------------------------------------------
# screen-state-predicate: extract the pinned predicate from a persisted state
# file and re-run it through screen-cmd. Persisted commands are never trusted —
# a poisoned state file must not re-enter the loop with an unscreened command.
# Delegates the verdict (ok/refuse + exit) to screen-cmd; "invalid" exit 2 when
# the state has no pinned predicate.
# ---------------------------------------------------------------------------
screen-state-predicate() {
  local state_file="${1:?usage: screen-state-predicate <state.json>}"
  if [[ ! -f "$state_file" ]]; then
    echo "invalid"; return 2
  fi

  local pred
  if ! pred=$(node -e '
    const fs = require("fs");
    const state = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
    if (typeof state.predicate !== "string" || state.predicate.length === 0 || state.predicate.includes("\0")) process.exit(1);
    process.stdout.write(state.predicate);
  ' "$state_file" 2>/dev/null); then
    echo "invalid"; return 2
  fi

  screen-cmd "$pred"
}

case "${1:-}" in
  classify)               shift; classify               "$@" ;;
  next-hop)               shift; next-hop               "$@" ;;
  units)                  shift; units                  "$@" ;;
  plateau)                shift; plateau                "$@" ;;
  screen-cmd)             shift; screen-cmd             "$@" ;;
  verdict)                shift; verdict                "$@" ;;
  validate-state)         shift; validate-state         "$@" ;;
  screen-state-predicate) shift; screen-state-predicate "$@" ;;
  *) echo "usage: $0 {classify|next-hop|units|plateau|screen-cmd|verdict|validate-state|screen-state-predicate}" >&2; exit 64 ;;
esac
