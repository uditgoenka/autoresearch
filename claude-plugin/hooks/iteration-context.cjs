'use strict';

const path = require('path');

const {
  isEnabled, safeParseStdin, loadSessionState, saveSessionState,
  incrementCounter, markRunActiveFromPrompt, log, readTsvTail, findRecentTsv, inject, failOpen
} = require('./lib/ar-hook-utils.cjs');

const HOOK_NAME = 'iteration-context';

const AR_COMMANDS = [
  'autoresearch', '/autoresearch:', 'loop', 'debug', 'fix', 'scenario',
  'predict', 'learn', 'reason', 'probe', 'security', 'ship'
];

function hasArCommand(prompt) {
  if (!prompt || typeof prompt !== 'string') return false;
  const lower = prompt.toLowerCase();
  return AR_COMMANDS.some(cmd => lower.includes(cmd));
}

function formatRows(header, rows) {
  const lines = [];
  if (header) lines.push(header);
  rows.forEach(r => lines.push(r));
  return lines.join('\n');
}

function relativePath(cwd, absPath) {
  try {
    return path.relative(cwd, absPath);
  } catch {
    return absPath;
  }
}

try {
  if (!isEnabled(HOOK_NAME)) process.exit(0);

  const stdin = safeParseStdin(HOOK_NAME);
  if (!stdin) process.exit(0);

  markRunActiveFromPrompt(stdin);

  const state = loadSessionState(stdin);
  const iterationCount = incrementCounter(stdin, 'iterationCount');

  // Throttle: only inject every 5th prompt
  if (iterationCount % 5 !== 0) {
    log('iteration-context', { action: 'skip', iterationCount });
    process.exit(0);
  }

  // Mark injection time so dev-rules-reminder can skip this turn
  const freshState = loadSessionState(stdin);
  freshState.lastContextInjection = Date.now();
  saveSessionState(stdin, freshState);

  const cwd = process.cwd();
  const tsvPath = findRecentTsv(cwd, 30);

  if (!tsvPath) {
    log('iteration-context', { action: 'skip', iterationCount, reason: 'no-tsv' });
    process.exit(0);
  }

  const tsv = readTsvTail(tsvPath, 3);
  if (!tsv) {
    log('iteration-context', { action: 'skip', iterationCount, reason: 'tsv-unreadable' });
    process.exit(0);
  }

  const relTsv = relativePath(cwd, tsvPath);
  const rowBlock = formatRows(tsv.header, tsv.rows);

  let text = `## Active iteration state\n**TSV:** ${relTsv}\n**Iteration:** ${iterationCount} | **Rows:** ${tsv.total}\n\n${rowBlock}`;

  // Append loop state info when prompt contains autoresearch command content
  if (hasArCommand(stdin.prompt || '')) {
    text += `\n\n**Loop state:** active — ${tsv.total} iterations recorded, last 3 rows above`;
  }

  log('iteration-context', { action: 'inject', iterationCount, tsvRows: tsv.total });
  inject(text);
} catch {
  failOpen(HOOK_NAME, 'internal-error');
}
