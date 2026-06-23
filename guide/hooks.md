# Hooks Reference

Autoresearch v2.1.1 ships 9 hooks that fire automatically on every Claude Code session. Three categories: safety gates, context injection, and quality + notifications.

## How Hooks Work

Hooks are Node.js scripts that intercept Claude Code events. They read JSON from stdin, make a decision, and write JSON to stdout with an exit code:
- **Exit 0** — allow (optionally inject context)
- **Exit 2** — block (with error message)

All hooks follow a fail-open design: if a hook crashes, it exits 0 and never blocks your work.

## Safety Gates (PreToolUse)

These fire on every tool call (Read, Edit, Write, Bash, Glob, Grep).

### scout-block

Blocks file access to directories that waste context tokens.

**Default blocked patterns:**
- `node_modules/`, `__pycache__/`, `.git/`, `dist/`, `build/`, `out/`
- `coverage/`, `.next/`, `.nuxt/`, `venv/`, `.venv/`, `env/`
- `.terraform/`, `.aws/`, `.ssh/`, `*.log`

**Bash handling:** Smart argument parsing — only blocks actual file path arguments, not string literals that mention blocked patterns.

**Build tool allowlist:** Commands starting with `npm`, `yarn`, `pnpm`, `bun`, `pip`, `cargo`, `go`, `rustc`, `make`, `cmake`, `mvn`, `gradle`, `docker`, `kubectl`, `terraform`, `helm`, `python`, `node` bypass blocking entirely.

**Custom patterns:** Create a `.ckignore` file at your project root using gitignore syntax:

```
# Block additional directories
vendor/
.cache/
*.tmp

# Allow a specific subdirectory
!dist/production/
```

**Disable:** `export AR_DISABLE_SCOUT_BLOCK=1`

### privacy-block

Blocks access to files that may contain secrets.

**Blocked:** `.env`, `.env.local`, `.env.production`, `.pem`, `.key`, `.p12`, `id_rsa`, `id_ed25519`, `.ssh/`, `credentials.json`, `credentials.yaml`, `.aws/credentials`

**Allowed exceptions:** `.env.example`, `.env.sample`, `.env.template`, `.env.test`

**Approval flow:**
1. Hook blocks the read with a message
2. Claude asks you for permission via AskUserQuestion
3. You approve
4. Claude retries with `APPROVED:` prefix on the file path
5. Hook allows the read and strips the prefix

