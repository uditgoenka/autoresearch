// scout-block — ported from claude-plugin/hooks/scout-block.cjs.
// Blocks file access (via read/write/edit/bash tools) to paths matching
// .ckignore + baseline ignore patterns (node_modules, .git, etc.). Fails open.

import { isHookEnabled, log } from "../lib/session-state.js";
import { checkIgnore, extractPathTokens, findProjectRoot, loadCkIgnore } from "../lib/paths.js";

const HOOK_NAME = "scout-block";

export interface ScoutBlockResult {
  block?: boolean;
  reason?: string;
}

// Check a structured-tool path (read/write/edit) against .ckignore.
export function checkStructuredPath(
  filePath: string,
  cwd: string,
): ScoutBlockResult {
  if (!isHookEnabled(HOOK_NAME)) return {};
  try {
    const projectRoot = findProjectRoot(cwd);
    const ig = loadCkIgnore(projectRoot);
    const matched = checkIgnore(filePath, ig, projectRoot, cwd);
    if (matched) {
      log(HOOK_NAME, { action: "block", tool: "structured" });
      return {
        block: true,
        reason: `BLOCKED: Access to '${matched}' denied by .ckignore\n\nTo allow, add to .ckignore: !${matched}`,
      };
    }
  } catch {
    // fail-open
  }
  return {};
}

// Check path-like tokens in a bash command against .ckignore.
export function checkBashCommand(
  command: string,
  cwd: string,
): ScoutBlockResult {
  if (!isHookEnabled(HOOK_NAME)) return {};
  try {
    const projectRoot = findProjectRoot(cwd);
    const ig = loadCkIgnore(projectRoot);
    for (const token of extractPathTokens(command)) {
      const matched = checkIgnore(token, ig, projectRoot, cwd);
      if (matched) {
        log(HOOK_NAME, { action: "block", tool: "bash" });
        return {
          block: true,
          reason: `BLOCKED: Access to '${matched}' denied by .ckignore\n\nTo allow, add to .ckignore: !${matched}`,
        };
      }
    }
  } catch {
    // fail-open
  }
  return {};
}
