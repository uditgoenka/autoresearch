'use strict';

const fs = require('fs');
const os = require('os');
const path = require('path');
const crypto = require('crypto');

function isEnabled(hookName) {
  const envKey = 'AR_DISABLE_' + hookName.replace(/-/g, '_').toUpperCase();
  return !process.env[envKey];
}

function safeParseStdin() {
  try {
    const data = fs.readFileSync('/dev/stdin', 'utf8');
    return JSON.parse(data);
  } catch {
    return null;
  }
}

function getSessionId(stdin) {
  return (stdin && stdin.session_id) || 'unknown';
}

function getSessionHash(stdin) {
  const cwd = process.cwd();
  const sid = getSessionId(stdin);
  return crypto.createHash('md5').update(cwd + ':' + sid).digest('hex').slice(0, 12);
}

function sessionStatePath(stdin) {
  return '/tmp/ar-session-' + getSessionHash(stdin) + '.json';
}

function loadSessionState(stdin) {
  try {
    const raw = fs.readFileSync(sessionStatePath(stdin), 'utf8');
    return JSON.parse(raw);
  } catch {
    return {
      projectRoot: process.cwd(),
      plansPath: path.join(process.cwd(), 'plans'),
      reportsPath: path.join(process.cwd(), 'plans', 'reports'),
      gitBranch: '',
      sessionId: getSessionId(stdin),
      iterationCount: 0
    };
  }
}

function saveSessionState(stdin, state) {
  try {
    fs.writeFileSync(sessionStatePath(stdin), JSON.stringify(state, null, 2));
  } catch { /* fail-open */ }
}

function incrementCounter(stdin, field) {
  const state = loadSessionState(stdin);
  state[field] = (state[field] || 0) + 1;
  saveSessionState(stdin, state);
  return state[field];
}

function log(hookName, entry) {
  try {
    // Runtime logs live under the user's global ~/.claude, keyed by project,
    // so they never pollute (or get committed into) the project repo. Mirrors
    // the global /tmp session-state convention above.
    const cwd = process.cwd();
    const projectKey = path.basename(cwd) + '-' +
      crypto.createHash('md5').update(cwd).digest('hex').slice(0, 8);
    const logDir = path.join(os.homedir(), '.claude', 'hooks', '.logs', projectKey);
    fs.mkdirSync(logDir, { recursive: true });
    const logPath = path.join(logDir, 'hook-log.jsonl');
    const record = JSON.stringify({
      ts: new Date().toISOString(),
      hook: hookName,
      cwd,
      ...entry
    });
    fs.appendFileSync(logPath, record + '\n');
  } catch { /* fail-open */ }
}

function readTsvTail(filePath, n) {
  try {
    const content = fs.readFileSync(filePath, 'utf8');
    const lines = content.split('\n').filter(l => l.trim());
    const headerLines = lines.filter(l => l.startsWith('#') || l.startsWith('iteration\t') || l.startsWith('iteration|'));
    const dataLines = lines.filter(l => !l.startsWith('#') && l.trim() && !l.startsWith('iteration\t') && !l.startsWith('iteration|'));
    const header = headerLines.length > 0 ? headerLines[headerLines.length - 1] : '';
    const tail = dataLines.slice(-n);
    return { header, rows: tail, total: dataLines.length };
  } catch {
    return null;
  }
}

function findRecentTsv(cwd, maxAgeMinutes) {
  const maxAge = maxAgeMinutes * 60 * 1000;
  const now = Date.now();
  const arDir = path.join(cwd, 'autoresearch');
  let best = null;
  let bestMtime = 0;

  try {
    const dirs = fs.readdirSync(arDir);
    for (const dir of dirs) {
      const subdir = path.join(arDir, dir);
      let stat;
      try { stat = fs.statSync(subdir); } catch { continue; }
      if (!stat.isDirectory()) continue;
      try {
        const files = fs.readdirSync(subdir);
        for (const f of files) {
          if (!f.endsWith('.tsv')) continue;
          const fp = path.join(subdir, f);
          const fstat = fs.statSync(fp);
          const age = now - fstat.mtimeMs;
          if (age < maxAge && fstat.mtimeMs > bestMtime) {
            best = fp;
            bestMtime = fstat.mtimeMs;
          }
        }
      } catch { continue; }
    }
  } catch { /* no autoresearch dir */ }

  return best;
}

function output(obj) {
  process.stdout.write(JSON.stringify(obj));
}

function block(reason) {
  process.stderr.write(reason + '\n');
  output({});
  process.exit(2);
}

function allow(extra) {
  output(extra || {});
  process.exit(0);
}

function inject(text) {
  output({ additionalContext: text });
  process.exit(0);
}

module.exports = {
  isEnabled,
  safeParseStdin,
  getSessionId,
  getSessionHash,
  sessionStatePath,
  loadSessionState,
  saveSessionState,
  incrementCounter,
  log,
  readTsvTail,
  findRecentTsv,
  output,
  block,
  allow,
  inject
};
