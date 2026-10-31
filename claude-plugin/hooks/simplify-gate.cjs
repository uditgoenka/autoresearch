'use strict';

// UserPromptSubmit hook: warns or blocks shipping verbs when too many LOC changed.
// Fails open on any error — never blocks legitimate work due to hook malfunction.

const fs = require('fs');
const { execSync } = require('child_process');
const { isEnabled, isRunActive, safeParseStdin, log, block, inject, failOpen } = require('./lib/ar-hook-utils.cjs');

const HOOK_NAME = 'simplify-gate';

const SHIPPING_VERBS = ['ship', 'merge', 'deploy', 'pr', 'publish', 'release'];

const NEGATION_PHRASES = [
  "don't ship", "never deploy", "not ready to merge",
  "don't merge", "don't deploy", "don't publish",
  "don't release", "no ship", "no merge", "no deploy"
];

const WARN_THRESHOLD = 400;
const BLOCK_THRESHOLD = 800;

function hasShippingVerb(prompt) {
  const lower = prompt.toLowerCase();

  for (const phrase of NEGATION_PHRASES) {
    if (lower.includes(phrase)) return false;
  }

  for (const verb of SHIPPING_VERBS) {
    const regex = new RegExp('\\b' + verb + '\\b', 'i');
    if (regex.test(prompt)) return true;
  }

  return false;
}

function pendingLoc() {
  const diff = execSync('git diff HEAD --numstat', { encoding: 'utf8', timeout: 5000 });
  let loc = diff.trim().split('\n').filter(Boolean).reduce((total, line) => {
    const [added, removed] = line.split('\t');
    return total + (/^\d+$/.test(added) ? Number(added) : 0) + (/^\d+$/.test(removed) ? Number(removed) : 0);
  }, 0);
  const untracked = execSync('git ls-files --others --exclude-standard -z', { encoding: 'utf8', timeout: 5000 });
  for (const file of untracked.split('\0').filter(Boolean)) {
    const content = fs.readFileSync(file);
    // Skip binaries, matching git's own numstat rule (a NUL byte means binary).
    if (content.includes(0)) continue;
    loc += content.toString('utf8').split('\n').length - 1;
  }
  return loc;
}

try {
  if (!isEnabled(HOOK_NAME)) process.exit(0);

  const stdin = safeParseStdin(HOOK_NAME);
  if (!stdin || !isRunActive(stdin)) process.exit(0);

  const prompt = (stdin.prompt && typeof stdin.prompt === 'string') ? stdin.prompt : '';
  if (!prompt) process.exit(0);

  // Fast bail: no shipping verb detected
  if (!hasShippingVerb(prompt)) process.exit(0);

  let loc = 0;
  try {
    loc = pendingLoc();
  } catch {
    failOpen(HOOK_NAME, 'git-inspection-error');
  }

  if (loc < WARN_THRESHOLD) {
    process.exit(0);
  }

  log(HOOK_NAME, { loc, action: loc > BLOCK_THRESHOLD ? 'block' : 'warn' });

  if (loc > BLOCK_THRESHOLD) {
    block(
      `BLOCKED: ${loc} lines changed exceeds ${BLOCK_THRESHOLD} LOC shipping threshold. ` +
      `Simplify before shipping. Use AR_DISABLE_SIMPLIFY_GATE=1 to override.`
    );
  }

  // 400–800 range: warn but allow
  inject(
    `WARNING: ${loc} lines changed. Consider simplifying before shipping.`
  );
} catch {
  failOpen(HOOK_NAME, 'internal-error');
}
