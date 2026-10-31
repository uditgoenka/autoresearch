// Session state persistence — ported from claude-plugin/hooks/lib/ar-hook-utils.cjs.
// In Claude, hooks received a session_id on stdin. In pi, we derive a stable
// hash from cwd + session id via ExtensionContext. State lives in the OS temp
// dir keyed by that hash, exactly like the original.

import { existsSync, mkdirSync, readFileSync, writeFileSync, appendFileSync, statSync, readdirSync, unlinkSync } from "node:fs";
import { homedir, tmpdir } from "node:os";
import { basename, dirname, join } from "node:path";
import { createHash } from "node:crypto";
import { findRecentTsv } from "./tsv.js";

export interface SessionState {
  projectRoot: string;
  plansPath: string;
  reportsPath: string;
  gitBranch: string;
  sessionId: string;
  iterationCount: number;
  startedAt?: string;
  lastContextInjection?: number;
  autoresearchActive?: boolean;
}

const DEFAULT_STATE = (cwd: string, sessionId: string): SessionState => ({
  projectRoot: cwd,
  plansPath: join(cwd, "plans"),
  reportsPath: join(cwd, "plans", "reports"),
  gitBranch: "",
  sessionId,
  iterationCount: 0,
});

export function sessionHash(cwd: string, sessionId: string): string {
  return createHash("md5").update(`${cwd}:${sessionId}`).digest("hex").slice(0, 12);
}

export function sessionStatePath(cwd: string, sessionId: string): string {
  return join(tmpdir(), `ar-session-${sessionHash(cwd, sessionId)}.json`);
}

export function loadSessionState(cwd: string, sessionId: string): SessionState {
  try {
    const raw = readFileSync(sessionStatePath(cwd, sessionId), "utf8");
    return { ...DEFAULT_STATE(cwd, sessionId), ...JSON.parse(raw) };
  } catch (error) {
    // A corrupt file starts fresh, like a missing one; the next save rewrites it.
    if (!(error instanceof SyntaxError) && (error as NodeJS.ErrnoException).code !== "ENOENT") throw error;
    return DEFAULT_STATE(cwd, sessionId);
  }
}

export function saveSessionState(cwd: string, sessionId: string, state: SessionState): void {
  writeFileSync(sessionStatePath(cwd, sessionId), JSON.stringify(state, null, 2));
}

export function incrementCounter(
  cwd: string,
  sessionId: string,
  field: keyof SessionState,
): number {
  const state = loadSessionState(cwd, sessionId);
  const next = ((state[field] as number) || 0) + 1;
  (state[field] as number) = next;
  saveSessionState(cwd, sessionId, state);
  return next;
}

export function cleanupSessionFile(cwd: string, sessionId: string): void {
  try {
    unlinkSync(sessionStatePath(cwd, sessionId));
  } catch {
    /* already gone */
  }
}

const SESSION_MAX_AGE_MS = 24 * 60 * 60 * 1000; // 24 hours

export function pruneStaleSessionFiles(): void {
  try {
    const now = Date.now();
    const tmp = tmpdir();
    for (const entry of readdirSync(tmp)) {
      if (!entry.startsWith("ar-session-") || !entry.endsWith(".json")) continue;
      const fp = join(tmp, entry);
      try {
        const stat = statSync(fp);
        if (now - stat.mtimeMs > SESSION_MAX_AGE_MS) unlinkSync(fp);
      } catch {
        /* skip */
      }
    }
  } catch {
    /* tmp dir unreadable */
  }
}

// Bounded metadata-only runtime log, mirroring the original. Lives under the
// pi config dir (~/.pi/agent/autoresearch/.logs/<projectHash>/hook-log.jsonl).
// NOTE: do NOT use ~/.pi/agent/hooks/ — pi renamed hooks→extensions and warns
// on a legacy hooks/ directory, so we use a namespaced autoresearch/ dir instead.
// Raw paths, commands, tool inputs, and secrets are intentionally excluded.
export function log(hookName: string, entry: Record<string, unknown>): void {
  try {
    const cwd = process.cwd();
    const projectKey = createHash("md5").update(cwd).digest("hex").slice(0, 12);
    const logDir = join(homedir(), ".pi", "agent", "autoresearch", ".logs", projectKey);
    mkdirSync(logDir, { recursive: true });
    const logPath = join(logDir, "hook-log.jsonl");
    const safeEntry: Record<string, unknown> = {};
    for (const key of [
      "action",
      "tool",
      "loc",
      "duration",
      "iterations",
      "category",
      "remediation",
      "matched",
    ]) {
      if (entry && typeof entry[key] !== "undefined") safeEntry[key] = entry[key];
    }
    const record = JSON.stringify({ ts: new Date().toISOString(), hook: hookName, ...safeEntry });
    appendFileSync(logPath, record + "\n");
  } catch {
    /* fail-open */
  }
}

export function isHookEnabled(hookName: string): boolean {
  const envKey = "AR_DISABLE_" + hookName.replace(/-/g, "_").toUpperCase();
  return !process.env[envKey];
}

export { homedir, basename, dirname, existsSync, readFileSync };

// A run is active once the user invokes /autoresearch (or a /autoresearch_*
// template, or /skill:autoresearch) in this session, once the model reads the
// autoresearch SKILL.md, or while a results TSV under ./autoresearch/ was
// written in the last 30 minutes. Guardrails that block or inject stay silent
// in every other session. privacy-block stays global.
// pi prompt templates use underscore names (/autoresearch_debug).
const RUN_INVOCATION = /(^|\s)(\/skill:autoresearch|[/$]autoresearch(_[a-z]+)?)\b/i;
const RUN_SKILL_FILE = /(^|[\\/])autoresearch[\\/]SKILL\.md$/;

export function promptInvokesRun(prompt: string | undefined): boolean {
  return typeof prompt === "string" && RUN_INVOCATION.test(prompt);
}

export function readsRunSkill(filePath: string | undefined): boolean {
  return typeof filePath === "string" && RUN_SKILL_FILE.test(filePath);
}

export function markRunActive(cwd: string, sessionId: string): void {
  try {
    const state = loadSessionState(cwd, sessionId);
    if (state.autoresearchActive) return;
    state.autoresearchActive = true;
    saveSessionState(cwd, sessionId, state);
  } catch {
    /* fail-open */
  }
}

export function isRunActive(cwd: string, sessionId: string, prompt?: string): boolean {
  if (promptInvokesRun(prompt)) return true;
  try {
    if (loadSessionState(cwd, sessionId).autoresearchActive) return true;
  } catch {
    /* unreadable state falls through to the TSV check */
  }
  try {
    return Boolean(findRecentTsv(cwd, 30));
  } catch {
    return false;
  }
}