**Bash:** Warn only (injects a context warning but doesn't block).

**Disable:** `export AR_DISABLE_PRIVACY_BLOCK=1`

### dangerous-cmd-block

Blocks destructive bash commands.

**Blocked:**
- `git push --force`, `git push -f` (regular `git push` is allowed)
- `git reset --hard`
- `git clean -f`, `git clean -fd`
- `git branch -D`
- `git checkout .`, `git restore .`
- `rm -rf /`, `rm -rf ~`, `rm -rf .`

**Disable:** `export AR_DISABLE_DANGEROUS_CMD_BLOCK=1`

## Context Injection (UserPromptSubmit / SubagentStart)

These inject helpful context to maintain awareness across long sessions.

### iteration-context

Injects recent TSV iteration data every 5th prompt.

**What it injects:** Last 3 rows from the most recently modified TSV file in `autoresearch/*/`. Includes header, iteration count, and metric values.

**Throttle:** Every 5th prompt only. Skips silently on other prompts.

**Why it matters:** After context compaction in long loops, Claude forgets what iteration it's on, what worked, and what the metric direction is. This hook restores that awareness.

**Disable:** `export AR_DISABLE_ITERATION_CONTEXT=1`

### subagent-context

Injects ~150 tokens of loop context when subagents spawn.

**What it injects:** Project root, git branch, plans path, reports path, active TSV path, iteration count, and latest metric value.

**When:** Only when an active TSV exists (autoresearch loop running). Silent otherwise.

**Disable:** `export AR_DISABLE_SUBAGENT_CONTEXT=1`

### dev-rules-reminder

Re-injects plan path and code standards path after compaction.

**What it injects:** Active plan directory + reminder to follow `docs/code-standards.md`.

**Throttle:** Same 5th-iteration cadence. Skips if iteration-context already fired this turn.

**Disable:** `export AR_DISABLE_DEV_RULES_REMINDER=1`

## Quality + Notifications

### simplify-gate

Warns or blocks when you try to ship too many changed lines.

**Verbs detected:** `ship`, `merge`, `deploy`, `pr`, `publish`, `release`

**Negation aware:** Ignores "don't ship", "never deploy", "not ready to merge", etc.

**Thresholds:**
- Under 400 LOC → pass silently
- 400–800 LOC → warning injected as context
- Over 800 LOC → blocked (exit 2) with override hint

**Disable:** `export AR_DISABLE_SIMPLIFY_GATE=1`

### session-init

Sets up project context at the start of every session.

**What it does:**
- Detects git root and current branch
- Creates session state file (`/tmp/ar-session-{hash}.json`)
- Cleans up stale session files older than 24 hours
- Injects project root, branch, plans path, and reports path

**Disable:** `export AR_DISABLE_SESSION_INIT=1`

### stop-notify

Sends a notification when a session ends.

**Terminal:** Always sends an OSC 777 notification (supported by iTerm2, WezTerm, and other modern terminals).

**Webhook:** If `AR_NOTIFY_WEBHOOK` is set, POSTs a JSON payload:

```json
{
  "text": "autoresearch session completed",
  "project": "my-project",
  "branch": "main",
  "duration": "47m 12s",
  "tsv_summary": "25 iterations, metric: 3.2"
}
```

Works with Slack, Discord, and any webhook that accepts JSON POST.

**Disable:** `export AR_DISABLE_STOP_NOTIFY=1`

## Environment Variables

| Variable | Purpose | Default |
|----------|---------|---------|
| `AR_DISABLE_{HOOK_NAME}` | Disable a specific hook (e.g., `AR_DISABLE_SCOUT_BLOCK=1`) | unset (enabled) |
| `AR_NOTIFY_WEBHOOK` | Webhook URL for session completion notifications | unset (no webhook) |

## Session State

All hooks share state via `/tmp/ar-session-{hash}.json`. The hash is derived from your project directory and session ID. Fields:

- `projectRoot` — git root or cwd
- `plansPath` — plans/ directory
- `reportsPath` — plans/reports/ directory
- `gitBranch` — current branch
- `iterationCount` — prompts seen this session
- `startedAt` — session start timestamp
- `lastContextInjection` — when iteration-context last fired

The file is created by session-init and cleaned up by stop-notify.

## Runtime Logs

Hooks append one diagnostic JSON line per event (block / inject / skip decisions) to a per-project log under your **global** home directory, never inside the project repo:

```
~/.claude/hooks/.logs/{project-name}-{hash}/hook-log.jsonl
```

The directory is keyed by the project's working directory, so logs from every repo stay separated yet out of the repos themselves — nothing lands in a project's `.claude/` and nothing can be accidentally committed. Logging is fail-open (a write error never blocks a hook) and write-only (no part of autoresearch reads these back; they exist purely for debugging hook behavior). Safe to delete anytime.

Records from the safety-gate hooks (`dangerous-cmd-block`, `privacy-block`, `scout-block`) may include the blocked command text or file path, so treat `~/.claude/hooks/.logs/` as mildly sensitive — it stays on your own machine and is never written into a repo, but don't share it wholesale.

## File Structure

```
.claude/hooks/autoresearch/
├── hooks.json              # Hook registration (auto-loaded by Claude Code)
├── node-hook-runner.sh     # Shell wrapper for clean Node.js execution
├── .ckignore               # Baseline blocked patterns
├── lib/
│   ├── ar-hook-utils.cjs   # Shared utilities
│   └── ignore.cjs          # Vendored gitignore pattern matcher
├── scout-block.cjs         # Directory access blocker
├── privacy-block.cjs       # Sensitive file protector
├── dangerous-cmd-block.cjs # Destructive command blocker
├── iteration-context.cjs   # TSV state injector
├── subagent-context.cjs    # Subagent context provider
├── dev-rules-reminder.cjs  # Post-compaction rule reminder
├── simplify-gate.cjs       # Shipping LOC gate
├── session-init.cjs        # Session state initializer
└── stop-notify.cjs         # Session end notifier
```
