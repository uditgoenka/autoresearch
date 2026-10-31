'use strict';

// PreToolUse hook: blocks destructive bash commands.
// Regular `git push` is allowed — only force-push variants and hard-destructive ops are blocked.
// Fails open on any error — never blocks legitimate work due to hook malfunction.

const { isEnabled, isRunActive, safeParseStdin, log, block, failOpen, shellSegments } = require('./lib/ar-hook-utils.cjs');

const HOOK_NAME = 'dangerous-cmd-block';

function gitSubcommandIndex(words) {
  const optionsWithValue = new Set([
    '-C', '-c', '--exec-path', '--git-dir', '--work-tree', '--namespace',
    '--super-prefix', '--config-env'
  ]);
  let index = 1;
  while (index < words.length) {
    const option = words[index];
    if (option === '--') return index + 1;
    if (!option.startsWith('-')) return index;
    if (optionsWithValue.has(option)) {
      index += 2;
    } else if (
      option.startsWith('-C') || option.startsWith('-c') ||
      [...optionsWithValue].some((name) => name.startsWith('--') && option.startsWith(name + '='))
    ) {
      index += 1;
    } else {
      index += 1;
    }
  }
  return -1;
}

// --force-with-lease and --force-if-includes refuse to overwrite commits the
// pusher has not seen, so they are allowed; plain -f/--force are not.
function isForcePushArg(arg) {
  return arg === '-f' || arg === '--force' || /^-[^-]*f/.test(arg) || arg.startsWith('+');
}

function commandLabel(command) {
  for (const words of shellSegments(command)) {
    const executable = require('path').basename(words[0] || '');
    if (executable === 'push' && words.slice(1).some(isForcePushArg)) return 'forced push';
    if (executable === 'rm') {
      const rmArgs = words.slice(1);
      const short = rmArgs.filter((word) => /^-[^-]/.test(word)).join('');
      const recursive = /[rR]/.test(short) || rmArgs.includes('--recursive');
      const force = short.includes('f') || rmArgs.includes('--force');
      if (recursive && force) return 'recursive forced removal';
    }
    if (executable !== 'git') continue;
    const subcommandIndex = gitSubcommandIndex(words);
    const subcommand = words[subcommandIndex];
    const args = words.slice(subcommandIndex + 1);
    if (subcommand === 'push' && args.some(isForcePushArg)) return 'forced git push';
    if (subcommand === 'reset' && args.includes('--hard')) return 'hard git reset';
    if (subcommand === 'clean' && args.some((arg) => /^-[^-]*f/.test(arg) || arg === '--force')) return 'forced git clean';
    if (subcommand === 'branch') {
      const flags = args.filter((arg) => arg.startsWith('-'));
      const hasDelete = flags.some((arg) => arg === '--delete' || /^-[^-]*[dD]/.test(arg));
      const hasForce = flags.some((arg) => arg === '--force' || /^-[^-]*[fD]/.test(arg));
      if (hasDelete && hasForce) return 'forced branch deletion';
    }
    if ((subcommand === 'checkout' || subcommand === 'restore') && args.includes('.')) return `git ${subcommand} of working tree`;
  }
  return null;
}

try {
  if (!isEnabled(HOOK_NAME)) {
    process.exit(0);
  }

  const stdin = safeParseStdin(HOOK_NAME);
  if (!stdin || stdin.tool_name !== 'Bash' || !isRunActive(stdin)) {
    process.exit(0);
  }

  const command = (stdin.tool_input && stdin.tool_input.command) || '';

  const label = commandLabel(command);
  if (label) {
    log(HOOK_NAME, { action: 'block', matched: label });
    block(`BLOCKED: Destructive command detected (${label}). This command is blocked while an autoresearch run is active. Set AR_DISABLE_DANGEROUS_CMD_BLOCK=1 to override.`);
  }

  process.exit(0);
} catch {
  failOpen(HOOK_NAME, 'internal-error');
}
