#!/usr/bin/env node
// Self-contained React health scanner + scoring engine. Zero dependencies, no
// network. Scans React/JSX source for a curated rule catalog, emits findings
// with severity + file:line, and computes a 0-100 health score.
//
// Usage:
//   node react-health.mjs [dir]            full scan, human report
//   node react-health.mjs [dir] --json     structured findings + score (JSON)
//   node react-health.mjs [dir] --score    print only the numeric score (or "null")
//   node react-health.mjs [dir] --diff [--base <ref>]   scan only git-changed files vs base
//
// Scoring engine (transparent, deterministic, size-fair):
//   severity penalty points: error=30, warning=10, info=3
//   filePenalty(f) = min(100, sum of penalty points of findings in f)
//   score = round(clamp0..100( 100 - sum(filePenalty) / scannedFileCount ))
//   0 files scanned -> score = null  (UNAVAILABLE, not a pass, not 0)
//   monorepo: pass multiple roots -> overall score = the lowest (worst wins)
// Exit: 0 always (reporting tool); callers gate on the printed score/verdict.

import { readFileSync, statSync, lstatSync, readdirSync, existsSync } from 'node:fs';
import { join, extname, relative, resolve } from 'node:path';
import { execFileSync } from 'node:child_process';

const WEIGHT = { error: 30, warning: 10, info: 3 };
const SKIP_DIR = new Set(['node_modules', 'dist', 'build', '.next', 'out', 'coverage', '.git', 'storybook-static', 'vendor']);
const SKIP_FILE = /\.(test|spec|stories|d)\.[jt]sx?$|\.(example|sample)\b/i;
const SRC_EXT = new Set(['.jsx', '.tsx', '.js', '.ts']);

