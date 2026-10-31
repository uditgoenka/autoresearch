#!/usr/bin/env bash
# Tests for the pi extension guardrails — the TypeScript ports of the Claude hooks.
#
# These exercise the pure-logic functions exported by pi-extension/src/ (shell
# tokenizer, ignore matcher, dangerous-cmd-block, scout-block, privacy-block,
# simplify-gate, iteration-context) via tsx, mirroring the behaviors asserted
# in test-hooks.sh for the Claude .cjs hooks. They do NOT spin up a pi session.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PI_EXT="$REPO_ROOT/pi-extension"

# The shell running the suite must not change the results.
while IFS= read -r name; do unset "$name"; done < <(compgen -e | grep '^AR_DISABLE_' || true)

PASS=0
FAIL=0
TOTAL=0

# Resolve a tsx binary (bundled with pi-coding-agent's node_modules if available,
# else npx). tsx transpiles TS on the fly like pi's jiti loader.
TSX=""
if [[ -x "$REPO_ROOT/node_modules/.bin/tsx" ]]; then
  TSX="$REPO_ROOT/node_modules/.bin/tsx"
elif command -v tsx >/dev/null 2>&1; then
  TSX="tsx"
else
  # Fall back to npx (cached). Pinned to avoid network on every run.
  TSX="npx -y tsx@4"
fi

# Run a TS test snippet that imports from the extension and prints a single
# line: "PASS" or "FAIL: <reason>". The snippet must call process.exit with 0/1.
run_case() {
  local label="$1"
  local code="$2"
  TOTAL=$((TOTAL + 1))
  local result
  result=$(printf '%s' "$code" | (cd "$PI_EXT" && $TSX -e "$(cat)" 2>&1) ) || true
  if [[ "$result" == "PASS" ]]; then
    printf '  PASS: %s\n' "$label"
    PASS=$((PASS + 1))
  else
    printf '  FAIL: %s — %s\n' "$label" "$result"
    FAIL=$((FAIL + 1))
  fi
}

# Convenience: assert a JS expression is truthy. The expression runs in a module
# that imports the named symbols.
ok() {
  local label="$1"
  local imports="$2"
  local expr="$3"
  run_case "$label" "
import { $imports } from \"./src/lib/shell.ts\"; // placeholder, replaced below
"
  # The above placeholder approach is awkward; use a direct inline module instead.
}

# We use a cleaner pattern: each case is a self-contained inline TS program.
case_ok() {
  local label="$1"
  local program="$2"
  TOTAL=$((TOTAL + 1))
  local result
  result=$(printf '%s' "$program" | (cd "$PI_EXT" && $TSX --eval "$program" 2>&1)) || true
  if [[ "$result" == "PASS" ]]; then
    printf '  PASS: %s\n' "$label"
    PASS=$((PASS + 1))
  else
    printf '  FAIL: %s — %s\n' "$label" "$result"
    FAIL=$((FAIL + 1))
  fi
}

# ============================================================================
printf '\n--- Testing shell tokenizer (shell.ts) ---\n'
# ============================================================================

case_ok "shellSegments: git push -f" '
import { shellSegments } from "./src/lib/shell.ts";
const s = shellSegments("git push -f origin master")[0].join(" ");
process.stdout.write(s === "git push -f origin master" ? "PASS" : "FAIL: " + s);
'

case_ok "shellSegments: sudo rm unwraps" '
import { shellSegments } from "./src/lib/shell.ts";
const s = shellSegments("sudo rm -rf /tmp/x")[0].join(" ");
process.stdout.write(s === "rm -rf /tmp/x" ? "PASS" : "FAIL: " + s);
'

case_ok "shellSegments: env VAR=1 unwraps" '
import { shellSegments } from "./src/lib/shell.ts";
const s = shellSegments("env FOO=bar node x.js")[0].join(" ");
process.stdout.write(s === "node x.js" ? "PASS" : "FAIL: " + s);
'

