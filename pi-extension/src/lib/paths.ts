// Path + sensitive-file helpers — ported from claude-plugin/hooks/scout-block.cjs
// and privacy-block.cjs. Used by the scout-block and privacy-block guardrails.

import { existsSync, readFileSync, statSync } from "node:fs";
import { basename, dirname, isAbsolute, join, relative, resolve } from "node:path";
import { Ignore } from "./ignore.js";
import { shellSegments } from "./shell.js";

export const BASELINE_PATTERNS = [
  "node_modules/",
  "__pycache__/",
  ".git/",
  "dist/",
  "build/",
  "out/",
  "coverage/",
  ".next/",
  ".nuxt/",
  "venv/",
  ".venv/",
  "env/",
  ".terraform/",
  ".aws/",
  ".ssh/",
  "*.log",
];

export function findProjectRoot(startDir: string): string {
  let dir = startDir;
  for (let i = 0; i < 20; i++) {
    if (existsSync(join(dir, ".git"))) return dir;
    const parent = dirname(dir);
    if (parent === dir) break;
    dir = parent;
  }
  return startDir;
}

export function loadCkIgnore(projectRoot: string): Ignore {
  const ig = new Ignore();
  ig.add(BASELINE_PATTERNS);
  try {
    const ckPath = join(projectRoot, ".ckignore");
    const content = readFileSync(ckPath, "utf8");
    ig.add(content);
  } catch {
    /* no .ckignore — baseline only */
  }
  return ig;
}

export function relativeToRoot(filePath: string, projectRoot: string, cwd: string): string {
  const abs = isAbsolute(filePath) ? filePath : resolve(cwd, filePath);
  const rel = relative(projectRoot, abs);
  // If the path escapes the project root, use the absolute path for matching.
  return (rel.startsWith("..") ? abs : rel).replace(/\\/g, "/");
}

export function checkIgnore(
  filePath: string,
  ig: Ignore,
  projectRoot: string,
  cwd: string,
): string | null {
  if (!filePath || typeof filePath !== "string") return null;
  const rel = relativeToRoot(filePath, projectRoot, cwd);
  return ig.ignores(rel) ? rel : null;
}

// --- Sensitive-file detection (privacy-block) ---

export const SENSITIVE_PATTERNS = [
  ".env",
  ".env.local",
  ".env.production",
  ".env.development",
  ".pem",
  ".key",
  ".p12",
  ".pfx",
  "id_rsa",
  "id_ed25519",
  ".ssh/",
  "credentials.json",
  "credentials.yaml",
  "secret",
  "api_key",
  "apikey",
  ".aws/credentials",
];

export const ALLOWED_EXCEPTIONS = [
  ".env.example",
  ".env.sample",
  ".env.template",
  ".env.test",
];

export function isSensitive(filePath: string): boolean {
  if (!filePath || typeof filePath !== "string") return false;
  const normalized = filePath.replace(/\\/g, "/").toLowerCase();
  const base = basename(filePath).toLowerCase();

  for (const exc of ALLOWED_EXCEPTIONS) {
    if (base === exc || normalized.endsWith("/" + exc)) return false;
  }

  for (const pattern of SENSITIVE_PATTERNS) {
    const lp = pattern.toLowerCase();
    if (
      base === lp ||
      normalized.endsWith("/" + lp) ||
      normalized.endsWith(lp) ||
      normalized.includes("/" + lp + "/") ||
      base.includes(lp)
    ) {
      return true;
    }
  }

  return false;
}

export function isRemoteOperand(token: string): boolean {
  if (/^[a-zA-Z]:[\\/]/.test(token)) return false;
  return /^[^/\s:]+(?:@[^/\s:]+)?:/.test(token);
}

// Extract path-like tokens from a bash command string for scout-block.
export function extractPathTokens(command: string): string[] {
  const tokens: string[] = [];
  for (const segmentTokens of shellSegments(command)) {
    const executable = basename(segmentTokens[0] || "");
    const remoteShell = executable === "ssh" || executable === "tsh";
    if (remoteShell) {
      const localPathOptions = new Set(["-i", "-F", "-E", "-S"]);
      const optionsWithValue = new Set([
        "-B",
        "-b",
        "-c",
        "-D",
        "-e",
        "-I",
        "-J",
        "-L",
        "-l",
        "-m",
        "-O",
        "-p",
        "-Q",
        "-R",
        "-W",
        "-w",
      ]);
      for (let i = 1; i < segmentTokens.length; i++) {
        const token = segmentTokens[i];
        if (localPathOptions.has(token) && segmentTokens[i + 1]) {
          tokens.push(segmentTokens[++i]);
        } else if (/^-[iFES].+/.test(token)) {
          tokens.push(token.slice(2));
        } else if (token === "-o" && segmentTokens[i + 1]) {
          const value = segmentTokens[++i];
          const match = value.match(
            /^(?:IdentityFile|UserKnownHostsFile|GlobalKnownHostsFile|CertificateFile)(?:=|\s+)(.+)$/i,
          );
          if (match) tokens.push(match[1]);
        } else if (/^-o(?:IdentityFile|UserKnownHostsFile|GlobalKnownHostsFile|CertificateFile)=/i.test(token)) {
          tokens.push(token.slice(token.indexOf("=") + 1));
        } else if (optionsWithValue.has(token)) {
          i += 1;
        } else if (!token.startsWith("-")) {
          break;
        }
      }
      continue;
    }
    if (["echo", "printf"].includes(executable)) continue;
    const candidates =
      executable === "grep" || executable === "sed" || executable === "awk"
        ? segmentTokens.slice(2)
        : segmentTokens;
    for (const token of candidates) {
      if (!isRemoteOperand(token)) tokens.push(token);
    }
  }
  return tokens.filter((t) => {
    if (!t || t.startsWith("-")) return false;
    return t.includes("/") || t.startsWith(".") || /\.[a-z]{1,6}$/.test(t);
  });
}

// Bash sensitivity classification for privacy-block.
export function bashSensitivity(command: string): "clear" | "ambiguous" | "none" {
  const clearOperations = new Set([
    "cat",
    "head",
    "tail",
    "less",
    "more",
    "grep",
    "cp",
    "mv",
    "scp",
    "rsync",
    "curl",
    "wget",
    "tee",
    "sed",
    "awk",
    "chmod",
    "chown",
    "rm",
    "truncate",
    "source",
    ".",
  ]);

  for (const tokens of shellSegments(command)) {
    const executable = basename(tokens[0] || "").toLowerCase();
    if (clearOperations.has(executable)) {
      const operands =
        executable === "grep" || executable === "sed" || executable === "awk"
          ? tokens.slice(2)
          : tokens.slice(1);
      for (const token of operands) {
        const operand = token.replace(
          /^(?:--upload-file|-T|--data-binary|--data|--data-raw|--output|-o)=?/,
          "",
        );
        if (operand && !operand.startsWith("-") && !isRemoteOperand(operand) && isSensitive(operand))
          return "clear";
      }
    }
    for (let i = 0; i < tokens.length - 1; i++) {
      if (/^&?[<>]+[&|]?$/.test(tokens[i]) && isSensitive(tokens[i + 1])) return "clear";
    }
  }

  const lower = command.toLowerCase();
  return SENSITIVE_PATTERNS.some((pattern) => lower.includes(pattern.toLowerCase()))
    ? "ambiguous"
    : "none";
}

export { statSync };
