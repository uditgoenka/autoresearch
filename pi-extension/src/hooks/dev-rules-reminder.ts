// dev-rules-reminder — ported from claude-plugin/hooks/dev-rules-reminder.cjs.
// Injects dev-context (plan path, code-standards) every 5th iteration, but
// skips the turn when iteration-context already injected. Fails open.

import { join } from "node:path";
import { isHookEnabled, loadSessionState, log } from "../lib/session-state.js";

const HOOK_NAME = "dev-rules-reminder";

export interface DevRulesResult {
  text: string | null;
}

export function buildDevRules(cwd: string, sessionId: string): DevRulesResult {
  if (!isHookEnabled(HOOK_NAME)) return { text: null };
  try {
    const state = loadSessionState(cwd, sessionId);

    // Skip if iteration-context already injected this same turn (within 2s)
    if (state.lastContextInjection && Date.now() - state.lastContextInjection < 2000) {
      log(HOOK_NAME, { action: "skip", reason: "iteration-context-fired" });
      return { text: null };
    }

    // Only inject on every 5th iteration, same cadence as iteration-context
    if ((state.iterationCount || 0) % 5 !== 0) {
      return { text: null };
    }

    const plansPath = state.plansPath || join(cwd, "plans");

    const text = [
      "## Dev context",
      `- Plan: ${plansPath} (check for active plan.md)`,
      "- Standards: docs/code-standards.md",
    ].join("\n");

    log(HOOK_NAME, { action: "inject", iterations: state.iterationCount });
    return { text };
  } catch {
    // fail-open
    return { text: null };
  }
}