case_ok "shellSegments: sh -c nested" '
import { shellSegments } from "./src/lib/shell.ts";
const segs = shellSegments("bash -c \x27git reset --hard\x27");
const s = segs[1] && segs[1].join(" ");
process.stdout.write(s === "git reset --hard" ? "PASS" : "FAIL: " + s);
'

case_ok "shellSegments: command substitution inspected" '
import { shellSegments } from "./src/lib/shell.ts";
const segs = shellSegments("echo $(git push -f)");
process.stdout.write(segs.length >= 1 ? "PASS" : "FAIL: no segments");
'

# ============================================================================
printf '\n--- Testing dangerous-cmd-block ---\n'
# ============================================================================

case_ok "dangerous: blocks git push --force" '
import { commandLabel } from "./src/hooks/dangerous-cmd-block.ts";
const r = commandLabel("git push --force");
process.stdout.write(r === "forced git push" ? "PASS" : "FAIL: " + r);
'

case_ok "dangerous: blocks git push -f" '
import { commandLabel } from "./src/hooks/dangerous-cmd-block.ts";
const r = commandLabel("git push -f origin main");
process.stdout.write(r === "forced git push" ? "PASS" : "FAIL: " + r);
'

case_ok "dangerous: allows regular git push" '
import { commandLabel } from "./src/hooks/dangerous-cmd-block.ts";
const r = commandLabel("git push origin main");
process.stdout.write(r === null ? "PASS" : "FAIL: " + r);
'

case_ok "dangerous: blocks git reset --hard" '
import { commandLabel } from "./src/hooks/dangerous-cmd-block.ts";
const r = commandLabel("git reset --hard HEAD~1");
process.stdout.write(r === "hard git reset" ? "PASS" : "FAIL: " + r);
'

case_ok "dangerous: blocks rm -rf" '
import { commandLabel } from "./src/hooks/dangerous-cmd-block.ts";
const r = commandLabel("rm -rf /");
process.stdout.write(r === "recursive forced removal" ? "PASS" : "FAIL: " + r);
'

case_ok "shell: a command after a <<- heredoc is still parsed" '
import { commandLabel } from "./src/hooks/dangerous-cmd-block.ts";
const r = commandLabel("cat <<-EOF\n\tbody\n\tEOF\nrm -rf /");
process.stdout.write(r === "recursive forced removal" ? "PASS" : "FAIL: " + r);
'

case_ok "dangerous: an f inside a long rm option is not --force" '
import { commandLabel } from "./src/hooks/dangerous-cmd-block.ts";
const a = commandLabel("rm -r --one-file-system build");
const b = commandLabel("rm --recursive --force build");
const c = commandLabel("rm --recur --forc build");
process.stdout.write(a === null && b === "recursive forced removal" && c === b ? "PASS" : "FAIL: " + a + " / " + b + " / " + c);
'

case_ok "ignore: trailing-slash dirs match at any depth, regex characters are literal" '
import { ignore } from "./src/lib/ignore.ts";
const r = [ignore().add("node_modules/").ignores("pkg/node_modules/x"), ignore().add("src/gen/").ignores("x/src/gen/y"), ignore().add("a+b.txt").ignores("aab.txt"), ignore().add("*.[oa]").ignores("lib.o"), ignore().add("*.[oa]").ignores("lib.c"), ignore().add("*.[!o]").ignores("lib.o"), ignore().add("*.[!o]").ignores("lib.c"), ignore().add("a[!o]b").ignores("a/b"), ignore().add(["[z-a]", "*.log"]).ignores("x.log"), ignore().add(["foo[", "tail\\\\", "*.log"]).ignores("foo["), ignore().add(["foo[", "*.log"]).ignores("x.log")].join(",");
process.stdout.write(r === "true,false,false,true,false,false,true,false,true,true,true" ? "PASS" : "FAIL: " + r);
'

