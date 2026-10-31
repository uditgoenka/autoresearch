#!/usr/bin/env node
import {
  createReadStream,
  createWriteStream,
  readFileSync,
  renameSync,
  rmSync,
  statSync,
  writeFileSync,
} from 'node:fs';
import { createHash } from 'node:crypto';
import { homedir } from 'node:os';
import { basename, dirname, resolve } from 'node:path';
import { Transform } from 'node:stream';
import { pipeline } from 'node:stream/promises';

const PAGE_BYTES = 32 * 1024;
const CARRY_CHARS = 16 * 1024;
const EXCERPT_BYTES = 6_000;
const BODY_BYTES = 58_000;

function fail(message) {
  throw new Error(message);
}

function option(args, name) {
  const index = args.indexOf(name);
  if (index < 0 || !args[index + 1]) fail(`missing required ${name} value`);
  return args[index + 1];
}

function escapeRegExp(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function sensitiveValues() {
  return Object.entries(process['env'])
    .filter(([key, value]) => value && value.length >= 4 && /(token|secret|password|passwd|api.?key|credential|auth)/i.test(key))
    .map(([, value]) => value)
    .sort((left, right) => right.length - left.length);
}

function sanitizeText(input, repo = '') {
  let value = String(input).replaceAll('\u0000', '�');
  for (const secret of sensitiveValues()) value = value.replace(new RegExp(escapeRegExp(secret), 'g'), '[REDACTED]');
  value = value
    .replace(/(?:gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_[A-Za-z0-9_]{20,}|AKIA[0-9A-Z]{16}|sk_(?:live|test)_[A-Za-z0-9_-]{16,})/g, '[REDACTED]')
    .replace(/\b(Authorization\s*:\s*)(?:Bearer|Basic)\s+[^\s]+/gi, '$1[REDACTED]')
    .replace(/\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/gi, '[EMAIL-REDACTED]');
  if (repo) value = value.replace(new RegExp(escapeRegExp(resolve(repo)), 'g'), '[REPO]');
  const home = homedir();
  if (home) value = value.replace(new RegExp(escapeRegExp(home), 'g'), '[HOME]');
  return value
    .replace(/<!--\s*PRGATE:[\s\S]*?-->/gi, '[PRGATE-MARKER-REDACTED]')
    .replace(/<!--/g, '&lt;!--')
    .replace(/-->/g, '--&gt;')
    .replace(/[\u0001-\u0008\u000B\u000C\u000E-\u001F\u007F-\u009F\u202A-\u202E\u2066-\u2069]/g, '')
    .replace(/@(?=[A-Za-z0-9_-])/g, '@\u200b');
}

class Sanitizer extends Transform {
  constructor(repo) {
    super({ decodeStrings: false });
    this.repo = repo;
    this.carry = '';
    this.discardCredential = false;
  }

  _transform(chunk, _encoding, callback) {
    try {
      let value = chunk.toString('utf8');
      if (this.discardCredential) {
        const boundary = value.search(/\s/);
        if (boundary < 0) return callback();
        value = value.slice(boundary);
        this.discardCredential = false;
      }
      this.carry += value;
      if (this.carry.length > CARRY_CHARS * 2) {
        const end = this.carry.length - CARRY_CHARS;
        const emitted = this.carry.slice(0, end);
        const openCredential = /(?:\bAuthorization[ \t]*:[ \t]*(?:Bearer|Basic)[ \t]+|\b(?:gh[pousr]_|github_pat_|sk_(?:live|test)_|AKIA))[^\s]*$/i.exec(emitted);
        if (openCredential) {
          this.push(sanitizeText(emitted, this.repo));
          const remainder = this.carry.slice(end);
          const boundary = remainder.search(/\s/);
          this.carry = boundary < 0 ? '' : remainder.slice(boundary);
          this.discardCredential = boundary < 0;
          return callback();
        }
        this.push(sanitizeText(emitted, this.repo));
        this.carry = this.carry.slice(end);
      }
      callback();
    } catch (error) {
      callback(error);
    }
  }

  _flush(callback) {
    try {
      this.push(sanitizeText(this.carry, this.repo));
      callback();
    } catch (error) {
      callback(error);
    }
  }
}

async function sanitizeFile(input, output, repo) {
  const temporary = `${output}.tmp.${process.pid}`;
  try {
    await pipeline(
      input === '-' ? process.stdin : createReadStream(input, { highWaterMark: PAGE_BYTES }),
      new Sanitizer(repo),
      createWriteStream(temporary, { mode: 0o600 }),
    );
    renameSync(temporary, output);
  } catch (error) {
    rmSync(temporary, { force: true });
    fail(`could not safely sanitize ${input === '-' ? 'standard input' : basename(input)}: ${error.message}`);
  }
}

function inert(value, limit = 4_000) {
  let text = sanitizeText(value ?? '');
  if (Buffer.byteLength(text) > limit) {
    text = `${Buffer.from(text).subarray(0, limit).toString('utf8')} [content truncated]`;
  }
  return text
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('`', '&#96;')
    .replaceAll('#', '&#35;')
    .replaceAll('[', '&#91;')
    .replaceAll(']', '&#93;')
    .replaceAll('|', '&#124;')
    .replace(/\r?\n/g, '<br>');
}

function safeUrl(value) {
  try {
    const url = new URL(String(value));
    if (url.protocol !== 'https:') fail('only HTTPS evidence links are allowed');
    return url.href.replaceAll(')', '%29');
  } catch {
    fail('evidence contains an invalid or unsafe URL');
  }
}

async function fileDigest(file) {
  const hash = createHash('sha256');
  await pipeline(createReadStream(file), new Transform({
    transform(chunk, _encoding, callback) {
      hash.update(chunk);
      callback();
    },
  }));
  return hash.digest('hex');
}

function requireObject(value, name) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) fail(`evidence is missing ${name}`);
}

