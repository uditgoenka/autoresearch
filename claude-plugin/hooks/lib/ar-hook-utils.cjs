'use strict';

const fs = require('fs');
const os = require('os');
const path = require('path');
const crypto = require('crypto');

function isEnabled(hookName) {
  const envKey = 'AR_DISABLE_' + hookName.replace(/-/g, '_').toUpperCase();
  return !process.env[envKey];
}

function safeParseStdin(hookName) {
  try {
    const data = fs.readFileSync(0, 'utf8');
    return JSON.parse(data);
  } catch {
    const remediation = 'Retry the action or inspect the hook installation.';
    log(hookName || 'unknown', {
      action: 'fail-open',
      category: 'invalid-input',
      remediation
    });
    output({
      systemMessage: `Autoresearch ${hookName || 'unknown'} Guardrail unavailable: invalid input. ${remediation}`
    });
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
  return path.join(os.tmpdir(), 'ar-session-' + getSessionHash(stdin) + '.json');
}

function loadSessionState(stdin) {
  try {
    const raw = fs.readFileSync(sessionStatePath(stdin), 'utf8');
    return JSON.parse(raw);
  } catch (error) {
    if (!error || error.code !== 'ENOENT') throw error;
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
  fs.writeFileSync(sessionStatePath(stdin), JSON.stringify(state, null, 2));
}

function incrementCounter(stdin, field) {
  const state = loadSessionState(stdin);
  state[field] = (state[field] || 0) + 1;
  saveSessionState(stdin, state);
  return state[field];
}

function log(hookName, entry) {
  try {
    // Runtime logs live under the user's global ~/.claude and contain only
    // bounded metadata. Raw paths, commands, tool inputs, and secrets are
    // intentionally excluded.
    const cwd = process.cwd();
    const projectKey = crypto.createHash('md5').update(cwd).digest('hex').slice(0, 12);
    const logDir = path.join(os.homedir(), '.claude', 'hooks', '.logs', projectKey);
    fs.mkdirSync(logDir, { recursive: true });
    const logPath = path.join(logDir, 'hook-log.jsonl');
    const safeEntry = {};
    for (const key of ['action', 'tool', 'loc', 'duration', 'iterations', 'category', 'remediation']) {
      if (entry && typeof entry[key] !== 'undefined') safeEntry[key] = entry[key];
    }
    const record = JSON.stringify({
      ts: new Date().toISOString(),
      hook: hookName,
      ...safeEntry
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

function tokenizeShell(command) {
  const segments = [];
  const substitutions = [];
  let tokens = [];
  let token = '';
  let quote = '';
  let lineStart = true;
  let heredocDelimiter = '';
  // A heredoc body is data unless a shell reads it (`bash <<EOF`, `cat <<EOF | sh`).
  const shellFed = /(?:^|[\s|;&(/])(?:ba|z|da|k|fi)?sh(?=[\s;|&)]|$)/.test(command);

  const pushToken = () => {
    if (token) tokens.push(token);
    token = '';
  };
  const pushSegment = () => {
    pushToken();
    if (tokens.length) segments.push(tokens);
    tokens = [];
  };

  for (let i = 0; i < command.length; i++) {
    const char = command[i];
    if (heredocDelimiter && lineStart) {
      const lineEnd = command.indexOf('\n', i);
      const end = lineEnd === -1 ? command.length : lineEnd;
      if (command.slice(i, end).trim() === heredocDelimiter) heredocDelimiter = '';
      i = lineEnd === -1 ? command.length : lineEnd;
      lineStart = true;
      continue;
    }
    if (char === '\\' && quote !== "'") {
      if (i + 1 < command.length) token += command[++i];
      continue;
    }
    if ((char === "'" || char === '"')) {
      if (!quote) quote = char;
      else if (quote === char) quote = '';
      else token += char;
      continue;
    }
    if (char === '$' && command[i + 1] === '(' && quote !== "'") {
      let depth = 1;
      let inner = '';
      let innerQuote = '';
      i += 2;
      for (; i < command.length && depth > 0; i++) {
        const current = command[i];
        if (current === '\\' && innerQuote !== "'" && i + 1 < command.length) {
          inner += current + command[++i];
        } else if (current === "'" || current === '"') {
          if (!innerQuote) innerQuote = current;
          else if (innerQuote === current) innerQuote = '';
          inner += current;
        } else if (!innerQuote && current === '(') {
          depth += 1;
          inner += current;
        } else if (!innerQuote && current === ')' && --depth === 0) {
          break;
        } else {
          inner += current;
        }
      }
      i -= 1;
      substitutions.push(inner);
      token += '$()';
      continue;
    }
    if (char === '`' && quote !== "'") {
      let inner = '';
      for (i += 1; i < command.length && command[i] !== '`'; i++) {
        if (command[i] === '\\' && i + 1 < command.length) inner += command[i++] + command[i];
        else inner += command[i];
      }
      substitutions.push(inner);
      token += '``';
      continue;
    }
    if (!quote && /[\t ]/.test(char)) {
      pushToken();
      continue;
    }
    if (!quote && char === '#' && !token) {
      pushSegment();
      const lineEnd = command.indexOf('\n', i);
      if (lineEnd === -1) break;
      i = lineEnd - 1;
      lineStart = true;
      continue;
    }
    if (!quote && (char === '\n' || char === ';' || char === '|' || char === '&' || char === '(' || char === ')')) {
      pushSegment();
      if (char === '|' && command[i + 1] === '|') i += 1;
      if (char === '&' && command[i + 1] === '&') i += 1;
      lineStart = char === '\n';
      continue;
    }
    if (!quote && (char === '<' || char === '>')) {
      pushToken();
      let redirect = char;
      while (command[i + 1] === char) redirect += command[++i];
      tokens.push(redirect);
      if (redirect === '<<') {
        let next = i + 1;
        // `<<-` strips leading tabs from the body; the delimiter follows the dash.
        if (command[next] === '-') next += 1;
        while (/[\t ]/.test(command[next] || '')) next += 1;
        const match = command.slice(next).match(/^(?:['"]([^'"]+)['"]|([^\s;|&]+))/);
        if (match && !shellFed) heredocDelimiter = match[1] || match[2];
      }
      continue;
    }
    token += char;
    lineStart = false;
  }
  pushSegment();
  return { segments, substitutions };
}

function unwrapCommand(tokens) {
  let index = 0;
  while (index < tokens.length) {
    if (/^[A-Za-z_][A-Za-z0-9_]*=/.test(tokens[index])) {
      index += 1;
      continue;
    }
    const executable = path.basename(tokens[index]).toLowerCase();
    if (executable === 'command' || executable === 'builtin' || executable === 'nohup' || executable === 'exec') {
      index += 1;
      while (tokens[index] && tokens[index].startsWith('-')) index += 1;
      continue;
    }
    if (executable === 'env') {
      index += 1;
      while (tokens[index]) {
        const option = tokens[index];
        if (/^[A-Za-z_][A-Za-z0-9_]*=/.test(option)) index += 1;
        else if (option === '-S' || option === '--split-string') return [];
        else if (['-u', '--unset', '-C', '--chdir'].includes(option)) index += 2;
        else if (option.startsWith('-')) index += 1;
        else break;
      }
      continue;
    }
    if (executable === 'sudo') {
      index += 1;
      const optionsWithValue = new Set(['-C', '-D', '-g', '-h', '-p', '-R', '-r', '-T', '-t', '-U', '-u', '--chdir', '--close-from', '--group', '--host', '--prompt', '--role', '--type', '--user']);
      while (tokens[index] && tokens[index].startsWith('-')) {
        const option = tokens[index++];
        if (optionsWithValue.has(option)) index += 1;
      }
      continue;
    }
    break;
  }
  return tokens.slice(index);
}

function shellSegments(command, depth = 0) {
  if (depth > 8 || typeof command !== 'string') return [];
  const parsed = tokenizeShell(command);
  const segments = [];
  for (const original of parsed.segments) {
    if (path.basename(original[0] || '').toLowerCase() === 'env') {
      const splitIndex = original.findIndex((item) => item === '-S' || item === '--split-string');
      if (splitIndex >= 0 && original[splitIndex + 1]) {
        segments.push(...shellSegments(original[splitIndex + 1], depth + 1));
        continue;
      }
    }
    let tokens = unwrapCommand(original);
    if (!tokens.length) continue;
    while (tokens.length && /^(?:if|then|elif|else|fi|while|until|do|done|for|case|esac|select|time|!|\{|\})$/.test(tokens[0])) tokens = tokens.slice(1);
    if (!tokens.length) continue;
    segments.push(tokens);
    const executable = path.basename(tokens[0]).toLowerCase();
    if (['sh', 'bash', 'dash', 'zsh', 'ksh'].includes(executable)) {
      const commandIndex = tokens.findIndex((item, index) => index > 0 && (/^-[^-]*c/.test(item) || item === '--command'));
      if (commandIndex >= 0 && tokens[commandIndex + 1]) {
        segments.push(...shellSegments(tokens[commandIndex + 1], depth + 1));
      }
    }
    if (executable === 'xargs') {
      let commandIndex = 1;
      while (tokens[commandIndex] && tokens[commandIndex].startsWith('-')) {
        const option = tokens[commandIndex++];
        if (['-a', '--arg-file', '-d', '--delimiter', '-E', '-I', '--replace', '-L', '--max-lines', '-n', '--max-args', '-P', '--max-procs', '-s', '--max-chars'].includes(option)) commandIndex += 1;
      }
      if (tokens[commandIndex]) segments.push(tokens.slice(commandIndex));
    }
    if (executable === 'find') {
      for (let i = 1; i < tokens.length; i++) {
        if ((tokens[i] === '-exec' || tokens[i] === '-execdir') && tokens[i + 1]) {
          const end = tokens.findIndex((item, index) => index > i && (item === ';' || item === '+'));
          segments.push(tokens.slice(i + 1, end === -1 ? undefined : end));
        }
      }
    }
    if (executable === 'eval' && tokens[1]) {
      segments.push(...shellSegments(tokens.slice(1).join(' '), depth + 1));
    }
  }
  for (const substitution of parsed.substitutions) {
    segments.push(...shellSegments(substitution, depth + 1));
  }
  return segments;
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

function askPermission(reason) {
  output({
    hookSpecificOutput: {
      hookEventName: 'PreToolUse',
      permissionDecision: 'ask',
      permissionDecisionReason: reason
    }
  });
  process.exit(0);
}

function failOpen(hookName, category) {
  const remediation = 'Retry the action or inspect the hook installation.';
  log(hookName, { action: 'fail-open', category, remediation });
  output({
    systemMessage: `Autoresearch ${hookName} Guardrail unavailable: ${category}. ${remediation}`
  });
  process.exit(0);
}

// A run is active once the user invokes /autoresearch (or $autoresearch) in this
// session, or while a results TSV under ./autoresearch/ was written in the last
// 30 minutes. Guardrails that block or inject stay silent in every other session.
const RUN_INVOCATION = /(^|\s)[/$]autoresearch\b/i;

const RUN_SKILL = /^(autoresearch:)?autoresearch(:|$)/i;

// A run starts when the user types the command or the model loads the skill.
function promptInvokesRun(stdin) {
  if (!stdin) return false;
  if (typeof stdin.prompt === 'string' && RUN_INVOCATION.test(stdin.prompt)) return true;
  const skill = stdin.tool_name === 'Skill' && stdin.tool_input && stdin.tool_input.skill;
  return typeof skill === 'string' && RUN_SKILL.test(skill);
}

function markRunActiveFromPrompt(stdin) {
  if (!promptInvokesRun(stdin)) return false;
  const state = loadSessionState(stdin);
  if (!state.autoresearchActive) {
    state.autoresearchActive = true;
    saveSessionState(stdin, state);
  }
  return true;
}

function isRunActive(stdin) {
  // UserPromptSubmit hooks run in parallel, so the invoking prompt counts on its own.
  if (promptInvokesRun(stdin)) return true;
  try {
    if (loadSessionState(stdin).autoresearchActive) return true;
  } catch { /* unreadable state falls through to the TSV check */ }
  return Boolean(findRecentTsv(process.cwd(), 30));
}

module.exports = {
  isEnabled,
  isRunActive,
  markRunActiveFromPrompt,
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
  shellSegments,
  unwrapCommand,
  output,
  block,
  allow,
  inject,
  askPermission,
  failOpen
};
