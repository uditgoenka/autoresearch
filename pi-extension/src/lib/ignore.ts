// Minimal gitignore-spec pattern matcher — ported from
// claude-plugin/hooks/lib/ignore.cjs. Zero deps. Supports directory
// patterns (dir/), globs (*.ext), negation (!pattern), double-star (**/)
// for arbitrary depth, and comments (#). Used by scout-block to enforce
// .ckignore + baseline ignore patterns.

interface Rule {
  pattern: string;
  negated: boolean;
  re: RegExp;
}

export class Ignore {
  private _rules: Rule[] = [];

  add(patterns: string | string[]): this {
    const lines = Array.isArray(patterns) ? patterns : patterns.split("\n");
    for (const raw of lines) {
      const line = raw.trim();
      if (!line || line.startsWith("#")) continue;
      const negated = line.startsWith("!");
      const pattern = negated ? line.slice(1) : line;
      this._rules.push({ pattern, negated, re: this._compile(pattern) });
    }
    return this;
  }

  ignores(inputPath: string): boolean {
    const p = inputPath.startsWith("/") ? inputPath.slice(1) : inputPath;
    let ignored = false;
    for (const rule of this._rules) {
      if (rule.re.test(p)) {
        ignored = !rule.negated;
      }
    }
    return ignored;
  }

  private _compile(pattern: string): RegExp {
    let p = pattern;
    if (p.endsWith("/")) p = p + "**";
    let re = "";
    let i = 0;
    while (i < p.length) {
      const c = p[i];
      if (c === "*") {
        if (p[i + 1] === "*") {
          if (p[i + 2] === "/") {
            re += "(?:.+/)?";
            i += 3;
            continue;
          }
          re += ".*";
          i += 2;
          continue;
        }
        re += "[^/]*";
        i++;
      } else if (c === "?") {
        re += "[^/]";
        i++;
      } else if (c === ".") {
        re += "\\.";
        i++;
      } else if (c === "/") {
        re += "/";
        i++;
      } else {
        re += c.replace(/[+^${}()|]/g, "\\$&");
        i++;
      }
    }
    // A trailing slash alone does not anchor (gitignore: `dir/` matches at any depth).
    const anchored = pattern.replace(/\/$/, "").includes("/") && !pattern.startsWith("**/");
    if (anchored) {
      return new RegExp("^" + re + "(?:$|/)");
    }
    return new RegExp("(?:^|/)" + re + "(?:$|/)");
  }
}

export function ignore(): Ignore {
  return new Ignore();
}
