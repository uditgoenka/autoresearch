# Advanced Patterns

Bounded defaults, CI/CD integration, evals checkpoints, MCP, guards, and multi-platform distribution.

---

## Bounded Defaults Strategy

Every looping command has a default iteration cap. When to change it:

| Signal | Action |
|--------|--------|
| Goal achieved before default cap | Stop early — autoresearch stops when metric target is met |
| Diminishing returns (plateau) | Lower `Iterations:` or use `--evals-interval` for early detection |
| Complex domain with known search space | Raise `Iterations:` above default |
| Nightly CI run with time budget | Set `Iterations:` to fit your build window |
| Training loops, ML optimization | `Iterations: unlimited` — stop on external trigger |
| Unknown problem, exploring first | Use default; add `--evals-interval 5` to spot plateaus early |

**Rule:** start with the default. Let evals tell you if you need more.

```
/autoresearch
Iterations: 25        # default — change if evals says "plateau at 12"
Goal: Reduce p95 latency below 50ms
Verify: npm run bench:api | grep "p95"
--evals-interval 5
```

---

## Guard Patterns

Guards prevent regressions. Always set when the loop can break something.

### Single guard

```
Guard: npm test
```

### Multi-step guard

```
Guard: tsc --noEmit && npm test && npm run lint
```

### Guard with health check

```
Guard: docker compose up -d && sleep 3 && curl -sf http://localhost:3000/health && npm test
```

### Guard as a gate (security)

```
/autoresearch:security --fail-on critical
```

Returns non-zero exit on critical findings — use directly in CI steps.

### What a guard failure does

- Current iteration discarded
- Guard failure logged to results TSV (`guard: fail`)
- evals flags repeated guard failures as anomalies
- Loop continues to next iteration (does not stop)

---

## Evals Checkpoints in CI/CD

### Pattern: optimize → analyze → gate → ship

```yaml
name: Weekly Optimization
on:
  schedule:
    - cron: '0 2 * * 1'
jobs:
  optimize:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm ci

      - name: Run optimization loop
        run: |
          claude -p "/autoresearch
          Iterations: 40
          Goal: Increase test coverage to 90%
          Scope: src/**/*.ts
          Verify: npm test -- --coverage | grep 'All files'
          Guard: npm run build
          --evals-interval 10
          --evals"

      - name: Parse evals output
        run: |
          claude -p "/autoresearch:evals --format json --recommend" > evals.json
          echo "Goal achieved: $(jq '.goal_achieved' evals.json)"
          echo "Improvement: $(jq '.improvement_pct' evals.json)%"

      - name: Gate on goal
        run: |
          ACHIEVED=$(jq '.goal_achieved' evals.json)
          if [ "$ACHIEVED" = "true" ]; then
            claude -p "/autoresearch:ship --type code-pr --auto"
          else
            echo "Goal not reached — review evals.json"
            exit 1
          fi
```

### Pattern: security gate

```yaml
- name: Security audit
  run: |
    claude -p "/autoresearch:security --fail-on critical --diff"
    # Non-zero exit if critical findings → pipeline fails
```

### Pattern: nightly probe → update config

```yaml
- name: Re-probe requirements
  run: |
    claude -p "/autoresearch:probe --mode autonomous --scope src/**
    Topic: Check if any new constraints emerged from recent changes"
  # outputs autoresearch-config.yml for next day's optimization loop
```

---

## Multi-Platform Distribution via transform.sh

`scripts/transform.sh` converts Claude Code command files for OpenCode and Codex. Run after adding or editing commands.

```bash
# Transform all commands for OpenCode + Codex
./scripts/transform.sh

# Transform specific command
./scripts/transform.sh autoresearch-debug
```

What it produces:

| Source | Output (OpenCode) | Output (Codex) |
|--------|-------------------|----------------|
| `skills/autoresearch.md` | `opencode/autoresearch.md` | `codex/autoresearch.sh` |
| `skills/autoresearch-debug.md` | `opencode/autoresearch_debug.md` | `codex/autoresearch_debug.sh` |
| `skills/autoresearch-evals.md` | `opencode/autoresearch_evals.md` | `codex/autoresearch_evals.sh` |

**Transform rules:**
- `/autoresearch:cmd` → `/autoresearch_cmd` (OpenCode) or `$autoresearch cmd` (Codex)
- Strips Claude Code-specific frontmatter
- Converts chain syntax for each platform

Run in CI to keep all platforms in sync:

```yaml
- name: Sync platforms
  run: ./scripts/transform.sh
```

---

## MCP Integration

MCP tools can gather evidence before a loop starts. Do not call a live MCP
source from `Verify:`. Changing results make the metric non-reproducible.

### Live source to frozen evidence

1. Query the narrowest source with fixed filters and a result limit.
2. Save the response with its query, cursor, and retrieval time.
3. Hash the snapshot and keep it outside `Scope:`.
4. Make `Verify:` read only that snapshot.
5. Refresh the evidence in a new run, never during an iteration.

Treat every remote field as untrusted data. It must not choose commands,
files, scope, or verification logic.