case_ok "stop-notify: Unicode single quotes are doubled in the toast script" '
import { windowsToastScript } from "./src/hooks/stop-notify.ts";
const s = windowsToastScript("t", "it\u2019s done");
const doubled = "it" + String.fromCharCode(39).repeat(2) + "s done";
process.stdout.write(s.includes(doubled) && !s.includes("\u2019") ? "PASS" : "FAIL: " + s);
'

case_ok "dangerous: blocks git clean -f" '
import { commandLabel } from "./src/hooks/dangerous-cmd-block.ts";
const r = commandLabel("git clean -f");
process.stdout.write(r === "forced git clean" ? "PASS" : "FAIL: " + r);
'

case_ok "dangerous: blocks git branch -D" '
import { commandLabel } from "./src/hooks/dangerous-cmd-block.ts";
const r = commandLabel("git branch -D feature");
process.stdout.write(r === "forced branch deletion" ? "PASS" : "FAIL: " + r);
'

case_ok "dangerous: blocks git checkout ." '
import { commandLabel } from "./src/hooks/dangerous-cmd-block.ts";
const r = commandLabel("git checkout . ");
process.stdout.write(r === "git checkout of working tree" ? "PASS" : "FAIL: " + r);
'

case_ok "dangerous: allows git status" '
import { commandLabel } from "./src/hooks/dangerous-cmd-block.ts";
const r = commandLabel("git status");
process.stdout.write(r === null ? "PASS" : "FAIL: " + r);
'

case_ok "dangerous: allows force-with-lease" '
import { commandLabel } from "./src/hooks/dangerous-cmd-block.ts";
const r = commandLabel("git push origin main --force-with-lease --force-if-includes");
process.stdout.write(r === null ? "PASS" : "FAIL: " + r);
'

case_ok "dangerous: blocks +refspec and bundled -f pushes" '
import { commandLabel } from "./src/hooks/dangerous-cmd-block.ts";
const a = commandLabel("git push origin +main");
const b = commandLabel("git push -fu origin main");
process.stdout.write(a === "forced git push" && b === "forced git push" ? "PASS" : "FAIL: " + a + " " + b);
'

case_ok "dangerous: harmless echoed text allowed" '
import { commandLabel } from "./src/hooks/dangerous-cmd-block.ts";
const r = commandLabel("echo rm -rf /");
process.stdout.write(r === null ? "PASS" : "FAIL: " + r);
'

case_ok "dangerous: sudo wrapper cannot hide hard reset" '
import { commandLabel } from "./src/hooks/dangerous-cmd-block.ts";
const r = commandLabel("sudo git reset --hard HEAD");
process.stdout.write(r === "hard git reset" ? "PASS" : "FAIL: " + r);
'

case_ok "dangerous: comment text not executed" '
import { commandLabel } from "./src/hooks/dangerous-cmd-block.ts";
const r = commandLabel("true # ; git reset --hard HEAD");
process.stdout.write(r === null ? "PASS" : "FAIL: " + r);
'

case_ok "dangerous: checkDangerousCommand block result" '
import { checkDangerousCommand } from "./src/hooks/dangerous-cmd-block.ts";
const r = checkDangerousCommand("git push -f origin master");
process.stdout.write(r.block === true ? "PASS" : "FAIL: not blocked");
'

case_ok "dangerous: disabled via env var" '
delete process.env.AR_DISABLE_DANGEROUS_CMD_BLOCK;
process.env.AR_DISABLE_DANGEROUS_CMD_BLOCK = "1";
import { checkDangerousCommand } from "./src/hooks/dangerous-cmd-block.ts";
const r = checkDangerousCommand("git push -f origin master");
process.stdout.write(r.block ? "FAIL: still blocked when disabled" : "PASS");
'

# ============================================================================
printf '\n--- Testing ignore matcher (ignore.ts) ---\n'
# ============================================================================

case_ok "ignore: node_modules ignored" '
import { ignore } from "./src/lib/ignore.ts";
const ig = ignore().add(["node_modules/", "*.log"]);
process.stdout.write(ig.ignores("node_modules/foo.js") ? "PASS" : "FAIL");
'

