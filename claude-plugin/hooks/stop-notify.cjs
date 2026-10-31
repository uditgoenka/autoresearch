'use strict';

// SessionEnd hook: sends terminal notification and optional webhook when session terminates.
// Cleans up session state file after firing. Fails open on any error.

const fs = require('fs');
const http = require('http');
const https = require('https');
const path = require('path');
const url = require('url');

const {
  isEnabled, safeParseStdin, loadSessionState, sessionStatePath,
  log, findRecentTsv, readTsvTail, output, failOpen
} = require('./lib/ar-hook-utils.cjs');

const HOOK_NAME = 'stop-notify';

function formatDuration(startedAt) {
  if (!startedAt) return 'unknown';
  const ms = Date.now() - new Date(startedAt).getTime();
  if (ms < 0) return 'unknown';
  const totalSeconds = Math.floor(ms / 1000);
  const hours = Math.floor(totalSeconds / 3600);
  const minutes = Math.floor((totalSeconds % 3600) / 60);
  const seconds = totalSeconds % 60;
  if (hours > 0) return `${hours}h ${minutes}m`;
  return `${minutes}m ${seconds}s`;
}

function buildTsvSummary(projectRoot) {
  const tsvPath = findRecentTsv(projectRoot, 120); // look back 2 hours on session end
  if (!tsvPath) return { text: 'no iterations recorded', iterations: 0 };

  const tsv = readTsvTail(tsvPath, 1);
  if (!tsv) return { text: 'no iterations recorded', iterations: 0 };

  const lastRow = tsv.rows[0] || '';
  const metricMatch = lastRow.match(/[\t|]([0-9.-]+)(?:[\t|]|$)/);
  const metric = metricMatch ? metricMatch[1] : 'n/a';

  return {
    text: `${tsv.total} iterations, metric: ${metric}`,
    iterations: tsv.total
  };
}

function postWebhook(webhookUrl, payload) {
  return new Promise((resolve) => {
    try {
      const parsed = new url.URL(webhookUrl);
      const client = parsed.protocol === 'http:' ? http : https;
      const body = JSON.stringify(payload);
      const options = {
        hostname: parsed.hostname,
        port: parsed.port || (parsed.protocol === 'https:' ? 443 : 80),
        path: parsed.pathname + parsed.search,
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Content-Length': Buffer.byteLength(body)
        }
      };
      const req = client.request(options, (response) => {
        response.resume();
        response.on('end', resolve);
      });
      req.setTimeout(2000, () => req.destroy());
      req.on('error', resolve);
      req.write(body);
      req.end();
    } catch { resolve(); }
  });
}

function cleanupSessionFile(stdin) {
  try {
    fs.unlinkSync(sessionStatePath(stdin));
  } catch { /* already gone or unwritable */ }
}

async function main() {
  try {
    if (!isEnabled(HOOK_NAME)) process.exit(0);

    const stdin = safeParseStdin(HOOK_NAME);
    if (!stdin) process.exit(0);

    const state = loadSessionState(stdin);
    const duration = formatDuration(state.startedAt);
    const tsvSummary = buildTsvSummary(state.projectRoot || process.cwd());
    const projectName = path.basename(state.projectRoot || process.cwd());

    const notifyText = `autoresearch;Session completed — ${projectName} (${duration})`;
    const result = {
      terminalSequence: '\x1b]777;notify;' + notifyText + '\x07'
    };

    // Optional webhook is bounded and awaited so the process cannot exit early.
    const webhookUrl = process.env.AR_NOTIFY_WEBHOOK;
    if (webhookUrl) {
      await postWebhook(webhookUrl, {
        text: 'autoresearch session completed',
        project: projectName,
        branch: state.gitBranch || '',
        duration,
        tsv_summary: tsvSummary.text
      });
    }

    log(HOOK_NAME, { projectName, duration, iterations: tsvSummary.iterations });

    cleanupSessionFile(stdin);

    output(result);
    process.exit(0);
  } catch {
    failOpen(HOOK_NAME, 'internal-error');
  }
}

main();