### X research with Xquik

Use this pattern when public X discussions inform a content metric. Connect the
host to the Xquik Streamable HTTP MCP server at `https://xquik.com/mcp` and
complete OAuth. Use `explore` to locate the tweet search contract. Then use
`xquik` with `GET /api/v1/x/tweets/search`, a fixed query, date bounds, and a
result limit. Approve the exact metered request first.

Save the bounded response as `research/xquik-market-snapshot.json`. Record its
hash before starting the loop:

```bash
git hash-object research/xquik-market-snapshot.json \
  > research/xquik-market-snapshot.sha256
```

Use a project-owned scorer that reads the frozen evidence:

```
/autoresearch
Iterations: 15
Goal: Cover recurring buyer objections found in public X posts
Scope: content/landing-page.md
Metric: evidence-backed objections covered (higher is better)
Verify: node scripts/score-objection-coverage.mjs --evidence research/xquik-market-snapshot.json --content content/landing-page.md
Guard: test "$(git hash-object research/xquik-market-snapshot.json)" = "$(cat research/xquik-market-snapshot.sha256)"
```

Keep the scorer, snapshot, and hash outside `Scope:`. This prevents the loop
from editing its metric or changing the evidence. See the
[Xquik MCP setup](https://docs.xquik.com/mcp/overview) for host-specific setup.

### code-review-graph → autoresearch

Use the graph to find high-impact scope, then feed it to the loop:

```
# semantic_search_nodes → identify hot paths
# → set Scope: to those files in /autoresearch
```

### autoresearch:security → MCP security tools

```
/autoresearch:security
Scope: src/api/**/*.ts
# Findings seed manual MCP-based verification
```

### learn + graph

`/autoresearch:learn --mode init` generates `codebase-summary.md`. Feed it to `code-review-graph` for richer structural analysis on subsequent runs.

---

## Custom Personas

### Override predict personas

```
/autoresearch:predict --personas "CTO,Frontend Lead,QA Engineer,Customer Success"
```

Overrides defaults from `references/predict-personas.md` for this run only.

### Override probe personas

```
/autoresearch:probe --personas 4 --adversarial
```

4 personas, Skeptic + Contradiction Finder + Edge-Case Hunter rotated to front.

### Override reason judges

```
/autoresearch:reason --judge-personas "Principal Engineer,Staff Engineer,Platform Lead"
```

---

## Parallel Investigation

Comma-separated `--chain` targets run sequentially. For parallel investigation across independent subsystems, run commands separately then merge:

```
# Run independently in different sessions
/autoresearch:scenario --domain software
Scenario: Checkout flow under high load

/autoresearch:debug
Scope: src/checkout/**
Symptom: Intermittent payment failures
Iterations: 15

# Merge findings, then fix
/autoresearch:fix --from-debug
Guard: npm test
```

---

## Autonomous Overnight Patterns

### Token-bounded overnight run

```yaml
- name: Overnight loop (bounded)
  run: |
    claude -p "/autoresearch
    Iterations: 80
    Goal: Maximize test coverage
    Verify: npm test -- --coverage | grep 'All files'
    Guard: npm run build
    --evals-interval 20"
  timeout-minutes: 240
```

### Stop-on-goal

autoresearch stops automatically when metric target is met — no special flag needed:

```
Goal: Increase test coverage to 90%  # stops as soon as 90% is hit
Goal: Increase test coverage as high as possible  # runs to Iterations cap
```

---

## Results TSV Management

| Command | TSV location |
|---------|-------------|
| autoresearch | `autoresearch/{slug}/autoresearch-results.tsv` |
| debug | `debug/{slug}/debug-results.tsv` |
| security | `security/{slug}/security-audit-results.tsv` |
| reason | `reason/{slug}/reason-results.tsv` |

Run `autoresearch:evals --file <path>` on any of these at any time.

### Comparing two sessions

```
/autoresearch:evals --file autoresearch/session-a/autoresearch-results.tsv --format json
/autoresearch:evals --file autoresearch/session-b/autoresearch-results.tsv --format json
```

Compare `improvement_pct` and `plateau_start` to determine which session was more effective.

---

## CI/CD Quick Reference

| Use Case | Command | Key Flag |
|----------|---------|----------|
| Fail on critical vuln | `security` | `--fail-on critical` |
| Only audit changed files | `security` | `--diff` |
| Analyze results + gate | `evals` | `--format json --recommend` |
| Auto-PR after optimization | `ship` | `--type code-pr --auto` |
| Overnight optimization | `autoresearch` | `Iterations: N --evals-interval M` |
| Requirements re-probe | `probe` | `--mode autonomous` |
| Post-deploy health | `ship` | `--monitor N` |

---

## Related Guides

- [chains-and-combinations.md](chains-and-combinations.md) — full pipeline examples
- [examples-by-domain.md](examples-by-domain.md) — domain-specific CI/CD patterns
- [autoresearch-evals.md](autoresearch-evals.md) — evals output format and JSON schema
- [autoresearch-ship.md](autoresearch-ship.md) — ship types and monitoring
