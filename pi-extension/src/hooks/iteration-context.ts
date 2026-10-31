// iteration-context — ported from claude-plugin/hooks/iteration-context.cjs.
// On every 5th prompt, injects the active iteration TSV tail + iteration count
// as additional context so the agent remembers loop state across compaction.
// In Claude this ran on UserPromptSubmit and returned additionalContext; in pi
// we run on before_agent_start and return a message. Fails open.

import { relative } from "node:path";
import {
  incrementCounter,
  isHookEnabled,
  loadSessionState,
  log,
  saveSessionState,
} from "../lib/session-state.js";
import { findRecentTsv, readTsvTail } from "../lib/tsv.js";

const HOOK_NAME = "iteration-context";

const AR_COMMANDS = [
  "autoresearch",
  "/autoresearch:",
  "loop",
  "debug",
  "fix",
  "scenario",
  "predict",
  "learn",
  "reason",
  "probe",
  "security",
  "ship",
];

function hasArCommand(prompt: string): boolean {
  if (!prompt || typeof prompt !== "string") return false;
  const lower = prompt.toLowerCase();
  return AR_COMMANDS.some((cmd) => lower.includes(cmd));
}

function formatRows(header: string, rows: string[]): string {
  const lines: string[] = [];
  if (header) lines.push(header);
  for (const r of rows) lines.push(r);
  return lines.join("\n");
}

function relativePath(cwd: string, absPath: string): string {
  try {
    return relative(cwd, absPath);
  } catch {
    return absPath;
  }
}

export interface IterationContextResult {
  /** Additional context text to inject, or null to inject nothing. */
  text: string | null;
}

export function buildIterationContext(
  cwd: string,
  sessionId: string,
  prompt: string,
): IterationContextResult {
  if (!isHookEnabled(HOOK_NAME)) return { text: null };
  try {
    incrementCounter(cwd, sessionId, "iterationCount");
    const state = loadSessionState(cwd, sessionId);
    const iterationCount = state.iterationCount;

    // Throttle: only inject every 5th prompt
    if (iterationCount % 5 !== 0) {
      log(HOOK_NAME, { action: "skip", iterations: iterationCount });
      return { text: null };
    }

    // Mark injection time so dev-rules-reminder can skip this turn
    state.lastContextInjection = Date.now();
    saveSessionState(cwd, sessionId, state);

    const tsvPath = findRecentTsv(cwd, 30);
    if (!tsvPath) {
      log(HOOK_NAME, { action: "skip", iterations: iterationCount, reason: "no-tsv" });
      return { text: null };
    }

    const tsv = readTsvTail(tsvPath, 3);
    if (!tsv) {
      log(HOOK_NAME, { action: "skip", iterations: iterationCount, reason: "tsv-unreadable" });
      return { text: null };
    }

    const relTsv = relativePath(cwd, tsvPath);
    const rowBlock = formatRows(tsv.header, tsv.rows);

    let text =
      `## Active iteration state\n**TSV:** ${relTsv}\n**Iteration:** ${iterationCount} | **Rows:** ${tsv.total}\n\n${rowBlock}`;

    if (hasArCommand(prompt)) {
      text += `\n\n**Loop state:** active — ${tsv.total} iterations recorded, last 3 rows above`;
    }

    log(HOOK_NAME, { action: "inject", iterations: iterationCount, tsvRows: tsv.total });
    return { text };
  } catch {
    // fail-open
    return { text: null };
  }
}