function requireText(value, name) {
  if (typeof value !== 'string' || !value.trim()) fail(`evidence is missing ${name}`);
}

function requireList(value, name) {
  if (!Array.isArray(value) || !value.length) fail(`evidence is missing ${name}`);
}

async function validateEvidence(value) {
  if (value.schema_version !== 1) fail('unsupported evidence schema version');
  for (const name of ['repository', 'base', 'head', 'diff', 'narrative', 'telemetry']) requireObject(value[name], name);
  requireList(value.phases, 'phase verdicts');
  requireList(value.commands, 'testing commands');
  for (const field of ['problem', 'scope', 'zero_debt', 'security', 'regression', 'compatibility', 'rollback']) {
    requireText(value.narrative[field], `narrative.${field}`);
  }
  for (const field of ['requirements', 'changes', 'decisions', 'risks', 'gaps']) requireList(value.narrative[field], `narrative.${field}`);
  for (const command of value.commands) {
    requireText(command.command, 'command.command');
    if (!Number.isInteger(command.exit_code) || !Number.isFinite(command.duration_ms)) fail('command result has invalid exit code or duration');
    requireObject(command.log, 'command.log');
    requireText(command.log.file, 'command.log.file');
    requireText(command.log.digest, 'command.log.digest');
    let actual;
    try { actual = await fileDigest(command.log.file); } catch { fail(`evidence log ${basename(command.log.file)} is missing`); }
    if (actual !== command.log.digest) fail(`evidence log ${basename(command.log.file)} digest changed or was substituted`);
  }
}

function bulletList(items) {
  return items.map((item) => `- ${inert(item)}`).join('\n');
}

function stackMap(stack, layer) {
  if (!stack) return '_Single pull request mode._';
  requireList(stack.layers, 'stack layers');
  return [
    '| Layer | Ref | Pull request |',
    '| ---: | --- | --- |',
    ...stack.layers.map((item) => {
      const current = item.position === layer.position ? ' **(this PR)**' : '';
      const link = item.pr_url ? `[open](${safeUrl(item.pr_url)})` : 'draft pending';
      return `| ${Number(item.position)} | ${inert(item.ref)}${current} | ${link} |`;
    }),
  ].join('\n');
}

function phaseTable(phases) {
  return [
    '| Phase | Gate | Verdict | Evidence |',
    '| ---: | --- | --- | --- |',
    ...phases.map((phase) => `| ${Number(phase.number)} | ${inert(phase.name)} | ${inert(phase.verdict)} | ${inert(phase.evidence)} |`),
  ].join('\n');
}

function testing(commands, excerptBytes) {
  const sections = [];
  for (const command of commands) {
    const excerpt = String(command.log.excerpt || '');
    const clipped = Buffer.byteLength(excerpt) > excerptBytes;
    const visible = clipped ? Buffer.from(excerpt).subarray(0, excerptBytes).toString('utf8') : excerpt;
    const counts = `${command.passed ?? 0} passed, ${command.failed ?? 0} failed, ${command.skipped ?? 0} skipped`;
    const artifact = command.log.artifact_url
      ? `\n\n[Complete redacted log](${safeUrl(command.log.artifact_url)}) — retained ${Number(command.log.retention_days || 30)} days.`
      : '';
    sections.push([
      `### <code>${inert(command.command)}</code>`,
      '',
      `Exit code: **${Number(command.exit_code)}** · ${inert(counts)} · ${Number(command.duration_ms)} ms`,
      '',
      '<details><summary>Bounded redacted excerpt</summary>',
      '',
      `<pre>${inert(visible, excerptBytes + 512)}</pre>`,
      '',
      clipped ? '_Excerpt truncated; use the complete redacted log link._' : '_Excerpt complete._',
      artifact,
      '</details>',
    ].join('\n'));
  }
  return sections.join('\n\n');
}

