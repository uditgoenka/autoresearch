'use strict';

const path = require('path');

const {
  isEnabled, safeParseStdin, loadSessionState,
  log, readTsvTail, findRecentTsv, inject, failOpen
} = require('./lib/ar-hook-utils.cjs');

const HOOK_NAME = 'subagent-context';

function relativePath(cwd, absPath) {
  try {
    return path.relative(cwd, absPath);
  } catch {
    return absPath;
  }
}

function summarizeLastRow(header, row) {
  if (!row) return 'none';
  // Try to extract status + first numeric metric from the row
  const headerCols = header ? header.split(/\t|\|/) : [];
  const rowCols = row.split(/\t|\|/);
  const parts = [];
  rowCols.forEach((val, i) => {
    const col = (headerCols[i] || '').toLowerCase();
    if (col.includes('status') || col.includes('result') || col.includes('pass') || col.includes('fail')) {
      parts.push(val.trim());
    } else if (/^-?\d+(\.\d+)?$/.test(val.trim()) && parts.length < 3) {
      const label = headerCols[i] ? headerCols[i].trim() + '=' : '';
      parts.push(label + val.trim());
    }
  });
  return parts.length > 0 ? parts.join(', ') : rowCols.slice(0, 3).join(', ');
}

try {
  if (!isEnabled(HOOK_NAME)) process.exit(0);

  const stdin = safeParseStdin(HOOK_NAME);
  if (!stdin) process.exit(0);

  const state = loadSessionState(stdin);
  const cwd = process.cwd();
  const tsvPath = findRecentTsv(cwd, 30);

  if (!tsvPath) {
    log('subagent-context', { action: 'skip', reason: 'no-active-tsv' });
    process.exit(0);
  }

  const tsv = readTsvTail(tsvPath, 1);
  const relTsv = relativePath(cwd, tsvPath);
  const latestSummary = tsv ? summarizeLastRow(tsv.header, tsv.rows[0]) : 'none';

  const text = [
    '## Autoresearch context (for subagent)',
    `- Project: ${state.projectRoot || cwd}`,
    `- Branch: ${state.gitBranch || 'unknown'}`,
    `- Plans: ${state.plansPath || path.join(cwd, 'plans')}`,
    `- Reports: ${state.reportsPath || path.join(cwd, 'plans', 'reports')}`,
    `- Active TSV: ${relTsv}`,
    `- Iteration: ${state.iterationCount || 0}`,
    `- Latest: ${latestSummary}`
  ].join('\n');

  log('subagent-context', { action: 'inject', subagentType: stdin.subagent_type || 'unknown' });
  inject(text);
} catch {
  failOpen(HOOK_NAME, 'internal-error');
}
