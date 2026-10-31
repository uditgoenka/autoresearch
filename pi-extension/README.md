# Autoresearch for pi

Autonomous goal-directed iteration for [pi](https://github.com/earendil-works/pi-coding-agent) — a port of the Claude Code autoresearch plugin to pi's extension system.

One metric, constrained scope, fast verification, automatic rollback, git as memory. Works on **any** domain — code, content, marketing, sales, DevOps — anything with a measurable metric.

**Core loop:** Modify → Verify → Keep/Discard → Repeat.

This package keeps the same spirit as the [Claude Code](../claude-plugin) and [OpenCode](../.opencode) integrations: the 14 commands are markdown protocols (here exposed as pi **prompt templates** + a **skill**), and the safety guardrails are ported from the Claude hooks to pi's **extension events**.

---

## What's in the box

```
pi-extension/
├── package.json              # pi package manifest (declares the extension entry only)
├── src/
│   ├── index.ts              # entry: registers guardrails + resources_discover
│   ├── guardrails.ts         # wires hooks → pi events
│   ├── lib/
│   │   ├── shell.ts          # shell command tokenizer (port of ar-hook-utils)
│   │   ├── ignore.ts         # .ckignore / gitignore matcher (port of ignore.cjs)
│   │   ├── session-state.ts  # per-session state in $TMPDIR + bounded hook log
│   │   ├── tsv.ts            # iteration-results TSV reader
│   │   └── paths.ts          # sensitive-file + .ckignore path helpers
│   └── hooks/
│       ├── dangerous-cmd-block.ts   # blocks force-push, hard reset, rm -rf, …
│       ├── scout-block.ts           # blocks access to .ckignore'd paths
│       ├── privacy-block.ts         # confirms sensitive-file access
│       ├── iteration-context.ts     # injects active iteration TSV every 5th prompt
│       ├── dev-rules-reminder.ts    # injects dev context (plan/standards)
│       ├── simplify-gate.ts         # blocks/warns shipping verbs with too many LOC
│       └── stop-notify.ts           # terminal notification + webhook on shutdown
├── skills/autoresearch/      # SKILL.md + references + orchestrator scripts
└── prompts/                  # 14 command prompt templates (/autoresearch, /autoresearch_debug, …)
```

## Hook → event mapping

| Claude Code hook | pi event | autoresearch hook(s) |
|---|---|---|
| `PreToolUse` (Bash) | `tool_call` (`bash`) | scout-block, privacy-block, dangerous-cmd-block |
| `PreToolUse` (Read/Write/Edit) | `tool_call` (`read`/`write`/`edit`) | scout-block, privacy-block |
| `UserPromptSubmit` | `before_agent_start` | iteration-context, dev-rules-reminder (inject message) |
| `UserPromptSubmit` | `input` | simplify-gate (block/warn shipping verbs) |
| `SessionStart` | `session_start` | session-init (persist project/branch state) |
| `SessionEnd` | `session_shutdown` | stop-notify (notify + webhook + cleanup) |
| `SubagentStart` | `before_agent_start` (child) + `pi.events` (parent) | subagent-context (port of Claude SubagentStart; integrates with pi-subagents) |

Every hook **fails open** — a guardrail malfunction never blocks legitimate work.

> **Note on subagent context:** Claude's `SubagentStart` hook injected iteration state into subagents. pi has no native subagent-spawn event in the extension API, but the widely-used [pi-subagents](https://github.com/earendil-works/pi-subagents) extension emits delegation events on the shared `pi.events` bus, and pi subagents are full pi sessions that load this same extension and fire `before_agent_start`. The `subagent-context` hook uses both: on the **parent** side it listens for `prompt-template:subagent:request` to log launches; on the **child** side (`PI_SUBAGENT_CHILD=1`) it injects the project/branch/active-TSV/iteration block at `before_agent_start` — the direct port of the Claude `SubagentStart` injection. If pi-subagents isn't installed, both paths fail open (no-op).

### Resource contribution

The skill and prompt templates are contributed **only** via the extension's `resources_discover` event (not duplicated in the `package.json` `pi` manifest). Declaring them in both places causes pi to register each resource twice and emit `collision` diagnostics. The manifest declares just the extension entry (`pi.extensions`); `resources_discover` supplies the skill + prompts at runtime. This works for `pi install`, `pi -e ./pi-extension` (dir), and `pi -e ./src/index.ts` (bare file).

> **Skill-name collisions:** if you already have the autoresearch skill installed elsewhere (e.g. a global `~/.pi/agent/skills/autoresearch/` copy, or the repo's own `.agents/skills/autoresearch/`), pi dedupes by name — the extension's copy wins and the others are skipped. The skipped entries show as `collision` diagnostics in the startup banner. To silence them, remove the stale copies you no longer need (the extension bundles its own).

## Commands

The 14 autoresearch commands are exposed as pi **prompt templates** (markdown protocols, invoked via `/name`) and the dispatcher is a pi **skill** (`/skill:autoresearch`):

| Command | Does | Default Iterations |
|---|---|---|
| `/autoresearch` | Iterate against a metric: modify → verify → keep/discard | 25 |
| `/autoresearch_plan` | Convert a goal into validated Scope, Metric, Verify config | N/A |
| `/autoresearch_debug` | Hunt bugs: hypothesize → test → falsify → repeat | 15 |
| `/autoresearch_fix` | Crush errors one-by-one until zero remain | 20 |
| `/autoresearch_security` | STRIDE + OWASP audit with red-team personas | 15 |
| `/autoresearch_ship` | Ship through 8 phases: checklist → dry-run → deploy → verify | N/A |
| `/autoresearch_scenario` | Generate edge cases across 12 dimensions | 20 |
| `/autoresearch_predict` | 5 expert personas debate before implementation | N/A |
| `/autoresearch_learn` | Scout codebase → generate docs or wiki → validate → fix loop | 10 |
| `/autoresearch_reason` | Adversarial debate with blind judges until convergence | 8 |
| `/autoresearch_probe` | 8 personas interrogate requirements until saturation | 15 |
| `/autoresearch_improve` | Research ICP challenges, discover improvements, generate PRDs | 15 |
| `/autoresearch_evals` | Analyze iteration results: trends, plateaus, regressions | N/A |
| `/autoresearch_regression` | Regression stability gate: baseline vs candidate | N/A |

## Install

### From this repo (git)

```bash
pi install git:github.com/uditgoenka/autoresearch
```

The root `package.json` points pi at this extension, so nothing else needs to be set up.

### Try it without installing

```bash
pi -e ./pi-extension
```

### Manual (any pi setup)

Copy this directory into your extensions folder:

```bash
cp -r pi-extension ~/.pi/agent/extensions/autoresearch-pi
```

## Usage

```
/autoresearch
Goal: Increase test coverage from 72% to 90%
Scope: src/**/*.test.ts, src/**/*.ts
Metric: coverage % (higher is better)
Verify: npm test -- --coverage | grep "All files"
Iterations: 50
```

Don't know what metric to use?

```
/autoresearch_plan
Goal: Make the API respond faster
```

## Configuration

Per-hook disable flags (same as the Claude plugin):

| Env var | Disables |
|---|---|
| `AR_DISABLE_SCOUT_BLOCK` | .ckignore path blocking |
| `AR_DISABLE_PRIVACY_BLOCK` | sensitive-file confirmation |
| `AR_DISABLE_DANGEROUS_CMD_BLOCK` | destructive-command blocking |
| `AR_DISABLE_ITERATION_CONTEXT` | iteration TSV injection |
| `AR_DISABLE_DEV_RULES_REMINDER` | dev-context injection |
| `AR_DISABLE_SIMPLIFY_GATE` | LOC shipping gate |
| `AR_DISABLE_SESSION_INIT` | session-state init |
| `AR_DISABLE_STOP_NOTIFY` | session-end notification |
| `AR_NOTIFY_WEBHOOK` | optional webhook URL for session-end notifications |

Runtime logs (bounded metadata only — no paths, commands, or secrets) are written to `~/.pi/agent/autoresearch/.logs/<projectHash>/hook-log.jsonl`.

## License

MIT — see [LICENSE](../LICENSE).