case_ok "ignore: *.log ignored" '
import { ignore } from "./src/lib/ignore.ts";
const ig = ignore().add(["*.log"]);
process.stdout.write(ig.ignores("debug.log") ? "PASS" : "FAIL");
'

case_ok "ignore: negation un-ignores" '
import { ignore } from "./src/lib/ignore.ts";
const ig = ignore().add(["node_modules/", "!node_modules/keep/"]);
process.stdout.write(!ig.ignores("node_modules/keep/x.js") ? "PASS" : "FAIL");
'

case_ok "ignore: src allowed" '
import { ignore } from "./src/lib/ignore.ts";
const ig = ignore().add(["node_modules/"]);
process.stdout.write(!ig.ignores("src/index.ts") ? "PASS" : "FAIL");
'

# ============================================================================
printf '\n--- Testing scout-block (.ckignore) ---\n'
# ============================================================================

case_ok "scout: blocks node_modules Read" '
import { checkStructuredPath } from "./src/hooks/scout-block.ts";
const r = checkStructuredPath("node_modules/express/index.js", "/tmp");
process.stdout.write(r.block === true ? "PASS" : "FAIL");
'

case_ok "scout: allows normal file Read" '
import { checkStructuredPath } from "./src/hooks/scout-block.ts";
const r = checkStructuredPath("src/main.ts", "/tmp");
process.stdout.write(!r.block ? "PASS" : "FAIL: blocked");
'

case_ok "scout: blocks .git access" '
import { checkStructuredPath } from "./src/hooks/scout-block.ts";
const r = checkStructuredPath(".git/config", "/tmp");
process.stdout.write(r.block === true ? "PASS" : "FAIL");
'

case_ok "scout: blocks Bash with node_modules path" '
import { checkBashCommand } from "./src/hooks/scout-block.ts";
const r = checkBashCommand("cat node_modules/foo/bar.js", "/tmp");
process.stdout.write(r.block === true ? "PASS" : "FAIL");
'

case_ok "scout: allows build tool (npm)" '
import { checkBashCommand } from "./src/hooks/scout-block.ts";
const r = checkBashCommand("npm test", "/tmp");
process.stdout.write(!r.block ? "PASS" : "FAIL: blocked");
'

case_ok "scout: bash string literal false-positive prevention" '
import { checkBashCommand } from "./src/hooks/scout-block.ts";
const r = checkBashCommand("echo \x27testing node_modules string\x27", "/tmp");
process.stdout.write(!r.block ? "PASS" : "FAIL: blocked");
'

case_ok "scout: remote ssh path not local" '
import { checkBashCommand } from "./src/hooks/scout-block.ts";
const r = checkBashCommand("ssh deploy@prod cat node_modules/server.js", "/tmp");
process.stdout.write(!r.block ? "PASS" : "FAIL: blocked remote");
'

case_ok "scout: disabled via env var" '
process.env.AR_DISABLE_SCOUT_BLOCK = "1";
import { checkBashCommand } from "./src/hooks/scout-block.ts";
const r = checkBashCommand("cat node_modules/foo.js", "/tmp");
process.stdout.write(!r.block ? "PASS" : "FAIL: still blocked");
'

# ============================================================================
printf '\n--- Testing privacy-block (sensitive files) ---\n'
# ============================================================================

case_ok "privacy: .env sensitive" '
import { isSensitive } from "./src/lib/paths.ts";
process.stdout.write(isSensitive(".env") ? "PASS" : "FAIL");
'

case_ok "privacy: .env.example allowed" '
import { isSensitive } from "./src/lib/paths.ts";
process.stdout.write(!isSensitive(".env.example") ? "PASS" : "FAIL");
'

case_ok "privacy: id_rsa sensitive" '
import { isSensitive } from "./src/lib/paths.ts";
process.stdout.write(isSensitive("~/.ssh/id_rsa") ? "PASS" : "FAIL");
'

