// privacy-block — ported from claude-plugin/hooks/privacy-block.cjs.
// Escalates clear sensitive-file access to a user confirmation. In Claude this
// returned permissionDecision: 'ask'; in pi we use ctx.ui.confirm() in
// interactive mode and fail open (allow) otherwise. Ambiguous commands get a
// warning injected. Fails open on any error.

import { isHookEnabled, log } from "../lib/session-state.js";
import { bashSensitivity, isSensitive } from "../lib/paths.js";
import type { ExtensionContext } from "@earendil-works/pi-coding-agent";

const HOOK_NAME = "privacy-block";

export interface PrivacyResult {
  block?: boolean;
  reason?: string;
  /** Text to inject as additional context (ambiguous-command warning). */
  warning?: string;
  /** When true, the caller should run ctx.ui.confirm before proceeding. */
  needsConfirm?: boolean;
  confirmReason?: string;
}

export function checkStructuredSensitive(filePath: string): PrivacyResult {
  if (!isHookEnabled(HOOK_NAME)) return {};
  try {
    if (isSensitive(filePath)) {
      log(HOOK_NAME, { action: "ask", tool: "structured", category: "sensitive-file" });
      return {
        needsConfirm: true,
        confirmReason:
          "This operation targets a potentially sensitive file. Confirm access?",
      };
    }
  } catch {
    // fail-open
  }
  return {};
}

export function checkBashSensitive(command: string): PrivacyResult {
  if (!isHookEnabled(HOOK_NAME)) return {};
  try {
    const sensitivity = bashSensitivity(command);
    if (sensitivity === "clear") {
      log(HOOK_NAME, { action: "ask", tool: "bash", category: "sensitive-command" });
      return {
        needsConfirm: true,
        confirmReason:
          "This command clearly accesses a potentially sensitive file. Confirm access?",
      };
    }
    if (sensitivity === "ambiguous") {
      log(HOOK_NAME, { action: "warn", tool: "bash", category: "ambiguous-sensitive-text" });
      return {
        warning:
          "WARNING: The command contains sensitive-looking text. Confirm that it does not expose credentials.",
      };
    }
  } catch {
    // fail-open
  }
  return {};
}

// Resolve a needsConfirm result against the UI. Returns a block decision if
// the user declines; returns {} if allowed or no UI available (fail open).
export async function resolveConfirm(
  result: PrivacyResult,
  ctx: ExtensionContext,
): Promise<PrivacyResult> {
  if (!result.needsConfirm) return result;
  if (!ctx.hasUI) {
    // Non-interactive: fail open (allow).
    return {};
  }
  const ok = await ctx.ui.confirm("Sensitive file", result.confirmReason || "Allow?");
  if (!ok) {
    return { block: true, reason: "Blocked: sensitive-file access declined by user." };
  }
  return {};
}
