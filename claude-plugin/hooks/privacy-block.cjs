'use strict';

// PreToolUse hook: escalates clear sensitive-file access to the host permission UI.
// Fails open on any error — never blocks legitimate work due to hook malfunction.

const path = require('path');
const { isEnabled, safeParseStdin, log, askPermission, inject, failOpen, shellSegments } = require('./lib/ar-hook-utils.cjs');

const HOOK_NAME = 'privacy-block';

const SENSITIVE_PATTERNS = [
  '.env',
  '.env.local',
  '.env.production',
  '.env.development',
  '.pem',
  '.key',
  '.p12',
  '.pfx',
  'id_rsa',
  'id_ed25519',
  '.ssh/',
  'credentials.json',
  'credentials.yaml',
  'secret',
  'api_key',
  'apikey',
  '.aws/credentials'
];

const ALLOWED_EXCEPTIONS = [
  '.env.example',
  '.env.sample',
  '.env.template',
  '.env.test'
];

function basename(filePath) {
  return path.basename(filePath).toLowerCase();
}

function isSensitive(filePath) {
  if (!filePath || typeof filePath !== 'string') return false;
  const normalized = filePath.replace(/\\/g, '/').toLowerCase();
  const base = basename(filePath);

  // Check exceptions first
  for (const exc of ALLOWED_EXCEPTIONS) {
    if (base === exc || normalized.endsWith('/' + exc)) return false;
  }

  // Check sensitive patterns
  for (const pattern of SENSITIVE_PATTERNS) {
    const lp = pattern.toLowerCase();
    if (
      base === lp ||
      normalized.endsWith('/' + lp) ||
      normalized.endsWith(lp) ||
      normalized.includes('/' + lp + '/') ||
      base.includes(lp)
    ) {
      return true;
    }
  }

  return false;
}

function isRemoteOperand(token) {
  if (/^[a-zA-Z]:[\\/]/.test(token)) return false;
  return /^[^/\s:]+(?:@[^/\s:]+)?:/.test(token);
}

function bashSensitivity(command) {
  const clearOperations = new Set([
    'cat', 'head', 'tail', 'less', 'more', 'grep', 'cp', 'mv', 'scp', 'rsync',
    'curl', 'wget', 'tee', 'sed', 'awk', 'chmod', 'chown', 'rm', 'truncate',
    'source', '.'
  ]);

  for (const tokens of shellSegments(command)) {
    const executable = path.basename(tokens[0] || '').toLowerCase();
    if (clearOperations.has(executable)) {
      const operands = (executable === 'grep' || executable === 'sed' || executable === 'awk')
        ? tokens.slice(2)
        : tokens.slice(1);
      for (const token of operands) {
        const operand = token.replace(/^(?:--upload-file|-T|--data-binary|--data|--data-raw|--output|-o)=?/, '');
        if (operand && !operand.startsWith('-') && !isRemoteOperand(operand) && isSensitive(operand)) return 'clear';
      }
    }
    for (let i = 0; i < tokens.length - 1; i++) {
      if (/^(?:>|>>|<|<<)$/.test(tokens[i]) && isSensitive(tokens[i + 1])) return 'clear';
    }
  }

  const lower = command.toLowerCase();
  return SENSITIVE_PATTERNS.some((pattern) => lower.includes(pattern.toLowerCase()))
    ? 'ambiguous'
    : 'none';
}

try {
  if (!isEnabled(HOOK_NAME)) {
    process.exit(0);
  }

  const stdin = safeParseStdin(HOOK_NAME);
  if (!stdin) {
    process.exit(0);
  }

  const { tool_name, tool_input } = stdin;
  if (!tool_input) {
    process.exit(0);
  }

  const STRUCTURED_TOOLS = new Set(['Read', 'Edit', 'Write', 'Glob', 'Grep']);

  if (STRUCTURED_TOOLS.has(tool_name)) {
    const rawPath = tool_input.file_path || tool_input.path || '';

    if (isSensitive(rawPath)) {
      log(HOOK_NAME, { action: 'ask', tool: tool_name, category: 'sensitive-file' });
      askPermission('This operation targets a potentially sensitive file. Confirm access in the host permission prompt.');
    }

    process.exit(0);
  }

  if (tool_name === 'Bash') {
    const command = tool_input.command || '';
    const sensitivity = bashSensitivity(command);
    if (sensitivity === 'clear') {
      log(HOOK_NAME, { action: 'ask', tool: tool_name, category: 'sensitive-command' });
      askPermission('This command clearly accesses a potentially sensitive file. Confirm access in the host permission prompt.');
    }
    if (sensitivity === 'ambiguous') {
      log(HOOK_NAME, { action: 'warn', tool: tool_name, category: 'ambiguous-sensitive-text' });
      inject('WARNING: The command contains sensitive-looking text. Confirm that it does not expose credentials.');
    }
  }

  process.exit(0);
} catch {
  failOpen(HOOK_NAME, 'internal-error');
}
