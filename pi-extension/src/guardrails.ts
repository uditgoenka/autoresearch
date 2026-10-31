// guardrails — wires the ported Claude hooks to pi's extension event system.
//
// Claude event        → pi event              → hooks
// PreToolUse (Bash)   → tool_call "bash"      → scout-block, privacy-block, dangerous-cmd-block
// PreToolUse (R/W/E)  → tool_call read/write  → scout-block, privacy-block
// UserPromptSubmit    → before_agent_start    → iteration-context, dev-rules-reminder (inject message)
// UserPromptSubmit    → input                 → simplify-gate (block/warn shipping verbs)
// SessionStart        → session_start         → session-init (persist state)
// SessionEnd          → session_shutdown      → stop-notify (notify + cleanup)
// SubagentStart       → before_agent_start    → subagent-context (child-side, PI_SUBAGENT_CHILD=1)
//                       + pi.events            → subagent-context (parent-side delegation logging)
//
// All hooks fail open: a guardrail malfunction never blocks legitimate work.

import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { isToolCallEventType } from "@earendil-works/pi-coding-agent";

import { checkDangerousCommand, type DangerousCmdResult } from "./hooks/dangerous-cmd-block.js";
import { checkBashCommand, checkStructuredPath, type ScoutBlockResult } from "./hooks/scout-block.js";
import {
  checkBashSensitive,
  checkStructuredSensitive,
  resolveConfirm,
} from "./hooks/privacy-block.js";
import { buildIterationContext } from "./hooks/iteration-context.js";
import { buildDevRules } from "./hooks/dev-rules-reminder.js";
import { buildSubagentContext, isSubagentChild } from "./hooks/subagent-context.js";
import { checkSimplifyGate, surfaceWarning } from "./hooks/simplify-gate.js";
import { runStopNotify } from "./hooks/stop-notify.js";
import {
  isHookEnabled,
  isRunActive,
  loadSessionState,
  markRunActive,
  promptInvokesRun,
  readsRunSkill,
  log,
  pruneStaleSessionFiles,
  saveSessionState,
} from "./lib/session-state.js";
import { execSync } from "node:child_process";
import { join } from "node:path";

const SESSION_INIT = "session-init";

function resolveGitRoot(cwd: string): string {
  try {
    return execSync("git rev-parse --show-toplevel", {
      encoding: "utf8",
      timeout: 5000,
      cwd,
    }).trim();
  } catch {
    return cwd;
  }
}

function resolveGitBranch(cwd: string): string {
  try {
    return execSync("git rev-parse --abbrev-ref HEAD", {
      encoding: "utf8",
      timeout: 5000,
      cwd,
    }).trim();
  } catch {
    return "";
  }
}

function getSessionId(ctx: ExtensionContext): string {
  return ctx.sessionManager.getSessionId() || "unknown";
}

// session_start → session-init
function onSessionStart(pi: ExtensionAPI): void {
  pi.on("session_start", async (_event, ctx) => {
    if (!isHookEnabled(SESSION_INIT)) return;
    try {
      const cwd = ctx.cwd;
      const sessionId = getSessionId(ctx);
      const projectRoot = resolveGitRoot(cwd);
      const gitBranch = resolveGitBranch(cwd);

      const state = {
        projectRoot,
        plansPath: join(projectRoot, "plans"),
        reportsPath: join(projectRoot, "plans", "reports"),
        gitBranch,
        sessionId,
        iterationCount: 0,
        startedAt: new Date().toISOString(),
        // A resumed session keeps its run flag.
        autoresearchActive: loadSessionState(cwd, sessionId).autoresearchActive || undefined,
      };
      saveSessionState(cwd, sessionId, state);
      pruneStaleSessionFiles();
      log(SESSION_INIT, { projectRoot, gitBranch });
    } catch {
      // fail-open
    }
  });
}

// session_shutdown → stop-notify
function onSessionShutdown(pi: ExtensionAPI): void {
  pi.on("session_shutdown", async (_event, ctx) => {
    const cwd = ctx.cwd;
    const sessionId = getSessionId(ctx);
    await runStopNotify(cwd, sessionId);
  });
}

