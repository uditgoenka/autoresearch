'use strict';

// PreToolUse hook: blocks file access to directories matching .ckignore patterns.
// Fails open on any error — never blocks legitimate work due to hook malfunction.

const fs = require('fs');
const path = require('path');
const { isEnabled, isRunActive, safeParseStdin, log, block, failOpen, shellSegments } = require('./lib/ar-hook-utils.cjs');
const ignore = require('./lib/ignore.cjs');

const HOOK_NAME = 'scout-block';

const BASELINE_PATTERNS = [
  'node_modules/',
  '__pycache__/',
  '.git/',
  'dist/',
  'build/',
  'out/',
  'coverage/',
  '.next/',
  '.nuxt/',
  'venv/',
  '.venv/',
  'env/',
  '.terraform/',
  '.aws/',
  '.ssh/',
  '*.log'
];

function findProjectRoot(startDir) {
  let dir = startDir;
  for (let i = 0; i < 20; i++) {
    if (fs.existsSync(path.join(dir, '.git'))) return dir;
    const parent = path.dirname(dir);
    if (parent === dir) break;
    dir = parent;
  }
  return startDir;
}

function loadCkIgnore(projectRoot) {
  const ig = ignore();
  ig.add(BASELINE_PATTERNS);
  try {
    const ckPath = path.join(projectRoot, '.ckignore');
    const content = fs.readFileSync(ckPath, 'utf8');
    ig.add(content);
  } catch { /* no .ckignore — baseline only */ }
  return ig;
}

function relativeToRoot(filePath, projectRoot) {
  const abs = path.isAbsolute(filePath) ? filePath : path.resolve(process.cwd(), filePath);
  const rel = path.relative(projectRoot, abs);
  // If the path escapes the project root, use the absolute path for matching.
  return (rel.startsWith('..') ? abs : rel).replace(/\\/g, '/');
}

// Extract path-like tokens from a bash command string.
// Splits on spaces, pipes, semicolons, and common shell operators.
function isRemoteOperand(token) {
  if (/^[a-zA-Z]:[\\/]/.test(token)) return false;
  return /^[^/\s:]+(?:@[^/\s:]+)?:/.test(token);
}

function extractPathTokens(command) {
  const tokens = [];
  for (const segmentTokens of shellSegments(command)) {
    const executable = path.basename(segmentTokens[0] || '');
    const remoteShell = executable === 'ssh' || executable === 'tsh';
    if (remoteShell) {
      const localPathOptions = new Set(['-i', '-F', '-E', '-S']);
      const optionsWithValue = new Set(['-B', '-b', '-c', '-D', '-e', '-I', '-J', '-L', '-l', '-m', '-O', '-p', '-Q', '-R', '-W', '-w']);
      for (let i = 1; i < segmentTokens.length; i++) {
        const token = segmentTokens[i];
        if (localPathOptions.has(token) && segmentTokens[i + 1]) {
          tokens.push(segmentTokens[++i]);
        } else if (/^-[iFES].+/.test(token)) {
          tokens.push(token.slice(2));
        } else if (token === '-o' && segmentTokens[i + 1]) {
          const value = segmentTokens[++i];
          const match = value.match(/^(?:IdentityFile|UserKnownHostsFile|GlobalKnownHostsFile|CertificateFile)(?:=|\s+)(.+)$/i);
          if (match) tokens.push(match[1]);
        } else if (/^-o(?:IdentityFile|UserKnownHostsFile|GlobalKnownHostsFile|CertificateFile)=/i.test(token)) {
          tokens.push(token.slice(token.indexOf('=') + 1));
        } else if (optionsWithValue.has(token)) {
          i += 1;
        } else if (!token.startsWith('-')) {
          break;
        }
      }
      continue;
    }
    if (['echo', 'printf'].includes(executable)) continue;
    const candidates = (executable === 'grep' || executable === 'sed' || executable === 'awk')
      ? segmentTokens.slice(2)
      : segmentTokens;
    for (const token of candidates) {
      if (!isRemoteOperand(token)) tokens.push(token);
    }
  }
  return tokens.filter(t => {
    if (!t || t.startsWith('-')) return false;
    // A token looks like a path if it contains '/' or starts with '.' or contains a file extension
    return t.includes('/') || t.startsWith('.') || /\.[a-z]{1,6}$/.test(t);
  });
}

function checkPath(filePath, ig, projectRoot) {
  if (!filePath || typeof filePath !== 'string') return null;
  const rel = relativeToRoot(filePath, projectRoot);
  if (ig.ignores(rel)) return rel;
  return null;
}

try {
  if (!isEnabled(HOOK_NAME)) {
    process.exit(0);
  }

  const stdin = safeParseStdin(HOOK_NAME);
  if (!stdin || !isRunActive(stdin)) {
    process.exit(0);
  }

  const { tool_name, tool_input } = stdin;
  if (!tool_input) {
    process.exit(0);
  }

  const projectRoot = findProjectRoot(process.cwd());
  const ig = loadCkIgnore(projectRoot);

  // Bash: smart token extraction with build-tool allowlist
  if (tool_name === 'Bash') {
    const command = tool_input.command || '';
    const pathTokens = extractPathTokens(command);
    for (const token of pathTokens) {
      const matched = checkPath(token, ig, projectRoot);
      if (matched) {
        log(HOOK_NAME, { action: 'block', tool: tool_name, path: token, matched });
        block(
          `BLOCKED: Access to '${matched}' denied by .ckignore\n\n` +
          `To allow, add to .ckignore: !${matched}`
        );
      }
    }
    process.exit(0);
  }

  // Structured tools: Read, Edit, Write, Glob, Grep
  const STRUCTURED_TOOLS = new Set(['Read', 'Edit', 'Write', 'Glob', 'Grep']);
  if (STRUCTURED_TOOLS.has(tool_name)) {
    const filePath = tool_input.file_path || tool_input.path || '';
    const matched = checkPath(filePath, ig, projectRoot);
    if (matched) {
      log(HOOK_NAME, { action: 'block', tool: tool_name, path: filePath, matched });
      block(
        `BLOCKED: Access to '${matched}' denied by .ckignore\n\n` +
        `To allow, add to .ckignore: !${matched}`
      );
    }
  }

  process.exit(0);
} catch {
  failOpen(HOOK_NAME, 'internal-error');
}
