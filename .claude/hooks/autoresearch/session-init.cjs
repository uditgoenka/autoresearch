'use strict';

// SessionStart hook: computes project context and persists session state.
// Injects additionalContext with project root, branch, and paths.
// Fails open on any error — never blocks session startup.

const fs = require('fs');
const os = require('os');
const path = require('path');
const { execSync } = require('child_process');

const {
  isEnabled, safeParseStdin, getSessionId, loadSessionState, saveSessionState, log, inject, failOpen
} = require('./lib/ar-hook-utils.cjs');

const HOOK_NAME = 'session-init';
const SESSION_MAX_AGE_MS = 24 * 60 * 60 * 1000; // 24 hours

function resolveGitRoot() {
  try {
    return execSync('git rev-parse --show-toplevel', { encoding: 'utf8', timeout: 5000 }).trim();
  } catch {
    return process.cwd();
  }
}

function resolveGitBranch() {
  try {
    return execSync('git rev-parse --abbrev-ref HEAD', { encoding: 'utf8', timeout: 5000 }).trim();
  } catch {
    return '';
  }
}

function pruneStaleSessionFiles() {
  try {
    const now = Date.now();
    const tmp = os.tmpdir();
    const entries = fs.readdirSync(tmp);
    for (const entry of entries) {
      if (!entry.startsWith('ar-session-') || !entry.endsWith('.json')) continue;
      const fp = path.join(tmp, entry);
      try {
        const stat = fs.statSync(fp);
        if (now - stat.mtimeMs > SESSION_MAX_AGE_MS) {
          fs.unlinkSync(fp);
        }
      } catch { /* skip files we can't stat or delete */ }
    }
  } catch { /* operating-system temp directory unreadable — skip */ }
}

try {
  if (!isEnabled(HOOK_NAME)) process.exit(0);

  const stdin = safeParseStdin(HOOK_NAME);
  if (!stdin) process.exit(0);

  const projectRoot = resolveGitRoot();
  const gitBranch = resolveGitBranch();

  const state = {
    projectRoot,
    plansPath: path.join(projectRoot, 'plans'),
    reportsPath: path.join(projectRoot, 'plans', 'reports'),
    gitBranch,
    sessionId: getSessionId(stdin),
    iterationCount: 0,
    startedAt: new Date().toISOString()
  };
  // Compact and resume re-fire SessionStart with the same session id; keep the run flag.
  try {
    if (loadSessionState(stdin).autoresearchActive) state.autoresearchActive = true;
  } catch { /* unreadable state starts fresh */ }

  saveSessionState(stdin, state);
  pruneStaleSessionFiles();

  log(HOOK_NAME, { projectRoot, gitBranch });

  inject(
    `## Session initialized\n` +
    `- Project: ${projectRoot}\n` +
    `- Branch: ${gitBranch}\n` +
    `- Plans: ${state.plansPath}\n` +
    `- Reports: ${state.reportsPath}`
  );
} catch {
  failOpen(HOOK_NAME, 'internal-error');
}