case_ok "privacy: credentials.json sensitive" '
import { isSensitive } from "./src/lib/paths.ts";
process.stdout.write(isSensitive("credentials.json") ? "PASS" : "FAIL");
'

case_ok "privacy: src normal" '
import { isSensitive } from "./src/lib/paths.ts";
process.stdout.write(!isSensitive("src/index.ts") ? "PASS" : "FAIL");
'

case_ok "privacy: cat .env is clear" '
import { bashSensitivity } from "./src/lib/paths.ts";
const r = bashSensitivity("cat .env");
process.stdout.write(r === "clear" ? "PASS" : "FAIL: " + r);
'

case_ok "privacy: echo src none" '
import { bashSensitivity } from "./src/lib/paths.ts";
const r = bashSensitivity("echo src/index.ts");
process.stdout.write(r === "none" ? "PASS" : "FAIL: " + r);
'

case_ok "privacy: checkStructuredSensitive needsConfirm" '
import { checkStructuredSensitive } from "./src/hooks/privacy-block.ts";
const r = checkStructuredSensitive(".env");
process.stdout.write(r.needsConfirm === true ? "PASS" : "FAIL");
'

case_ok "privacy: disabled via env var" '
process.env.AR_DISABLE_PRIVACY_BLOCK = "1";
import { checkStructuredSensitive } from "./src/hooks/privacy-block.ts";
const r = checkStructuredSensitive(".env");
process.stdout.write(!r.needsConfirm ? "PASS" : "FAIL: still asking");
'

# ============================================================================
printf '\n--- Testing simplify-gate ---\n'
# ============================================================================

# simplify-gate needs a git repo to count LOC. Build a throwaway repo.
GATE_REPO="$(mktemp -d)"
# Every temp repo is removed on exit, even when a case fails early.
trap 'rm -rf "$GATE_REPO" "${ITER_REPO:-}" "${SUB_REPO:-}"' EXIT
( cd "$GATE_REPO" && git init -q && git config user.name t && git config user.email t@x && printf "x\n" > a.txt && git add a.txt && git commit -qm init ) >/dev/null 2>&1

case_ok "simplify-gate: no shipping verb allows" "
import { checkSimplifyGate } from \"./src/hooks/simplify-gate.ts\";
const r = checkSimplifyGate('fix the bug', '$GATE_REPO');
process.stdout.write(!r.block ? 'PASS' : 'FAIL: blocked');
"

case_ok "simplify-gate: small diff allows shipping" "
import { checkSimplifyGate } from \"./src/hooks/simplify-gate.ts\";
const r = checkSimplifyGate('ship this', '$GATE_REPO');
process.stdout.write(!r.block ? 'PASS' : 'FAIL: blocked');
"

