// subagent-context — ported from claude-plugin/hooks/subagent-context.cjs.
//
// In Claude this ran on SubagentStart and injected project/branch/TSV state
// into the subagent. pi has no native subagent-spawn event in the extension
// API, but the widely-used pi-subagents extension emits delegation events on
// the shared `pi.events` bus, and — crucially — pi subagents are full pi
// sessions that load this same extension and fire `before_agent_start`. So
// iteration context already flows into children via iteration-context.ts.
//
// This module does two things:
//   1. (child side) When this extension is running inside a subagent
//      (PI_SUBAGENT_CHILD=1), build the same context block the Claude hook
//      injected: project, branch, plans/reports path, active TSV, iteration
//      count, latest row summary. Injected via before_agent_start.
//   2. (parent side) Listen for pi-subagents delegation events on pi.events to
//      log subagent launches for observability (bounded metadata only).
//
// Fails open on any error.

import { join, relative } from "node:path";
import {
  isHookEnabled,
  loadSessionState,
  log,
} from "../lib/session-state.js";
import { findRecentTsv, readTsvTail } from "../lib/tsv.js";

const HOOK_NAME = "subagent-context";

/** True when this extension instance is running inside a pi-subagents child. */
export function isSubagentChild(): boolean {
  return process.env.PI_SUBAGENT_CHILD === "1";
}

function relativePath(cwd: string, absPath: string): string {
  try {
    return relative(cwd, absPath);
  } catch {
    return absPath;
  }
}

function summarizeLastRow(header: string, row: string | undefined): string {
  if (!row) return "none";
  const headerCols = header ? header.split(/\t|\|/) : [];
  const rowCols = row.split(/\t|\|/);
  const parts: string[] = [];
  rowCols.forEach((val, i) => {
    const col = (headerCols[i] || "").toLowerCase();
    if (
      col.includes("status") ||
      col.includes("result") ||
      col.includes("pass") ||
      col.includes("fail")
    ) {
      parts.push(val.trim());
    } else if (/^-?\d+(\.\d+)?$/.test(val.trim()) && parts.length < 3) {
      const label = headerCols[i] ? headerCols[i].trim() + "=" : "";
      parts.push(label + val.trim());
    }
  });
  return parts.length > 0 ? parts.join(", ") : rowCols.slice(0, 3).join(", ");
}

export interface SubagentContextResult {
  /** Context block to inject into the subagent, or null. */
  text: string | null;
}

// Build the subagent context block. Called from before_agent_start when
// PI_SUBAGENT_CHILD=1. Mirrors subagent-context.cjs output exactly.
export function buildSubagentContext(
  cwd: string,
  sessionId: string,
): SubagentContextResult {
  if (!isHookEnabled(HOOK_NAME)) return { text: null };
  try {
    const state = loadSessionState(cwd, sessionId);
    // A subagent may start in a subdirectory; the run lives at the project root.
    const root = state.projectRoot || cwd;
    const tsvPath = findRecentTsv(root, 30);

    if (!tsvPath) {
      log(HOOK_NAME, { action: "skip", reason: "no-active-tsv" });
      return { text: null };
    }

    const tsv = readTsvTail(tsvPath, 1);
    const relTsv = relativePath(root, tsvPath);
    const latestSummary = tsv
      ? summarizeLastRow(tsv.header, tsv.rows[0])
      : "none";

    const text = [
      "## Autoresearch context (for subagent)",
      `- Project: ${state.projectRoot || cwd}`,
      `- Branch: ${state.gitBranch || "unknown"}`,
      `- Plans: ${state.plansPath || join(cwd, "plans")}`,
      `- Reports: ${state.reportsPath || join(cwd, "plans", "reports")}`,
      `- Active TSV: ${relTsv}`,
      `- Iteration: ${state.iterationCount || 0}`,
      `- Latest: ${latestSummary}`,
    ].join("\n");

    log(HOOK_NAME, { action: "inject", subagent: "child" });
    return { text };
  } catch {
    // fail-open
    return { text: null };
  }
}
