'use strict';

const path = require('path');

const {
  isEnabled, isRunActive, safeParseStdin, loadSessionState,
  log, inject, failOpen
} = require('./lib/ar-hook-utils.cjs');

const HOOK_NAME = 'dev-rules-reminder';

try {
  if (!isEnabled(HOOK_NAME)) process.exit(0);

  const stdin = safeParseStdin(HOOK_NAME);
  if (!stdin || !isRunActive(stdin)) process.exit(0);

  const state = loadSessionState(stdin);

  // Skip if iteration-context already injected this same turn (within 2 seconds)
  if (state.lastContextInjection && (Date.now() - state.lastContextInjection) < 2000) {
    log('dev-rules-reminder', { action: 'skip', reason: 'iteration-context-fired' });
    process.exit(0);
  }

  // Only inject on every 5th iteration, same cadence as iteration-context
  if ((state.iterationCount || 0) % 5 !== 0) {
    process.exit(0);
  }

  const plansPath = state.plansPath || path.join(process.cwd(), 'plans');

  const text = [
    '## Dev context',
    `- Plan: ${plansPath} (check for active plan.md)`,
    '- Standards: docs/code-standards.md'
  ].join('\n');

  log('dev-rules-reminder', { action: 'inject', iterationCount: state.iterationCount });
  inject(text);
} catch {
  failOpen(HOOK_NAME, 'internal-error');
}