function telemetryTable(telemetry) {
  const rows = [
    ['Elapsed', `${Number(telemetry.elapsed_ms || 0)} ms`],
    ['Unique trees executed', telemetry.unique_trees],
    ['Command runs', telemetry.command_runs],
    ['Command runs avoided', telemetry.avoided_runs],
    ['Cache hits / misses', `${telemetry.cache_hits ?? 0} / ${telemetry.cache_misses ?? 0}`],
    ['Unique context slices', telemetry.unique_slices],
    ['Judgment context', `${telemetry.context_bytes ?? 0} bytes (token-cost proxy)`],
    ['Judgment dispatches', telemetry.judgment_dispatches],
    ['Actual tokens', telemetry.token_usage == null ? 'not exposed by runtime' : telemetry.token_usage],
  ];
  return ['| Metric | Value |', '| --- | ---: |', ...rows.map(([name, value]) => `| ${inert(name)} | ${inert(value)} |`)].join('\n');
}

function renderBody(value, excerptBytes = EXCERPT_BYTES) {
  const n = value.narrative;
  const body = [
    '<!-- PRGATE:BODY:START -->',
    '# PRGate evidence',
    '',
    '## Problem and motivation', '', inert(n.problem), '',
    '## Scope', '', inert(n.scope), '',
    '## Requirements', '', bulletList(n.requirements), '',
    '## Exact change summary', '', bulletList(n.changes), '',
    '## Architectural decisions', '', bulletList(n.decisions), '',
    '## Zero-tech-debt decisions', '', inert(n.zero_debt), '',
    '## Stack map', '', stackMap(value.stack, value.layer || { position: 1 }), '',
    '## Phase verdicts', '', phaseTable(value.phases), '',
    '## Testing', '', testing(value.commands, excerptBytes), '',
    '## Security analysis', '', inert(n.security), '',
    '## Regression analysis', '', inert(n.regression), '',
    '## Compatibility', '', inert(n.compatibility), '',
    '## Risks', '', bulletList(n.risks), '',
    '## Rollback', '', inert(n.rollback), '',
    '## Known gaps', '', bulletList(n.gaps), '',
    '## Optimization telemetry', '', telemetryTable(value.telemetry), '',
    '## Generation metadata', '',
    `Generated deterministically by PRGate evidence schema v${value.schema_version} at ${inert(value.generated_at)}.`,
    '',
    `Repository: ${inert(value.repository.name_with_owner)} · Base: <code>${inert(value.base.ref)}@${inert(value.base.commit)}</code> · Head: <code>${inert(value.head.ref)}@${inert(value.head.commit)}</code> · Diff: <code>${inert(value.diff.digest)}</code>`,
    '', '<!-- PRGATE:BODY:END -->', '',
  ].join('\n');
  return body;
}

function budgetBody(value) {
  const full = renderBody(value);
  if (Buffer.byteLength(full) <= BODY_BYTES) return full;
  let low = 0;
  let high = EXCERPT_BYTES;
  let best = null;
  while (low <= high) {
    const excerptBytes = Math.floor((low + high) / 2);
    const candidate = renderBody(value, excerptBytes);
    if (Buffer.byteLength(candidate) <= BODY_BYTES) {
      best = candidate;
      low = excerptBytes + 1;
    } else {
      high = excerptBytes - 1;
    }
  }
  if (!best) fail(`mandatory PR evidence exceeds the ${BODY_BYTES}-byte publication budget even without excerpts`);
  return best;
}

async function render(evidenceFile, output) {
  let value;
  try { value = JSON.parse(readFileSync(evidenceFile, 'utf8')); } catch { fail(`evidence ${basename(evidenceFile)} is invalid JSON`); }
  await validateEvidence(value);
  const body = budgetBody(value);
  const temporary = `${output}.tmp.${process.pid}`;
  writeFileSync(temporary, body, { mode: 0o600 });
  renameSync(temporary, output);
}

function usage() {
  return 'usage: render-evidence.mjs sanitize --input <raw> --output <safe> [--repo <root>] | render --evidence <json> --output <md>';
}

try {
  const [command, ...args] = process.argv.slice(2);
  if (command === 'sanitize') {
    const input = option(args, '--input');
    await sanitizeFile(input === '-' ? '-' : resolve(input), resolve(option(args, '--output')), args.includes('--repo') ? option(args, '--repo') : '');
  } else if (command === 'render') {
    await render(resolve(option(args, '--evidence')), resolve(option(args, '--output')));
  } else {
    fail(usage());
  }
} catch (error) {
  process.stderr.write(`render-evidence: ${error.message}\n`);
  process.exitCode = 1;
}