case_ok "simplify-gate: negation phrase allows" "
import { checkSimplifyGate } from \"./src/hooks/simplify-gate.ts\";
const r = checkSimplifyGate(\"don't ship yet\", '$GATE_REPO');
process.stdout.write(!r.block ? 'PASS' : 'FAIL: blocked');
"

case_ok "simplify-gate: large diff blocks" "
import { checkSimplifyGate } from \"./src/hooks/simplify-gate.ts\";
const fs = require('fs');
// Append 811 lines to a TRACKED file so git diff HEAD --numstat (cwd-aware) counts them.
fs.appendFileSync('$GATE_REPO/a.txt', '\\n' + Array(811).fill('b').join('\\n'));
const r = checkSimplifyGate('release now', '$GATE_REPO');
process.stdout.write(r.block === true ? 'PASS' : 'FAIL: not blocked');
"

case_ok "simplify-gate: disabled via env var" "
process.env.AR_DISABLE_SIMPLIFY_GATE = '1';
import { checkSimplifyGate } from \"./src/hooks/simplify-gate.ts\";
const r = checkSimplifyGate('ship this', '$GATE_REPO');
process.stdout.write(!r.block ? 'PASS' : 'FAIL: still blocked');
"

# ============================================================================
printf '\n--- Testing iteration-context ---\n'
# ============================================================================

ITER_REPO="$(mktemp -d)"
( cd "$ITER_REPO" && mkdir -p autoresearch/run001 && printf 'iteration\tstatus\tmetric\n1\tpass\t0.85\n2\tpass\t0.87\n3\tpass\t0.88\n' > autoresearch/run001/results.tsv ) >/dev/null 2>&1

case_ok "iteration-context: skips before 5th" "
import { buildIterationContext } from \"./src/hooks/iteration-context.ts\";
const r = buildIterationContext('$ITER_REPO', 'sess-skip', 'fix the bug');
process.stdout.write(r.text === null ? 'PASS' : 'FAIL: injected early');
"

case_ok "iteration-context: injects on 5th" "
import { buildIterationContext } from \"./src/hooks/iteration-context.ts\";
// advance the counter to 4 first
for (let i=0;i<4;i++) buildIterationContext('$ITER_REPO', 'sess-inject', 'x');
const r = buildIterationContext('$ITER_REPO', 'sess-inject', 'autoresearch loop');
process.stdout.write(r.text && r.text.includes('Active iteration state') ? 'PASS' : 'FAIL: ' + (r.text||'null'));
"

case_ok "iteration-context: loop state for AR commands" "
import { buildIterationContext } from \"./src/hooks/iteration-context.ts\";
for (let i=0;i<9;i++) buildIterationContext('$ITER_REPO', 'sess-loop', 'x');
const r = buildIterationContext('$ITER_REPO', 'sess-loop', 'autoresearch: loop over scenarios');
process.stdout.write(r.text && r.text.includes('Loop state') ? 'PASS' : 'FAIL: ' + (r.text||'null'));
"

case_ok "iteration-context: disabled via env var" "
process.env.AR_DISABLE_ITERATION_CONTEXT = '1';
import { buildIterationContext } from \"./src/hooks/iteration-context.ts\";
const r = buildIterationContext('$ITER_REPO', 'sess-disabled', 'x');
process.stdout.write(r.text === null ? 'PASS' : 'FAIL: still injecting');
"

rm -rf "$ITER_REPO"

# ============================================================================
printf '\n--- Testing isHookEnabled env flags ---\n'
# ============================================================================

case_ok "isHookEnabled: enabled by default" '
import { isHookEnabled } from "./src/lib/session-state.ts";
delete process.env.AR_DISABLE_SCOUT_BLOCK;
process.stdout.write(isHookEnabled("scout-block") ? "PASS" : "FAIL");
'

case_ok "isHookEnabled: disabled by env" '
import { isHookEnabled } from "./src/lib/session-state.ts";
process.env.AR_DISABLE_SCOUT_BLOCK = "1";
process.stdout.write(!isHookEnabled("scout-block") ? "PASS" : "FAIL");
'

# ============================================================================
printf '\n--- Testing subagent-context ---\n'
# ============================================================================

SUB_REPO="$(mktemp -d)"
( cd "$SUB_REPO" && mkdir -p autoresearch/run001 && printf 'iteration\tstatus\tmetric\n1\tpass\t0.85\n2\tpass\t0.87\n' > autoresearch/run001/results.tsv ) >/dev/null 2>&1

case_ok "subagent-context: isSubagentChild detects PI_SUBAGENT_CHILD" '
import { isSubagentChild } from "./src/hooks/subagent-context.ts";
process.env.PI_SUBAGENT_CHILD = "1";
process.stdout.write(isSubagentChild() ? "PASS" : "FAIL");
'

case_ok "subagent-context: no TSV returns null" '
import { buildSubagentContext } from "./src/hooks/subagent-context.ts";
const r = buildSubagentContext("/nonexistent-cwd-12345", "sess-no-tsv");
process.stdout.write(r.text === null ? "PASS" : "FAIL: " + r.text);
'

case_ok "subagent-context: with active TSV injects header" "
import { buildSubagentContext } from \"./src/hooks/subagent-context.ts\";
const r = buildSubagentContext('$SUB_REPO', 'sess-sub');
process.stdout.write(r.text && r.text.includes('Autoresearch context (for subagent)') ? 'PASS' : 'FAIL: ' + (r.text||'null'));
"

case_ok "subagent-context: contains TSV path + iteration" "
import { buildSubagentContext } from \"./src/hooks/subagent-context.ts\";
const r = buildSubagentContext('$SUB_REPO', 'sess-sub2');
process.stdout.write(r.text && r.text.includes('Active TSV:') && r.text.includes('Iteration:') ? 'PASS' : 'FAIL: ' + (r.text||'null'));
"

case_ok "subagent-context: disabled via env var" "
process.env.AR_DISABLE_SUBAGENT_CONTEXT = '1';
import { buildSubagentContext } from \"./src/hooks/subagent-context.ts\";
const r = buildSubagentContext('$SUB_REPO', 'sess-disabled');
process.stdout.write(r.text === null ? 'PASS' : 'FAIL: still injecting');
"

rm -rf "$SUB_REPO"

# ============================================================================
# ============================================================================
printf '\n--- Testing run gating ---\n'
# ============================================================================
GATE_CWD="$(mktemp -d)"

case_ok "run gating: inactive session, no TSV" "
import { isRunActive } from \"./src/lib/session-state.ts\";
process.stdout.write(!isRunActive('$GATE_CWD', 'gate-a', 'fix the bug') ? 'PASS' : 'FAIL: active');
"

case_ok "run gating: invoking prompts activate" "
import { promptInvokesRun } from \"./src/lib/session-state.ts\";
const ok = ['/autoresearch go', '/autoresearch_debug x', '/autoresearch:debug x', '\$autoresearch plan', '/skill:autoresearch']
  .every((p) => promptInvokesRun(p)) && !promptInvokesRun('see docs/autoresearch.md') && !promptInvokesRun('/autoresearchx');
process.stdout.write(ok ? 'PASS' : 'FAIL');
"

case_ok "run gating: reading the skill file marks the run" "
import { isRunActive, markRunActive, readsRunSkill } from \"./src/lib/session-state.ts\";
const ok = readsRunSkill('/x/skills/autoresearch/SKILL.md') && !readsRunSkill('/x/skills/other/SKILL.md');
markRunActive('$GATE_CWD', 'gate-b');
process.stdout.write(ok && isRunActive('$GATE_CWD', 'gate-b') && !isRunActive('$GATE_CWD', 'gate-c') ? 'PASS' : 'FAIL');
"

case_ok "run gating: a recent results TSV activates" "
const fs = require('fs');
fs.mkdirSync('$GATE_CWD/autoresearch/run-1', { recursive: true });
fs.writeFileSync('$GATE_CWD/autoresearch/run-1/results.tsv', 'iteration\\tmetric\\n');
import { isRunActive } from \"./src/lib/session-state.ts\";
process.stdout.write(isRunActive('$GATE_CWD', 'gate-d') ? 'PASS' : 'FAIL');
"

case_ok "simplify-gate: untracked binaries are skipped" "
import { checkSimplifyGate } from \"./src/hooks/simplify-gate.ts\";
const fs = require('fs');
const dir = fs.mkdtempSync(require('os').tmpdir() + '/pi-bin-');
require('child_process').execSync('git init -q && git config user.name t && git config user.email t@x && git commit -q --allow-empty -m init', { cwd: dir });
fs.writeFileSync(dir + '/blob.bin', Buffer.concat([Buffer.from([0]), Buffer.from('\\n'.repeat(900))]));
const r = checkSimplifyGate('ship it', dir);
fs.rmSync(dir, { recursive: true, force: true });
process.stdout.write(!r.block ? 'PASS' : 'FAIL: blocked');
"

case_ok "session-state: a corrupt state file starts fresh" '
import { loadSessionState, sessionStatePath, cleanupSessionFile } from "./src/lib/session-state.ts";
const fs = require("fs");
fs.writeFileSync(sessionStatePath("/tmp/pi-corrupt", "corrupt"), "{not json");
const r = loadSessionState("/tmp/pi-corrupt", "corrupt");
cleanupSessionFile("/tmp/pi-corrupt", "corrupt");
process.stdout.write(r.sessionId === "corrupt" ? "PASS" : "FAIL: " + JSON.stringify(r));
'

# Type-check: the extension must compile clean against pi types.
# ============================================================================
printf '\n--- Testing TypeScript type-check ---\n'
TOTAL=$((TOTAL + 1))
PI_NODE="$(cd "$PI_EXT" && npm root -g 2>/dev/null)/@earendil-works/pi-coding-agent"
if [[ ! -d "$PI_NODE" ]] && command -v pi >/dev/null 2>&1; then
  # Walk up from the real pi binary to its package root (nvm, Homebrew, ...).
  PI_NODE="$(dirname "$(readlink -f "$(command -v pi)")")"
  while [[ "$PI_NODE" != "/" && "$(basename "$PI_NODE")" != "pi-coding-agent" ]]; do PI_NODE="$(dirname "$PI_NODE")"; done
fi
if [[ ! -d "$PI_NODE" || "$(basename "$PI_NODE")" != "pi-coding-agent" ]]; then
  printf '  SKIP: pi-coding-agent types not found (non-pi environment)\n'
  TOTAL=$((TOTAL - 1))
else
  # Symlink pi's types into the extension's own node_modules so tsc's
  # upward module resolution (src -> pi-extension/node_modules) finds them.
  NM="$PI_EXT/node_modules"
  NM_EXISTED=0; [[ -e "$NM" ]] && NM_EXISTED=1
  TSC_LOG="$(mktemp)"
  mkdir -p "$NM/@earendil-works"
  ln -sfn "$PI_NODE" "$NM/@earendil-works/pi-coding-agent"
  [[ -d "$PI_NODE/../typebox" ]] && ln -sfn "$PI_NODE/../typebox" "$NM/typebox"
  [[ -d "$PI_NODE/../pi-ai" ]] && ln -sfn "$PI_NODE/../pi-ai" "$NM/@earendil-works/pi-ai"
  printf '{"compilerOptions":{"target":"ES2022","module":"ESNext","moduleResolution":"Bundler","strict":true,"noEmit":true,"skipLibCheck":true,"esModuleInterop":true,"resolveJsonModule":true,"lib":["ES2022"],"types":[]},"include":["src/**/*.ts"]}' > "$PI_EXT/tsconfig.test.json"
  if npx -y -p typescript@5.6 tsc --noEmit -p "$PI_EXT/tsconfig.test.json" >"$TSC_LOG" 2>&1; then
    printf '  PASS: tsc --strict clean\n'
    PASS=$((PASS + 1))
  else
    printf '  FAIL: tsc --strict\n'
    head -20 "$TSC_LOG" >&2
    FAIL=$((FAIL + 1))
  fi
  if [[ $NM_EXISTED -eq 1 ]]; then
    for link in "$NM/@earendil-works/pi-coding-agent" "$NM/@earendil-works/pi-ai" "$NM/typebox"; do
      [[ -L "$link" ]] && rm -f "$link"
    done
  else
    rm -rf "$NM"
  fi
  rm -f "$PI_EXT/tsconfig.test.json" "$TSC_LOG"
fi

# ============================================================================
# Summary
# ============================================================================
printf '\n=== Results: %d/%d passed ===' "$PASS" "$TOTAL"
if [[ "$FAIL" -gt 0 ]]; then
  printf ' (%d FAILED)\n' "$FAIL"
  exit 1
else
  printf ' (all passed)\n'
  exit 0
fi
