'use strict';

// PreToolUse hook on Skill: marks the session's run active when the model
// loads the autoresearch skill, so guards cover runs nobody typed.

const { isEnabled, markRunActiveFromPrompt, safeParseStdin, failOpen } = require('./lib/ar-hook-utils.cjs');

const HOOK_NAME = 'run-marker';

try {
  if (!isEnabled(HOOK_NAME)) process.exit(0);
  const stdin = safeParseStdin(HOOK_NAME);
  if (stdin) markRunActiveFromPrompt(stdin);
} catch {
  failOpen(HOOK_NAME, 'internal-error');
}
