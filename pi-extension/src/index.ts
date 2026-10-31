// Autoresearch for pi — extension entry point.
//
// Ports the Claude Code autoresearch hooks (safety guardrails + iteration
// context injection) to pi's extension event system, and contributes the
// autoresearch skill + 14 command prompt templates via resources_discover.
//
// Install:   pi install git:github.com/uditgoenka/autoresearch
//   (the repo-root package.json points pi at this extension)
// Try:       pi -e ./pi-extension
//
// Hooks → events:
//   PreToolUse  → tool_call         (scout/privacy/dangerous-cmd block)
//   UserPrompt → before_agent_start (iteration-context + dev-rules inject)
//   UserPrompt → input              (simplify-gate)
//   SessionStart → session_start    (session-init)
//   SessionEnd   → session_shutdown (stop-notify)
//   SubagentStart → before_agent_start (subagent-context, child-side) + pi.events (parent)
//
// Every hook fails open — a guardrail malfunction never blocks work.

import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

import { registerGuardrails } from "./guardrails.js";

const baseDir = dirname(fileURLToPath(import.meta.url));

export default function autoresearchPi(pi: ExtensionAPI): void {
  // 1. Safety guardrails + context injection (the "hooks").
  registerGuardrails(pi);

  // 2. Contribute the autoresearch skill + command prompt templates.
  //    skills/autoresearch/SKILL.md  → /skill:autoresearch (dispatcher)
  //    prompts/autoresearch.md      → /autoresearch        (classic loop)
  //    prompts/autoresearch/*.md    → /autoresearch_debug, /autoresearch_fix, ...
  pi.on("resources_discover", () => {
    return {
      skillPaths: [join(baseDir, "..", "skills", "autoresearch", "SKILL.md")],
      promptPaths: [join(baseDir, "..", "prompts")],
    };
  });
}
