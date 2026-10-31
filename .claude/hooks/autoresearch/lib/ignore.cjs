'use strict';

// Minimal gitignore-spec pattern matcher (vendored, zero deps).
// Supports: directory patterns (dir/), globs (*.ext), negation (!pattern),
// double-star (**/) for arbitrary depth, and comments (#).

class Ignore {
  constructor() {
    this._rules = [];
  }

  add(patterns) {
    const lines = Array.isArray(patterns) ? patterns : patterns.split('\n');
    for (let raw of lines) {
      const line = raw.trim();
      if (!line || line.startsWith('#')) continue;
      const negated = line.startsWith('!');
      const pattern = negated ? line.slice(1) : line;
      // A malformed pattern (e.g. an inverted range) skips only that rule.
      try {
        this._rules.push({ pattern, negated, re: this._compile(pattern) });
      } catch {
        continue;
      }
    }
    return this;
  }

  ignores(path) {
    const p = path.startsWith('/') ? path.slice(1) : path;
    let ignored = false;
    for (const rule of this._rules) {
      if (rule.re.test(p)) {
        ignored = !rule.negated;
      }
    }
    return ignored;
  }

  _compile(pattern) {
    let p = pattern;
    if (p.endsWith('/')) p = p + '**';
    if (p.startsWith('/')) p = p.slice(1);
    let re = '';
    let i = 0;
    while (i < p.length) {
      const c = p[i];
      if (c === '*') {
        if (p[i + 1] === '*') {
          if (p[i + 2] === '/') {
            re += '(?:.+/)?';
            i += 3;
            continue;
          }
          re += '.*';
          i += 2;
          continue;
        }
        re += '[^/]*';
        i++;
      } else if (c === '?') {
        re += '[^/]';
        i++;
      } else if (c === '.') {
        re += '\\.';
        i++;
      } else if (c === '/') {
        re += '/';
        i++;
      } else if (c === '[') {
        // Copy a complete class (gitignore `[!x]` negates, JS uses `[^x]`); a lone `[` is literal.
        let start = i + 1;
        const neg = p[start] === '!' || p[start] === '^';
        if (neg) start++;
        const end = p.indexOf(']', start + 1);
        if (end === -1) {
          re += '\\[';
          i++;
        } else {
          re += '[' + (neg ? '^/' : '') + p.slice(start, end).replace(/[\\\[\]]/g, '\\$&') + ']';
          i = end + 1;
        }
      } else {
        re += c.replace(/[+^${}()|\\\]]/g, '\\$&');
        i++;
      }
    }
    // A trailing slash alone does not anchor (gitignore: `dir/` matches at any depth).
    const anchored = pattern.replace(/\/$/, '').includes('/') && !pattern.startsWith('**/');
    if (anchored) {
      return new RegExp('^' + re + '(?:$|/)');
    }
    return new RegExp('(?:^|/)' + re + '(?:$|/)');
  }
}

function ignore() {
  return new Ignore();
}

module.exports = ignore;
module.exports.default = ignore;
