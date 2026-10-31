// TSV helpers — ported from claude-plugin/hooks/lib/ar-hook-utils.cjs.
// readTsvTail returns the header + last N data rows of an iteration results
// TSV. findRecentTsv walks autoresearch/<sub>-<ts>/ for the most recently
// modified *.tsv within an age window.

import { readdirSync, readFileSync, statSync } from "node:fs";
import { join } from "node:path";

export interface TsvTail {
  header: string;
  rows: string[];
  total: number;
}

export function readTsvTail(filePath: string, n: number): TsvTail | null {
  try {
    const content = readFileSync(filePath, "utf8");
    const lines = content.split("\n").filter((l) => l.trim());
    const headerLines = lines.filter(
      (l) =>
        l.startsWith("#") ||
        l.startsWith("iteration\t") ||
        l.startsWith("iteration|"),
    );
    const dataLines = lines.filter(
      (l) =>
        !l.startsWith("#") &&
        l.trim() &&
        !l.startsWith("iteration\t") &&
        !l.startsWith("iteration|"),
    );
    const header = headerLines.length > 0 ? headerLines[headerLines.length - 1] : "";
    const tail = dataLines.slice(-n);
    return { header, rows: tail, total: dataLines.length };
  } catch {
    return null;
  }
}

export function findRecentTsv(cwd: string, maxAgeMinutes: number): string | null {
  const maxAge = maxAgeMinutes * 60 * 1000;
  const now = Date.now();
  const arDir = join(cwd, "autoresearch");
  let best: string | null = null;
  let bestMtime = 0;

  try {
    for (const dir of readdirSync(arDir)) {
      const subdir = join(arDir, dir);
      let stat;
      try {
        stat = statSync(subdir);
      } catch {
        continue;
      }
      if (!stat.isDirectory()) continue;
      try {
        for (const f of readdirSync(subdir)) {
          if (!f.endsWith(".tsv")) continue;
          const fp = join(subdir, f);
          const fstat = statSync(fp);
          const age = now - fstat.mtimeMs;
          if (age < maxAge && fstat.mtimeMs > bestMtime) {
            best = fp;
            bestMtime = fstat.mtimeMs;
          }
        }
      } catch {
        continue;
      }
    }
  } catch {
    /* no autoresearch dir */
  }

  return best;
}
