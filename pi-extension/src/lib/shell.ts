// Shell tokenizer — ported from claude-plugin/hooks/lib/ar-hook-utils.cjs.
// Splits a shell command into segments of tokens, unwrapping wrappers
// (env/sudo/nohup/exec/command/builtin), sh -c, xargs, find -exec, eval,
// and $()/`` substitutions. Used by the guardrail hooks to inspect what a
// bash command actually does without executing it.

import { basename } from "node:path";

export interface ShellSegment extends Array<string> {}

export interface TokenizeResult {
  segments: string[][];
  substitutions: string[];
}

function tokenizeShell(command: string): TokenizeResult {
  const segments: string[][] = [];
  const substitutions: string[] = [];
  let tokens: string[] = [];
  let token = "";
  let quote = "";
  let lineStart = true;
  let heredocDelimiter = "";

  const pushToken = () => {
    if (token) tokens.push(token);
    token = "";
  };
  const pushSegment = () => {
    pushToken();
    if (tokens.length) segments.push(tokens);
    tokens = [];
  };

  for (let i = 0; i < command.length; i++) {
    const char = command[i];
    if (heredocDelimiter && lineStart) {
      const lineEnd = command.indexOf("\n", i);
      const end = lineEnd === -1 ? command.length : lineEnd;
      if (command.slice(i, end).trim() === heredocDelimiter) heredocDelimiter = "";
      i = lineEnd === -1 ? command.length : lineEnd;
      lineStart = true;
      continue;
    }
    if (char === "\\" && quote !== "'") {
      if (i + 1 < command.length) token += command[++i];
      continue;
    }
    if (char === "'" || char === '"') {
      if (!quote) quote = char;
      else if (quote === char) quote = "";
      else token += char;
      continue;
    }
    if (char === "$" && command[i + 1] === "(" && quote !== "'") {
      let depth = 1;
      let inner = "";
      let innerQuote = "";
      i += 2;
      for (; i < command.length && depth > 0; i++) {
        const current = command[i];
        if (current === "\\" && innerQuote !== "'" && i + 1 < command.length) {
          inner += current + command[++i];
        } else if (current === "'" || current === '"') {
          if (!innerQuote) innerQuote = current;
          else if (innerQuote === current) innerQuote = "";
          inner += current;
        } else if (!innerQuote && current === "(") {
          depth += 1;
          inner += current;
        } else if (!innerQuote && current === ")" && --depth === 0) {
          break;
        } else {
          inner += current;
        }
      }
      i -= 1;
      substitutions.push(inner);
      token += "$()";
      continue;
    }
    if (char === "`" && quote !== "'") {
      let inner = "";
      for (i += 1; i < command.length && command[i] !== "`"; i++) {
        if (command[i] === "\\" && i + 1 < command.length)
          inner += command[i++] + command[i];
        else inner += command[i];
      }
      substitutions.push(inner);
      token += "``";
      continue;
    }
    if (!quote && /[\t ]/.test(char)) {
      pushToken();
      continue;
    }
    if (!quote && char === "#" && !token) {
      pushSegment();
      const lineEnd = command.indexOf("\n", i);
      if (lineEnd === -1) break;
      i = lineEnd - 1;
      lineStart = true;
      continue;
    }
    if (
      !quote &&
      (char === "\n" ||
        char === ";" ||
        char === "|" ||
        char === "&" ||
        char === "(" ||
        char === ")")
    ) {
      pushSegment();
      if (char === "|" && command[i + 1] === "|") i += 1;
      if (char === "&" && command[i + 1] === "&") i += 1;
      lineStart = char === "\n";
      continue;
    }
    if (!quote && (char === "<" || char === ">")) {
      pushToken();
      let redirect = char;
      while (command[i + 1] === char) redirect += command[++i];
      tokens.push(redirect);
      if (redirect === "<<") {
        let next = i + 1;
        // `<<-` strips leading tabs from the body; the delimiter follows the dash.
        if (command[next] === "-") next += 1;
        while (/[\t ]/.test(command[next] || "")) next += 1;
        const match = command
          .slice(next)
          .match(/^(?:['"]([^'"]+)['"]|([^\s;|&]+))/);
        if (match) heredocDelimiter = match[1] || match[2];
      }
      continue;
    }
    token += char;
    lineStart = false;
  }
  pushSegment();
  return { segments, substitutions };
}

