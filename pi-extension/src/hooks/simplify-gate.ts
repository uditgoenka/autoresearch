// simplify-gate — ported from claude-plugin/hooks/simplify-gate.cjs.
// Warns or blocks shipping verbs (ship/merge/deploy/pr/publish/release) when
// too many lines have changed. In Claude this ran on UserPromptSubmit; in pi
// we run on the `input` event and can block or transform. Fails open.

import { readFileSync } from "node:fs";
import { execSync } from "node:child_process";
import { join } from "node:path";
import { isHookEnabled, log } from "../lib/session-state.js";
import type { ExtensionContext } from "@earendil-works/pi-coding-agent";

const HOOK_NAME = "simplify-gate";

const SHIPPING_VERBS = ["ship", "merge", "deploy", "pr", "publish", "release"];

const NEGATION_PHRASES = [
  "don't ship",
  "never deploy",
  "not ready to merge",
  "don't merge",
  "don't deploy",
  "don't publish",
  "don't release",
  "no ship",
  "no merge",
  "no deploy",
];

const WARN_THRESHOLD = 400;
const BLOCK_THRESHOLD = 800;

function hasShippingVerb(prompt: string): boolean {
  const lower = prompt.toLowerCase();
  for (const phrase of NEGATION_PHRASES) {
    if (lower.includes(phrase)) return false;
  }
  for (const verb of SHIPPING_VERBS) {
    const regex = new RegExp("\\b" + verb + "\\b", "i");
    if (regex.test(prompt)) return true;
  }
  return false;
}

function pendingLoc(cwd: string): number {
  const diff = execSync("git diff HEAD --numstat", {
    encoding: "utf8",
    timeout: 5000,
    cwd,
  });
  let loc = diff
    .trim()
    .split("\n")
    .filter(Boolean)
    .reduce((total, line) => {
      const [added, removed] = line.split("\t");
      return (
        total +
        (/^\d+$/.test(added) ? Number(added) : 0) +
        (/^\d+$/.test(removed) ? Number(removed) : 0)
      );
    }, 0);
  const untracked = execSync("git ls-files --others --exclude-standard -z", {
    encoding: "utf8",
    timeout: 5000,
    cwd,
  });
  for (const file of untracked.split("\0").filter(Boolean)) {
    try {
      const content = readFileSync(join(cwd, file));
      // Skip binaries, matching git's own numstat rule (a NUL byte means binary).
      if (content.includes(0)) continue;
      loc += content.toString("utf8").split("\n").length - 1;
    } catch {
      /* skip unreadable untracked file */
    }
  }
  return loc;
}

export interface SimplifyGateResult {
  /** Block the prompt entirely. */
  block?: boolean;
  reason?: string;
  /** Warning text to surface to the user (non-blocking). */
  warning?: string;
}

export function checkSimplifyGate(prompt: string, cwd: string): SimplifyGateResult {
  if (!isHookEnabled(HOOK_NAME)) return {};
  if (!prompt || typeof prompt !== "string") return {};

  if (!hasShippingVerb(prompt)) return {};

  let loc = 0;
  try {
    loc = pendingLoc(cwd);
  } catch {
    // fail-open on git errors
    return {};
  }

  if (loc < WARN_THRESHOLD) return {};

  log(HOOK_NAME, { loc, action: loc > BLOCK_THRESHOLD ? "block" : "warn" });

  if (loc > BLOCK_THRESHOLD) {
    return {
      block: true,
      reason: `BLOCKED: ${loc} lines changed exceeds ${BLOCK_THRESHOLD} LOC shipping threshold. Simplify before shipping. Use AR_DISABLE_SIMPLIFY_GATE=1 to override.`,
    };
  }

  // 400–800 range: warn but allow
  return { warning: `WARNING: ${loc} lines changed. Consider simplifying before shipping.` };
}

// Surface a non-blocking warning to the user without altering the prompt.
export function surfaceWarning(result: SimplifyGateResult, ctx: ExtensionContext): void {
  if (result.warning && ctx.hasUI) {
    ctx.ui.notify(result.warning, "warning");
  }
}