// tool_call → scout-block + privacy-block + dangerous-cmd-block
function onToolCall(pi: ExtensionAPI): void {
  pi.on("tool_call", async (event, ctx) => {
    const cwd = ctx.cwd;
    const sessionId = getSessionId(ctx);
    // The model reading the autoresearch skill starts a run nobody typed.
    if (isToolCallEventType("read", event) && readsRunSkill(event.input.path as string)) {
      markRunActive(cwd, sessionId);
    }
    const active = isRunActive(cwd, sessionId);

    // --- bash tool ---
    if (isToolCallEventType("bash", event)) {
      const command = event.input.command as string;

      // dangerous-cmd-block (highest priority — hard block)
      const dangerous: DangerousCmdResult = active ? checkDangerousCommand(command) : {};
      if (dangerous.block) {
        if (ctx.hasUI) ctx.ui.notify(dangerous.reason || "Blocked", "error");
        return { block: true, reason: dangerous.reason };
      }

      // scout-block (.ckignore)
      const scout: ScoutBlockResult = active ? checkBashCommand(command, cwd) : {};
      if (scout.block) {
        if (ctx.hasUI) ctx.ui.notify(scout.reason || "Blocked", "error");
        return { block: true, reason: scout.reason };
      }

      // privacy-block (sensitive file → confirm; ambiguous → warn)
      const privacy = checkBashSensitive(command);
      if (privacy.warning && ctx.hasUI) {
        ctx.ui.notify(privacy.warning, "warning");
      }
      const resolved = await resolveConfirm(privacy, ctx);
      if (resolved.block) {
        return { block: true, reason: resolved.reason };
      }
      return;
    }

    // --- structured path tools: read / write / edit ---
    const pathTools = ["read", "write", "edit"] as const;
    for (const name of pathTools) {
      if (isToolCallEventType(name, event)) {
        const filePath = (event.input.path as string) || "";

        // scout-block (.ckignore)
        const scout: ScoutBlockResult = active ? checkStructuredPath(filePath, cwd) : {};
        if (scout.block) {
          if (ctx.hasUI) ctx.ui.notify(scout.reason || "Blocked", "error");
          return { block: true, reason: scout.reason };
        }

        // privacy-block (sensitive file → confirm)
        const privacy = checkStructuredSensitive(filePath);
        const resolved = await resolveConfirm(privacy, ctx);
        if (resolved.block) {
          return { block: true, reason: resolved.reason };
        }
        return;
      }
    }

    return;
  });
}

// before_agent_start → iteration-context + dev-rules-reminder (inject message)
function onBeforeAgentStart(pi: ExtensionAPI): void {
  pi.on("before_agent_start", async (event, ctx) => {
    const cwd = ctx.cwd;
    const sessionId = getSessionId(ctx);
    // Runs started by a custom message carry no user prompt.
    const prompt = event.messageType === "user" ? event.prompt || "" : "";
    if (promptInvokesRun(prompt)) markRunActive(cwd, sessionId);

    const parts: string[] = [];

    // When running inside a pi-subagents child, inject the subagent context
    // block (project/branch/active TSV/iteration) — the port of Claude's
    // SubagentStart hook. iteration-context already flows into children via
    // this same handler, but the subagent block adds the structured header
    // and is the canonical entry point for child-side autoresearch state.
    if (isSubagentChild()) {
      const sub = buildSubagentContext(cwd, sessionId);
      if (sub.text) parts.push(sub.text);
    }

    const iter = buildIterationContext(cwd, sessionId, prompt);
    if (iter.text) parts.push(iter.text);

    if (isRunActive(cwd, sessionId, prompt)) {
      const dev = buildDevRules(cwd, sessionId);
      if (dev.text) parts.push(dev.text);
    }

    if (parts.length === 0) return;

    return {
      message: {
        customType: "autoresearch-context",
        content: parts.join("\n\n"),
        display: false,
      },
    };
  });
}

// input → simplify-gate (block/warn shipping verbs)
function onInput(pi: ExtensionAPI): void {
  pi.on("input", async (event, ctx) => {
    if (event.source === "extension") return { action: "continue" };
    const sessionId = getSessionId(ctx);
    if (promptInvokesRun(event.text)) markRunActive(ctx.cwd, sessionId);
    if (!isRunActive(ctx.cwd, sessionId, event.text)) return { action: "continue" };

    const result = checkSimplifyGate(event.text, ctx.cwd);
    surfaceWarning(result, ctx);

    if (result.block) {
      if (ctx.hasUI) ctx.ui.notify(result.reason || "Blocked", "error");
      return { action: "handled" };
    }

    return { action: "continue" };
  });
}

// Parent-side observability for pi-subagents: log delegation requests so
// subagent launches show up in the bounded hook log. This is notification
// only — the request cannot be mutated here; child-side context injection
// happens via onBeforeAgentStart (PI_SUBAGENT_CHILD=1). Fails open if
// pi-subagents is not installed (the event simply never fires).
const SUBAGENT_REQUEST_EVENT = "prompt-template:subagent:request";

function onSubagentDelegation(pi: ExtensionAPI): void {
  try {
    pi.events.on(SUBAGENT_REQUEST_EVENT, (data: unknown) => {
      if (!isHookEnabled("subagent-context")) return;
      try {
        const req = data as { agent?: string; context?: string } | null;
        log("subagent-context", {
          action: "delegation",
          tool: req?.agent || "unknown",
          category: req?.context || "unknown",
        });
      } catch {
        /* fail-open */
      }
    });
  } catch {
    /* pi.events unavailable — fail open */
  }
}

export function registerGuardrails(pi: ExtensionAPI): void {
  onSessionStart(pi);
  onSessionShutdown(pi);
  onToolCall(pi);
  onBeforeAgentStart(pi);
  onInput(pi);
  onSubagentDelegation(pi);
}

// Re-export for tests / direct use.
export { loadSessionState };