function unwrapCommand(tokens: string[]): string[] {
  let index = 0;
  while (index < tokens.length) {
    if (/^[A-Za-z_][A-Za-z0-9_]*=/.test(tokens[index])) {
      index += 1;
      continue;
    }
    const executable = basename(tokens[index]).toLowerCase();
    if (
      executable === "command" ||
      executable === "builtin" ||
      executable === "nohup" ||
      executable === "exec"
    ) {
      index += 1;
      while (tokens[index] && tokens[index].startsWith("-")) index += 1;
      continue;
    }
    if (executable === "env") {
      index += 1;
      while (tokens[index]) {
        const option = tokens[index];
        if (/^[A-Za-z_][A-Za-z0-9_]*=/.test(option)) index += 1;
        else if (option === "-S" || option === "--split-string") return [];
        else if (["-u", "--unset", "-C", "--chdir"].includes(option)) index += 2;
        else if (option.startsWith("-")) index += 1;
        else break;
      }
      continue;
    }
    if (executable === "sudo") {
      index += 1;
      const optionsWithValue = new Set([
        "-C",
        "-D",
        "-g",
        "-h",
        "-p",
        "-R",
        "-r",
        "-T",
        "-t",
        "-U",
        "-u",
        "--chdir",
        "--close-from",
        "--group",
        "--host",
        "--prompt",
        "--role",
        "--type",
        "--user",
      ]);
      while (tokens[index] && tokens[index].startsWith("-")) {
        const option = tokens[index++];
        if (optionsWithValue.has(option)) index += 1;
      }
      continue;
    }
    break;
  }
  return tokens.slice(index);
}

export function shellSegments(command: string, depth = 0): string[][] {
  if (depth > 8 || typeof command !== "string") return [];
  const parsed = tokenizeShell(command);
  const segments: string[][] = [];
  for (const original of parsed.segments) {
    if (basename(original[0] || "").toLowerCase() === "env") {
      const splitIndex = original.findIndex(
        (item) => item === "-S" || item === "--split-string",
      );
      if (splitIndex >= 0 && original[splitIndex + 1]) {
        segments.push(...shellSegments(original[splitIndex + 1], depth + 1));
        continue;
      }
    }
    let tokens = unwrapCommand(original);
    if (!tokens.length) continue;
    while (
      tokens.length &&
      /^(?:if|then|elif|else|fi|while|until|do|done|for|case|esac|select|time|!|\{|\})$/.test(
        tokens[0],
      )
    )
      tokens = tokens.slice(1);
    if (!tokens.length) continue;
    segments.push(tokens);
    const executable = basename(tokens[0]).toLowerCase();
    if (["sh", "bash", "dash", "zsh", "ksh"].includes(executable)) {
      const commandIndex = tokens.findIndex(
        (item, index) =>
          index > 0 && (/^-[^-]*c/.test(item) || item === "--command"),
      );
      if (commandIndex >= 0 && tokens[commandIndex + 1]) {
        segments.push(...shellSegments(tokens[commandIndex + 1], depth + 1));
      }
    }
    if (executable === "xargs") {
      let commandIndex = 1;
      while (tokens[commandIndex] && tokens[commandIndex].startsWith("-")) {
        const option = tokens[commandIndex++];
        if (
          [
            "-a",
            "--arg-file",
            "-d",
            "--delimiter",
            "-E",
            "-I",
            "--replace",
            "-L",
            "--max-lines",
            "-n",
            "--max-args",
            "-P",
            "--max-procs",
            "-s",
            "--max-chars",
          ].includes(option)
        )
          commandIndex += 1;
      }
      if (tokens[commandIndex]) segments.push(tokens.slice(commandIndex));
    }
    if (executable === "find") {
      for (let i = 1; i < tokens.length; i++) {
        if (
          (tokens[i] === "-exec" || tokens[i] === "-execdir") &&
          tokens[i + 1]
        ) {
          const end = tokens.findIndex(
            (item, index) => index > i && (item === ";" || item === "+"),
          );
          segments.push(tokens.slice(i + 1, end === -1 ? undefined : end));
        }
      }
    }
    if (executable === "eval" && tokens[1]) {
      segments.push(...shellSegments(tokens.slice(1).join(" "), depth + 1));
    }
  }
  for (const substitution of parsed.substitutions) {
    segments.push(...shellSegments(substitution, depth + 1));
  }
  return segments;
}
