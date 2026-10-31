// dangerous-cmd-block — ported from claude-plugin/hooks/dangerous-cmd-block.cjs.
// Blocks destructive bash commands: forced push, recursive forced rm, hard git
// reset, forced git clean, forced branch deletion, checkout/restore of the
// working tree. Regular `git push` is allowed. Fails open on any error.

import { basename } from "node:path";
import { shellSegments } from "../lib/shell.js";
import { isHookEnabled, log } from "../lib/session-state.js";

const HOOK_NAME = "dangerous-cmd-block";

function gitSubcommandIndex(words: string[]): number {
  const optionsWithValue = new Set([
    "-C",
    "-c",
    "--exec-path",
    "--git-dir",
    "--work-tree",
    "--namespace",
    "--super-prefix",
    "--config-env",
  ]);
  let index = 1;
  while (index < words.length) {
    const option = words[index];
    if (option === "--") return index + 1;
    if (!option.startsWith("-")) return index;
    if (optionsWithValue.has(option)) {
      index += 2;
    } else if (
      option.startsWith("-C") ||
      option.startsWith("-c") ||
      [...optionsWithValue].some(
        (name) => name.startsWith("--") && option.startsWith(name + "="),
      )
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
function isForcePushArg(arg: string): boolean {
  return arg === "-f" || arg === "--force" || /^-[^-]*f/.test(arg) || arg.startsWith("+");
}

export function commandLabel(command: string): string | null {
  for (const words of shellSegments(command)) {
    const executable = basename(words[0] || "");
    if (
      executable === "push" &&
      words.slice(1).some(isForcePushArg)
    )
      return "forced push";
    if (executable === "rm") {
      const rmArgs = words.slice(1);
      const short = rmArgs.filter((word) => /^-[^-]/.test(word)).join("");
      const recursive = /[rR]/.test(short) || rmArgs.includes("--recursive");
      const force = short.includes("f") || rmArgs.includes("--force");
      if (recursive && force) return "recursive forced removal";
    }
    if (executable !== "git") continue;
    const subcommandIndex = gitSubcommandIndex(words);
    const subcommand = words[subcommandIndex];
    const args = words.slice(subcommandIndex + 1);
    if (subcommand === "push" && args.some(isForcePushArg))
      return "forced git push";
    if (subcommand === "reset" && args.includes("--hard")) return "hard git reset";
    if (subcommand === "clean" && args.some((arg) => /^-[^-]*f/.test(arg) || arg === "--force"))
      return "forced git clean";
    if (subcommand === "branch") {
      const flags = args.filter((arg) => arg.startsWith("-"));
      const hasDelete = flags.some((arg) => arg === "--delete" || /^-[^-]*[dD]/.test(arg));
      const hasForce = flags.some((arg) => arg === "--force" || /^-[^-]*[fD]/.test(arg));
      if (hasDelete && hasForce) return "forced branch deletion";
    }
    if ((subcommand === "checkout" || subcommand === "restore") && args.includes("."))
      return `git ${subcommand} of working tree`;
  }
  return null;
}

export interface DangerousCmdResult {
  block?: boolean;
  reason?: string;
}

export function checkDangerousCommand(command: string): DangerousCmdResult {
  if (!isHookEnabled(HOOK_NAME)) return {};
  try {
    const label = commandLabel(command);
    if (label) {
      log(HOOK_NAME, { action: "block", matched: label });
      return {
        block: true,
        reason: `BLOCKED: Destructive command detected (${label}). This command is blocked during autoresearch sessions.`,
      };
    }
  } catch {
    // fail-open
  }
  return {};
}