// Rule catalog: { id, category, severity, test(line, ctx) -> bool }.
// Line-based heuristics; the skill's FP-suppression guidance (re-read in context,
// honor // preprgate-disable) governs which findings survive into the report.
const RULES = [
  // --- correctness / bugs ---
  { id: 'array-index-as-key', category: 'bugs', severity: 'warning',
    test: l => /\bkey=\{\s*(i|idx|index|_i)\s*\}/.test(l) },
  { id: 'conditional-number-render', category: 'bugs', severity: 'warning',
    test: l => /\{\s*[\w.]+\.length\s*&&/.test(l) },
  { id: 'set-state-in-render', category: 'bugs', severity: 'error',
    // A useState setter is called bare (`setX(`); a class setState is `this.setX(`.
    // Both are real. Other member calls (`localStorage.setItem`, `el.setAttribute`,
    // `date.setHours`) are not — exclude the member position but keep `this.`.
    // Exclude the timer globals (`setTimeout`/`setInterval`/`setImmediate`) too.
    test: (l, c) => (/(^|[^.\w])set[A-Z]\w*\s*\(/.test(l) || /(^|[^\w])this\.set[A-Z]\w*\s*\(/.test(l))
      && !/\bset(Timeout|Interval|Immediate)\s*\(/.test(l)
      && c.inComponentBody && !c.inHandlerOrEffect },
  // --- security ---
  { id: 'dangerous-html-sink', category: 'security', severity: 'error',
    test: l => /dangerouslySetInnerHTML/.test(l) },
  { id: 'no-eval', category: 'security', severity: 'error',
    test: l => /\beval\s*\(|new\s+Function\s*\(/.test(l) },
  { id: 'script-url', category: 'security', severity: 'error',
    test: l => /(href|src)\s*=\s*\{?\s*['"`]\s*javascript:/i.test(l) },
  { id: 'target-blank-no-noopener', category: 'security', severity: 'warning',
    test: l => /target\s*=\s*['"]_blank['"]/.test(l) && !/rel\s*=\s*['"][^'"]*noopener/.test(l) },
  { id: 'auth-token-in-web-storage', category: 'security', severity: 'warning',
    test: l => /(local|session)Storage\.setItem\s*\([^)]*(token|jwt|secret|password|auth)/i.test(l) },
  { id: 'secret-in-client-code', category: 'security', severity: 'error',
    test: l => /(AKIA[0-9A-Z]{16})|(ghp_[A-Za-z0-9]{36})|(sk_(live|test)_[A-Za-z0-9]{24,})|(eyJ[A-Za-z0-9_-]+\.eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+)/.test(l) },
  // --- performance ---
  { id: 'new-object-as-prop', category: 'performance', severity: 'info',
    test: l => /\b[a-zA-Z_]\w*=\{\{/.test(l) && !/style=\{\{/.test(l) },
  { id: 'inline-style', category: 'performance', severity: 'info',
    test: l => /\bstyle=\{\{/.test(l) },
  { id: 'new-array-as-prop', category: 'performance', severity: 'info',
    test: l => /\b[a-zA-Z_]\w*=\{\[/.test(l) },
  { id: 'transition-all', category: 'performance', severity: 'info',
    test: l => /transition\s*:\s*all\b/.test(l) || /\btransition-all\b/.test(l) },
  // --- accessibility ---
  { id: 'img-missing-alt', category: 'accessibility', severity: 'warning',
    test: l => /<img\b/.test(l) && !/\balt\s*=/.test(l) },
  { id: 'click-without-key-handler', category: 'accessibility', severity: 'info',
    test: l => /<(div|span|li)\b[^>]*\bonClick=/.test(l) && !/onKey(Down|Press|Up)=/.test(l) },
  { id: 'autofocus', category: 'accessibility', severity: 'info',
    test: l => /\bautoFocus\b/.test(l) },
  { id: 'outline-none', category: 'accessibility', severity: 'info',
    test: l => /outline\s*:\s*none|\boutline-none\b/.test(l) },
];

function loadDisabled(root) {
  const cfg = join(root, '.preprgate', 'config.json');
  if (existsSync(cfg)) { try { return new Set(JSON.parse(readFileSync(cfg, 'utf8')).disabledRules || []); } catch { /* ignore */ } }
  return new Set();
}

function walk(dir, acc) {
  for (const name of readdirSync(dir)) {
    if (SKIP_DIR.has(name)) continue;
    const p = join(dir, name);
    // lstat, not stat: a symlinked dir pointing at an ancestor would otherwise
    // recurse forever. Symlinks are not followed for traversal.
    let st; try { st = lstatSync(p); } catch { continue; }
    if (st.isDirectory()) walk(p, acc);
    else if (SRC_EXT.has(extname(p)) && !SKIP_FILE.test(name)) acc.push(p);
  }
  return acc;
}

function git(root, argv) {
  // execFile with an argument array — no shell, so refs can't inject commands.
  return execFileSync('git', argv, { cwd: root, stdio: ['ignore', 'pipe', 'ignore'] }).toString();
}

function changedFiles(root, base) {
  if (!base) throw new Error('--diff requires --base <trusted-ref> or PREPRGATE_BASE; refusing a HEAD~1 guess');
  const b = base;
  let out = '';
  try { out = git(root, ['diff', '--name-only', `${b}..HEAD`]); } catch { return []; }
  return out.split('\n').filter(Boolean).map(f => resolve(root, f))
    .filter(f => existsSync(f) && SRC_EXT.has(extname(f)) && !SKIP_FILE.test(f));
}

// Cheap context: is this line inside a component body, and in a handler/effect?
function scanFile(path, disabled) {
  const findings = [];
  let text; try { text = readFileSync(path, 'utf8'); } catch { return findings; }
  // Only score files that actually contain JSX/React.
  if (!/</.test(text) && !/\breact\b/i.test(text) && extname(path).endsWith('sx') === false) {
    if (!/from\s+['"]react['"]/.test(text) && !/<[A-Za-z]/.test(text)) return findings;
  }
  const lines = text.split('\n');
  const ctx = { inComponentBody: false, inHandlerOrEffect: false };
  let depth = 0, handlerDepth = null;
  // Handler openers: hooks/event props, arrow blocks, and named-declaration
  // handlers. Named fns starting lowercase (handleClick, onSave) are handlers;
  // Capitalized fns are components, deliberately excluded so a setter in a
  // component body still trips set-state-in-render.
  const HANDLER_OPEN = /\b(useEffect|useLayoutEffect|useCallback|onClick|onChange|onSubmit|addEventListener)\b|=>\s*\{|\bfunction\s+[a-z]\w*\s*\(/;
  for (let i = 0; i < lines.length; i++) {
    const raw = lines[i];
    const line = raw;
    // suppression: previous line disables a rule (optionally named)
    const prev = i > 0 ? lines[i - 1] : '';
    const disableAll = /preprgate-disable-next-line\s*$/.test(prev);
    const disabledHere = m => disableAll || new RegExp(`preprgate-disable-next-line[^\\n]*\\b${m}\\b`).test(prev) || /\bpreprgate-disable-line\b/.test(line);
    // skip pure comment lines for detection (but not for suppression parsing)
    const isComment = /^\s*(\/\/|\*|\/\*)/.test(line);
    // crude scope tracking
    if (/\bfunction\s+[A-Z]\w*|\bconst\s+[A-Z]\w*\s*=\s*(\([^)]*\)|[\w]+)\s*=>|\bclass\s+[A-Z]\w*/.test(line)) ctx.inComponentBody = true;
    // Handler/effect context spans the whole block via brace-depth tracking, so
    // a setter on a line inside a handler body isn't mis-flagged as set-in-render.
    ctx.inHandlerOrEffect = handlerDepth !== null || HANDLER_OPEN.test(line);
    if (handlerDepth === null && HANDLER_OPEN.test(line)) handlerDepth = depth;
    // ponytail: brace count is text-only, doesn't skip strings/comments;
    // escalate to a real parser if this heuristic ever causes scope drift.
    depth += (line.match(/\{/g) || []).length - (line.match(/\}/g) || []).length;
    if (handlerDepth !== null && depth <= handlerDepth) handlerDepth = null;
    if (isComment) continue;
    for (const r of RULES) {
      if (disabled.has(r.id) || disabledHere(r.id)) continue;
      try { if (r.test(line, ctx)) findings.push({ rule: r.id, category: r.category, severity: r.severity, line: i + 1 }); } catch { /* rule error ignored */ }
    }
  }
  return findings;
}

function scoreOf(fileFindings, scannedCount) {
  if (scannedCount <= 0) return null; // UNAVAILABLE
  let total = 0;
  for (const findings of fileFindings.values()) {
    let fp = 0;
    for (const f of findings) fp += WEIGHT[f.severity] || 0;
    total += Math.min(100, fp);
  }
  const raw = 100 - total / scannedCount;
  const s = Number.isFinite(raw) ? Math.min(100, Math.max(0, raw)) : 50;
  return Math.round(s);
}

// --- main ---
const args = process.argv.slice(2);
const flag = n => args.includes(n);
const baseIdx = args.indexOf('--base');
const base = baseIdx >= 0 ? args[baseIdx + 1] : process['env'].PREPRGATE_BASE;
// The token after --base is a git ref, not the scan root — exclude only it.
const baseValIdx = baseIdx >= 0 ? baseIdx + 1 : -1;
const root = resolve(args.find((a, i) => !a.startsWith('-') && i !== baseValIdx) || '.');
const disabled = loadDisabled(root);

let files;
try { files = flag('--diff') ? changedFiles(root, base) : walk(root, []); }
catch (error) { console.error(`react-health: ${error.message}`); process.exit(2); }
const perFile = new Map();
const all = [];
for (const f of files) {
  const fnd = scanFile(f, disabled);
  perFile.set(f, fnd);
  for (const x of fnd) all.push({ ...x, file: relative(root, f) });
}
const scanned = files.length;
const score = scoreOf(perFile, scanned);

if (flag('--score')) { console.log(score === null ? 'null' : String(score)); process.exit(0); }

if (flag('--json')) {
  const counts = all.reduce((a, f) => (a[f.severity] = (a[f.severity] || 0) + 1, a), {});
  console.log(JSON.stringify({ score, scannedFiles: scanned, counts, findings: all.sort((a, b) => a.file.localeCompare(b.file) || a.line - b.line) }, null, 2));
  process.exit(0);
}

// human report
const order = { error: 0, warning: 1, info: 2 };
all.sort((a, b) => order[a.severity] - order[b.severity] || a.file.localeCompare(b.file) || a.line - b.line);
if (score === null) {
  console.log('React health: UNAVAILABLE — no React files scanned.');
} else if (all.length === 0) {
  console.log(`React health: clean — 0 findings (${score}/100).`);
} else {
  const files = new Set(all.map(f => f.file)).size;
  console.log(`React health: ${all.length} finding(s) firing across ${files} file(s) (score ${score}/100 — size-diluted; the gate is zero findings, not the number).`);
  console.log('Clear every finding below — fix real ones, suppress genuine false positives with // preprgate-disable-next-line <rule>.\n');
}
for (const f of all) console.log(`  [${f.severity}] ${f.file}:${f.line}  ${f.rule} (${f.category})`);
