# Autoresearch Examples

Real-world examples organized by domain, with practical configurations you can copy-paste.

[Software Engineering](#software-engineering) · [Sales](#sales) · [Marketing](#marketing) · [HR & People Ops](#hr--people-ops) · [Operations](#operations) · [Performance Marketing](#performance-marketing) · [Data Science](#data-science) · [DevOps](#devops) · [Design & Accessibility](#design--accessibility) · [Debug Examples](#debug-examples) · [Fix Examples](#fix-examples) · [Scenario Examples](#scenario-examples) · [MCP Servers](#combining-with-mcp-servers) · [API Patterns](#combining-with-apis) · [Claude Code Patterns](#claude-code-patterns) · [Plan Wizard Examples](#plan-wizard-examples) · [Security Audit Examples](#security-audit-examples) · [Ship Workflow Examples](#ship-workflow-examples) · [Verification Scripts](#writing-verification-scripts) · [Core Principles](#core-principles)

---

## Software Engineering

### Increase test coverage

```
/autoresearch
Goal: Increase test coverage from 72% to 90%
Scope: src/**/*.test.ts, src/**/*.ts
Metric: coverage % (higher is better)
Verify: npm test -- --coverage | grep "All files"
```

Bounded variant — run 20 iterations then stop:

```
/autoresearch
Iterations: 20
Goal: Increase test coverage from 72% to 90%
Scope: src/**/*.test.ts, src/**/*.ts
Metric: coverage % (higher is better)
Verify: npm test -- --coverage | grep "All files"
```

Claude adds tests one-by-one. Each iteration: write test → run coverage → keep if % increased → discard if not → repeat.

### Reduce bundle size

```
/autoresearch
Iterations: 15
Goal: Reduce production bundle size
Scope: src/**/*.tsx, src/**/*.ts
Metric: bundle size in KB (lower is better)
Verify: npm run build 2>&1 | grep "First Load JS"
```

Claude tries: tree-shaking unused imports, lazy-loading routes, replacing heavy libraries, code-splitting — one change at a time. 15 iterations is usually enough to find the big wins.

### Fix flaky tests

```
/autoresearch
Iterations: 10
Goal: Zero flaky tests (all tests pass 5 consecutive runs)
Scope: src/**/*.test.ts
Metric: failure count across 5 runs (lower is better)
Verify: for i in {1..5}; do npm test 2>&1; done | grep -c "FAIL"
```

### Performance optimization

```
/autoresearch
Goal: API response time under 100ms (p95)
Scope: src/api/**/*.ts, src/services/**/*.ts
Metric: p95 response time in ms (lower is better)
Verify: npm run bench:api | grep "p95"
```

Quick 30-minute sprint:

```
/autoresearch
Iterations: 10
Goal: API response time under 100ms (p95)
Scope: src/api/**/*.ts, src/services/**/*.ts
Metric: p95 response time in ms (lower is better)
Verify: npm run bench:api | grep "p95"
```

### Eliminate TypeScript `any` types

```
/autoresearch
Iterations: 25
Goal: Eliminate all TypeScript `any` types
Scope: src/**/*.ts
Metric: count of `any` occurrences (lower is better)
Verify: grep -r ":\s*any" src/ --include="*.ts" | wc -l
```

### Reduce lines of code

```
/autoresearch
Iterations: 20
Goal: Reduce lines of code in src/services/ by 30% while keeping all tests green
Metric: LOC count (lower is better)
Verify: npm test && find src/services -name "*.ts" | xargs wc -l | tail -1
```

---

## Sales

### Cold email optimization

```
/autoresearch
Iterations: 15
Goal: Improve cold email reply rate prediction score
Scope: content/email-templates/*.md
Metric: readability score + personalization token count (higher is better)
Verify: node scripts/score-email-template.js
```

Claude iterates on subject lines, opening hooks, CTAs, personalization variables — keeping changes that score higher. 15 iterations for a focused session.

### Sales deck refinement

```
/autoresearch
Iterations: 10
Goal: Reduce slide count while maintaining all key points
Scope: content/sales-deck/*.md
Metric: slide count (lower is better), constraint: key-points-checklist.md must all be present
Verify: node scripts/check-deck-coverage.js && wc -l content/sales-deck/*.md
```

### Objection handling docs

```
/autoresearch
Iterations: 20
Goal: Cover all 20 common objections with responses under 50 words each
Scope: content/objection-responses.md
Metric: objections covered + avg word count per response (more covered + fewer words = better)
Verify: node scripts/score-objections.js
```

---

## Marketing

### SEO content optimization

```
/autoresearch
Goal: Maximize SEO score for target keywords
Scope: content/blog/*.md
Metric: SEO score from audit tool (higher is better)
Verify: node scripts/seo-score.js --file content/blog/target-post.md
```

Claude tweaks headings, keyword density, meta descriptions, internal links — one change per iteration. Run unlimited overnight, or bounded:

```
/autoresearch
Iterations: 25
Goal: Maximize SEO score for target keywords
```

### Landing page copy

```
/autoresearch
Iterations: 15
Goal: Maximize Flesch readability + keyword density for "AI automation"
Scope: content/landing-pages/ai-automation.md
Metric: readability_score * 0.7 + keyword_density_score * 0.3 (higher is better)
Verify: node scripts/content-score.js content/landing-pages/ai-automation.md
```

### Email sequence optimization

```
/autoresearch
Iterations: 20
Goal: Optimize 7-day nurture sequence for clarity and CTA strength
Scope: content/email-sequences/onboarding/*.md
Metric: avg readability + CTA score per email (higher is better)
Verify: node scripts/score-email-sequence.js onboarding
```

### Ad copy variants

```
/autoresearch
Iterations: 25
Goal: Generate and refine 20 ad copy variants, each under 90 chars with power words
Scope: content/ads/facebook-q1.md
Metric: variants meeting criteria (higher is better)
Verify: node scripts/validate-ad-copy.js
```

---

## HR & People Ops

### Job description optimization

```
/autoresearch
Iterations: 15
Goal: Improve job descriptions — bias-free language, clear requirements, inclusive tone
Scope: content/job-descriptions/*.md
Metric: inclusivity score from textio-style checker (higher is better)
Verify: node scripts/jd-inclusivity-score.js
```

### Policy document clarity

```
/autoresearch
Iterations: 10
Goal: Reduce average reading level of HR policies to grade 8
Scope: content/policies/*.md
Metric: Flesch-Kincaid grade level (lower is better)
Verify: node scripts/readability.js content/policies/
```

### Interview question bank

```
/autoresearch
Iterations: 20
Goal: Ensure all questions are behavioral (STAR format) + cover all competencies
Scope: content/interview-questions.md
Metric: STAR-format compliance % + competency coverage % (higher is better)
Verify: node scripts/interview-quality.js
```

---

## Operations

### Runbook optimization

```
/autoresearch
Iterations: 15
Goal: Reduce average runbook steps while maintaining completeness
Scope: docs/runbooks/*.md
Metric: avg steps per runbook (lower is better), constraint: all checklist items preserved
Verify: node scripts/runbook-audit.js
```

### Process documentation

```
/autoresearch
Iterations: 10
Goal: Standardize all SOPs to template format with <100 words per step
Scope: docs/sops/*.md
Metric: template compliance % + avg words per step (higher compliance + lower words = better)
Verify: node scripts/sop-score.js
```

### Incident response playbooks

```
/autoresearch
Iterations: 20
Goal: Ensure all playbooks have decision trees, escalation paths, rollback steps
Scope: docs/incident-playbooks/*.md
Metric: completeness checklist score (higher is better)
Verify: node scripts/playbook-completeness.js
```

---

## Performance Marketing

### Google Ads copy optimization

```
/autoresearch
Iterations: 30
Goal: Generate 50 ad headline variants (max 30 chars) with power words + CTA
Scope: content/ads/google-search/*.md
Metric: headlines meeting char limit + power word + CTA criteria (higher is better)
Verify: node scripts/google-ads-validator.js --type headlines
```

Claude generates headline variants, scores each for character limits, emotional triggers, and CTA presence — discarding any that don't meet criteria. 30 iterations to build up 50 variants.

### Landing page CRO

```
/autoresearch
Iterations: 15
Goal: Maximize landing page quality score — clear CTA, social proof, urgency, mobile-friendly
Scope: content/landing-pages/product-launch.md
Metric: CRO checklist score (higher is better)
Verify: node scripts/cro-score.js content/landing-pages/product-launch.md
```

### Meta/Facebook ad copy

```
/autoresearch
Iterations: 25
Goal: Create 30 primary text variants (max 125 chars) optimized for engagement
Scope: content/ads/meta/*.md
Metric: variants meeting criteria + avg engagement score (higher is better)
Verify: node scripts/meta-ad-validator.js
```

### A/B test hypothesis generation

```
/autoresearch
Iterations: 20
Goal: Generate 20 testable hypotheses for checkout page, each with metric + expected lift
Scope: content/experiments/checkout-hypotheses.md
Metric: valid hypotheses with metric + lift prediction (higher is better)
Verify: node scripts/hypothesis-validator.js
```

### UTM campaign taxonomy

```
/autoresearch
Iterations: 10
Goal: Standardize all campaign URLs with consistent UTM parameters
Scope: content/campaigns/utm-tracker.csv
Metric: UTM compliance % (higher is better)
Verify: node scripts/utm-validator.js
```

### Email subject line testing

```
/autoresearch
Iterations: 30
Goal: Generate 40 subject lines for product launch — max 50 chars, personalization token, urgency
Scope: content/emails/subject-lines.md
Metric: lines meeting all criteria (higher is better)
Verify: node scripts/subject-line-scorer.js
```

---

## Data Science

### Data pipeline quality

```
/autoresearch
Iterations: 20
Goal: Increase data validation pass rate from 85% to 99%
Scope: scripts/validators/*.py
Metric: validation pass rate % (higher is better)
Verify: python scripts/run_validations.py | grep "pass_rate"
```

### SQL query optimization

```
/autoresearch
Iterations: 15
Goal: Reduce total query execution time for dashboard queries
Scope: queries/dashboard/*.sql
Metric: total execution time in ms (lower is better)
Verify: psql -f scripts/bench-queries.sql | grep "total_ms"
```

### Report template automation

```
/autoresearch
Iterations: 10
Goal: Standardize all weekly reports — consistent sections, KPI coverage, action items
Scope: templates/reports/*.md
Metric: template compliance score (higher is better)
Verify: node scripts/report-template-audit.js
```

### Python ML training

```
/autoresearch
Goal: Reduce validation loss (val_bpb)
Scope: train.py, model.py
Metric: val_bpb (lower is better)
Verify: uv run train.py --epochs 1 2>&1 | grep "val_bpb" | tail -1 | awk '{print $NF}'
```

---

## DevOps

### Dockerfile optimization

```
/autoresearch
Iterations: 10
Goal: Reduce Docker image size and build time
Scope: Dockerfile, .dockerignore
Metric: image size in MB (lower is better)
Verify: docker build -t bench . 2>&1 && docker images bench --format "{{.Size}}"
```

### CI/CD pipeline speed

```
/autoresearch
Iterations: 15
Goal: Reduce CI pipeline duration from 12min to under 5min
Scope: .github/workflows/*.yml
Metric: pipeline duration in seconds (lower is better)
Verify: node scripts/estimate-ci-time.js
```

### Terraform/IaC compliance

```
/autoresearch
Iterations: 20
Goal: Pass all tfsec security checks + reduce resource count
Scope: infra/*.tf
Metric: tfsec violations (lower is better)
Verify: tfsec . --format json | jq '.results | length'
```

---

## Design & Accessibility

### Accessibility audit

```
/autoresearch
Iterations: 25
Goal: Reach WCAG 2.1 AA compliance — zero axe violations
Scope: src/components/**/*.tsx
Metric: axe violation count (lower is better)
Verify: npx playwright test a11y.spec.ts | grep "violations"
```

### Design token consistency

```
/autoresearch
Iterations: 20
Goal: Replace all hardcoded colors/spacing with design tokens
Scope: src/**/*.tsx, src/**/*.css
Metric: hardcoded values count (lower is better)
Verify: grep -rE "#[0-9a-fA-F]{3,6}|px\b" src/ --include="*.tsx" --include="*.css" | wc -l
```

---

## Debug Examples

### Hunt all bugs in a codebase

```
/autoresearch:debug
Scope: src/**/*.ts
```

Claude scans the codebase, runs tests/lint/typecheck, and iteratively investigates every failure using the scientific method — one hypothesis per iteration.

### Debug a specific error

```
/autoresearch:debug
Symptom: API returns 500 on POST /users
Scope: src/api/**/*.ts
```

### Bounded bug hunt

```
/autoresearch:debug
Iterations: 20
Scope: src/auth/**/*.ts
```

20 investigation iterations focused on auth code.

### Debug then auto-fix

```
/autoresearch:debug --fix
```

Hunts bugs first, then automatically switches to `/autoresearch:fix` to repair everything found.

### Debug by domain

```
# API debugging — checks routes, middleware, serialization
/autoresearch:debug
Scope: src/api/**/*.ts
Symptom: 404 on valid routes

# Database debugging — checks queries, transactions, N+1
/autoresearch:debug
Scope: src/models/**/*.ts
Symptom: Slow queries on dashboard page

# Auth debugging — checks JWT, permissions, escalation
/autoresearch:debug
Scope: src/auth/**/*.ts, src/middleware/**/*.ts
Symptom: Regular users can access admin endpoints
```

### Example debug session output

```
> /autoresearch:debug
> Iterations: 10

[Phase 1] Gathering symptoms...
  Tests: 3 failures, Lint: 0 errors, Types: 2 errors

[Iteration 1] Hypothesis: "db.insert() missing await at db.ts:88"
  → CONFIRMED HIGH — silent write failure on error path

[Iteration 2] Hypothesis: "JWT alg not validated at auth.ts:42"
  → CONFIRMED CRITICAL — algorithm confusion vulnerability

[Iteration 3] Hypothesis: "Rate limiting missing on /api/auth/login"
  → CONFIRMED MEDIUM — brute force possible

[Iteration 4] Hypothesis: "SQL injection via string concat in search"
  → DISPROVEN — parameterized queries used correctly

=== Debug Complete (10/10 iterations) ===
Bugs found: 3 (1 Critical, 1 High, 1 Medium)
Hypotheses: 10 tested (3 confirmed, 6 disproven, 1 inconclusive)
Files investigated: 14 / 47 in scope
```

---

## Fix Examples

### Fix all errors automatically

```
/autoresearch:fix
```

Auto-detects what's broken (tests, types, lint, build), prioritizes by severity, and fixes ONE thing per iteration until zero errors.

### Fix with guard

```
/autoresearch:fix
Target: tsc --noEmit
Guard: npm test
```

Fixes type errors while ensuring tests keep passing.

### Fix only tests

```
/autoresearch:fix --category test
```

### Fix only TypeScript errors

```
/autoresearch:fix --category type --guard "npm test"
```

### Fix from debug findings

```
# Step 1: Hunt bugs
/autoresearch:debug
Iterations: 15

# Step 2: Fix what was found
/autoresearch:fix --from-debug
Iterations: 30
```

### Bounded fix sprint

```
/autoresearch:fix
Iterations: 20
```

Fix as many errors as possible in 20 iterations.

### Example fix session output

```
> /autoresearch:fix

[Phase 1] Detected: 47 test failures, 12 type errors, 3 lint errors
[Phase 2] Priority: types first (may cascade-fix test failures)

[Iteration 1] Fix: auth.ts:42 — add return type annotation
  delta: -2 errors | guard: pass | STATUS: KEEP

[Iteration 2] Fix: db.ts:15 — handle nullable column
  delta: -1 error | guard: pass | STATUS: KEEP

[Iteration 3] Fix: api.test.ts — fix expected status 200→201
  delta: -3 errors | guard: pass | STATUS: KEEP

[Iteration 4] Fix: auth.test.ts — wrong approach
  delta: 0 errors | guard: - | STATUS: DISCARD (reverted)

...

=== Fix Complete (23 iterations) ===
Baseline: 62 errors → Final: 3 errors (-95.2%)
Keeps: 19 | Discards: 3 | Reworks: 1
Blocked: 1 (circular dependency — escalated to /autoresearch:debug)
```

### Fix CI/CD failures

```
/autoresearch:fix
Target: gh run view --log-failed
Scope: .github/workflows/*.yml
```

### Fix after dependency upgrade

```
/autoresearch:fix
Target: npm test
Guard: tsc --noEmit
Scope: src/**/*.ts
```

---

## Combining with MCP Servers

Claude Code supports [MCP (Model Context Protocol)](https://modelcontextprotocol.io/) servers. When combined with autoresearch, this unlocks **real-time data-driven iteration loops**.

### Database-driven iteration

Use a PostgreSQL MCP server to iterate on query performance:

```
/autoresearch
Goal: Optimize slow dashboard queries — reduce p95 query time
Scope: queries/dashboard/*.sql
Metric: avg query time in ms (lower is better)
Verify: Use MCP postgres tool to run EXPLAIN ANALYZE on each query, sum total costs
```

### API integration testing

```
/autoresearch
Goal: All API endpoints return valid JSON with correct status codes in <200ms
Scope: src/api/**/*.ts
Metric: endpoints passing all checks (higher is better)
Verify: Use MCP HTTP tool to hit each endpoint, validate response schema + timing
```

### Analytics-driven content

Use a Google Analytics or Plausible MCP server:

```
/autoresearch
Goal: Improve blog post structure based on engagement metrics
Scope: content/blog/*.md
Metric: avg time on page for modified posts (higher is better)
Verify: Use MCP analytics tool to fetch page metrics, compare against baseline
```

### CRM + sales automation

Use a HubSpot/Salesforce MCP server:

```
/autoresearch
Goal: Optimize email templates based on actual open/reply rates
Scope: content/email-templates/*.md
Metric: avg open rate from CRM data (higher is better)
Verify: Use MCP CRM tool to pull latest campaign metrics for template variants
```

### Cloud infrastructure monitoring

Use an AWS/GCP MCP server:

```
/autoresearch
Goal: Reduce Lambda cold start times across all functions
Scope: src/lambdas/**/*.ts
Metric: avg cold start time in ms (lower is better)
Verify: Use MCP CloudWatch tool to query p95 cold start durations
```

### GitHub issue triage

```
/autoresearch
Goal: Auto-label and categorize 100+ open issues by type and priority
Scope: scripts/issue-triage.js
Metric: issues correctly labeled (higher is better)
Verify: Use MCP GitHub tool to fetch issues, compare labels against rules
```

### Recommended MCP Servers

| MCP Server | Use Case | Metric Source |
|---|---|---|
| **PostgreSQL** | Query optimization, data validation | Query execution time, row counts |
| **GitHub** | Issue triage, PR quality, CI status | Issue counts, check pass rates |
| **Filesystem** | File organization, cleanup | File counts, directory depth |
| **Puppeteer/Playwright** | Visual regression, performance | Lighthouse scores, screenshot diffs |
| **Slack** | Notification quality, alert tuning | Message delivery, response times |
| **Stripe** | Payment flow optimization | Checkout completion rates |
| **Sentry** | Error reduction | Error count, crash-free rate |
| **Cloudflare** | Edge performance | Cache hit rate, TTFB |

---

## Combining with APIs

Beyond MCP, Claude can call APIs directly via scripts in the verification step.

### Lighthouse via API

```javascript
// scripts/lighthouse-score.js
const { exec } = require('child_process');
exec('npx lighthouse http://localhost:3000 --output json --quiet', (err, stdout) => {
  const report = JSON.parse(stdout);
  const perf = report.categories.performance.score * 100;
  console.log(`SCORE: ${perf}`);
  process.exit(perf > 0 ? 0 : 1);
});
```

```
/autoresearch
Goal: Lighthouse performance score above 95
Scope: src/components/**/*.tsx, src/app/**/*.tsx
Metric: Lighthouse performance score (higher is better)
Verify: node scripts/lighthouse-score.js
```

### LLM API for content scoring

Use a fast, cheap model (like Haiku) for scoring:

```javascript
// scripts/content-quality-scorer.js
const Anthropic = require('@anthropic-ai/sdk');
const fs = require('fs');

const content = fs.readFileSync(process.argv[2], 'utf-8');
const client = new Anthropic();

async function score() {
  const msg = await client.messages.create({
    model: 'claude-haiku-4-5-20251001',
    max_tokens: 100,
    messages: [{ role: 'user', content: `Score this content 0-100 for clarity, engagement, and SEO. Return ONLY a number.\n\n${content}` }]
  });
  const score = parseInt(msg.content[0].text.trim());
  console.log(`SCORE: ${score}`);
  process.exit(0);
}
score();
```

```
/autoresearch
Goal: All blog posts score 80+ on AI-assessed quality
Scope: content/blog/*.md
Metric: quality score from Haiku (higher is better)
Verify: node scripts/content-quality-scorer.js content/blog/latest.md
```

### PageSpeed Insights API

```javascript
// scripts/pagespeed-score.js
const https = require('https');
const url = `https://www.googleapis.com/pagespeedonline/v5/runPagespeed?url=${process.argv[2]}&key=${process.env.PSI_API_KEY}`;
https.get(url, res => {
  let data = '';
  res.on('data', chunk => data += chunk);
  res.on('end', () => {
    const score = JSON.parse(data).lighthouseResult.categories.performance.score * 100;
    console.log(`SCORE: ${score}`);
  });
});
```

### Stripe checkout flow

```
/autoresearch
Goal: Reduce checkout page load time and increase Stripe test payment success rate
Scope: src/checkout/**/*.tsx
Metric: checkout flow success rate % (higher is better)
Verify: node scripts/test-checkout-flow.js
```

### Email deliverability

```
/autoresearch
Goal: Improve email deliverability — reduce spam score across all templates
Scope: content/email-templates/*.html
Metric: SpamAssassin score (lower is better)
Verify: node scripts/spam-score.js content/email-templates/
```

---

## Claude Code Patterns

### Pattern 1: "Run Overnight"

```
/autoresearch
Goal: Improve lighthouse score from 72 to 95+
I'm going to sleep — iterate all night. Don't ask me anything.
```

### Pattern 2: "Controlled Sprint"

```
/autoresearch
Iterations: 15
Goal: Increase test coverage from 72% to 85%
Focus on the modules with lowest coverage first.
```

### Pattern 3: "Compound Improvements"

Stack small wins. Each kept commit builds on the last.

```
/autoresearch
Goal: Reduce TypeScript errors from 47 to 0
Start with the easiest fixes. Build momentum. Save hardest for last.
```

### Pattern 4: "Explore and Exploit"

Let Claude try bold experiments, auto-reverting failures.

```
/autoresearch
Goal: Reduce API response time
Try radical approaches too — different data structures, caching strategies, query rewrites.
If stuck after 5 discards, try something completely different.
```

### Pattern 5: "Refactor Without Breaking"

Safe refactoring with automatic rollback safety net.

```
/autoresearch
Goal: Reduce lines of code in src/services/ by 30% while keeping all tests green
Metric: LOC count (lower is better)
Verify: npm test && find src/services -name "*.ts" | xargs wc -l | tail -1
```

### Pattern 6: "Content Factory"

Batch-produce content that meets quality gates.

```
/autoresearch
Goal: Write 20 blog post outlines, each with 5+ sections, 3+ internal link opportunities
Scope: content/outlines/*.md
Metric: outlines meeting criteria (higher is better)
Verify: node scripts/outline-validator.js
```

### Pattern 7: "Progressive Hardening"

Start lenient, tighten criteria as baseline improves.

```
/autoresearch
Goal: Phase 1 — all tests pass. Phase 2 — coverage >80%. Phase 3 — zero linting errors.
Advance to next phase only when current is stable for 3 consecutive iterations.
```

---

## Plan Wizard Examples

### Bundle size reduction

```
> /autoresearch:plan Reduce bundle size

[Scope]    Which files? → src/**/*.tsx, src/**/*.ts (127 files)
[Metric]   Bundle size in KB (lower is better)
[Verify]   npm run build 2>&1 | grep "First Load JS" | awk '{print $4}'
[Dry run]  ✓ Exit 0 — Baseline: 287KB

Ready-to-use:

  /autoresearch
  Goal: Reduce bundle size below 200KB
  Scope: src/**/*.tsx, src/**/*.ts
  Metric: bundle size in KB (lower is better)
  Verify: npm run build 2>&1 | grep "First Load JS" | awk '{print $4}'

Launch now? → [Unlimited] [Bounded] [Copy only]
```

### Test coverage (Node.js)

```
> /autoresearch:plan Increase test coverage to 95%

[Context]  Detected: Jest, TypeScript, 84 source files
[Scope]    src/**/*.ts, src/**/*.test.ts (84 + 31 files)
[Metric]   Coverage % from Jest (higher is better)
[Verify]   npx jest --coverage --silent 2>&1 | grep "All files" | awk '{print $4}'
[Dry run]  ✓ Exit 0 — Baseline: 72.3%
```

### Lighthouse performance (Next.js)

```
> /autoresearch:plan Improve page load speed

[Context]  Detected: Next.js, React, Tailwind, 23 components
[Scope]    src/app/**/*.tsx, src/components/**/*.tsx (41 files)
[Metric]   Lighthouse performance score 0-100 (higher is better)
[Verify]   npx lighthouse http://localhost:3000 --output json --quiet | jq '.categories.performance.score * 100'
[Dry run]  ✓ Exit 0 — Baseline: 68
```

### TypeScript strictness

```
> /autoresearch:plan Eliminate all any types

[Context]  Detected: TypeScript 5.x, 147 source files
[Scope]    src/**/*.ts, src/**/*.tsx (147 files)
[Metric]   Count of `any` type annotations (lower is better)
[Verify]   grep -r ":\s*any" src/ --include="*.ts" --include="*.tsx" | wc -l | tr -d ' '
[Dry run]  ✓ Exit 0 — Baseline: 34
```

### Content SEO scoring

```
> /autoresearch:plan Improve blog SEO scores

[Context]  Detected: Markdown blog posts, custom scoring script
[Scope]    content/blog/*.md (12 files)
[Metric]   Average SEO score across posts (higher is better)
[Verify]   node scripts/seo-score.js content/blog/ | grep "average" | awk '{print $2}'
[Dry run]  ✓ Exit 0 — Baseline: 64
```

### Docker image size

```
> /autoresearch:plan Reduce Docker image size

[Context]  Detected: Dockerfile, .dockerignore, Node.js app
[Scope]    Dockerfile, .dockerignore (2 files)
[Metric]   Image size in MB (lower is better)
[Verify]   docker build -t bench . -q 2>&1 && docker images bench --format "{{.Size}}" | sed 's/MB//'
[Dry run]  ✓ Exit 0 — Baseline: 487
```

### When to use the plan wizard

| Situation | Recommendation |
|-----------|----------------|
| First time using autoresearch | `/autoresearch:plan` — learn the format |
| Unsure what metric to use | `/autoresearch:plan` — it suggests options |
| Want to validate before a long run | `/autoresearch:plan` — dry-run confirms it works |
| Know exactly what you want | `/autoresearch` directly — skip the wizard |
| Running overnight | `/autoresearch:plan` then launch — confidence before sleep |

---

## Security Audit Examples

### Basic usage

```
# Unlimited — keep finding vulnerabilities until interrupted
/autoresearch:security

# Bounded — exactly 10 security sweep iterations
/autoresearch:security
Iterations: 10

# With focused scope
/autoresearch:security
Scope: src/api/**/*.ts, src/middleware/**/*.ts
Focus: authentication and authorization flows
```

### How the audit works

```
┌─────────────────────────────────────────────────────────────┐
│                    SETUP PHASE (once)                       │
│                                                             │
│  1. Codebase Recon     Scan tech stack, deps, configs       │
│  2. Asset Inventory    Data stores, auth, APIs, inputs      │
│  3. Trust Boundaries   Client↔Server, Public↔Auth, etc.     │
│  4. STRIDE Model       Full threat model per asset+boundary │
│  5. Attack Surface     Entry points, data flows, abuse paths│
│  6. Baseline           Run npm audit / existing tools       │
├─────────────────────────────────────────────────────────────┤
│                    AUTONOMOUS LOOP                          │
│                                                             │
│  LOOP (FOREVER or N times):                                 │
│    1. Select untested attack vector from threat model       │
│    2. Deep-dive into target code                            │
│    3. Validate with code evidence (file:line + scenario)    │
│    4. Classify: severity + OWASP category + STRIDE tag      │
│    5. Log to security-audit-results.tsv                     │
│    6. Print coverage summary every 5 iterations             │
│    7. Repeat                                                │
├─────────────────────────────────────────────────────────────┤
│                    STRUCTURED REPORT FOLDER                 │
│                                                             │
│  security/260315-0945-stride-owasp-full-audit/              │
│  ├── overview.md              Executive summary + links     │
│  ├── threat-model.md          STRIDE analysis + assets      │
│  ├── attack-surface-map.md    Entry points + abuse paths    │
│  ├── findings.md              All findings by severity      │
│  ├── owasp-coverage.md        Coverage matrix per category  │
│  ├── dependency-audit.md      npm/pip/go audit results      │
│  ├── recommendations.md       Prioritized fixes + code      │
│  └── security-audit-results.tsv  Iteration log             │
└─────────────────────────────────────────────────────────────┘
```

### STRIDE threat model

| Threat | Question | Example Findings |
|--------|----------|------------------|
| **S**poofing | Can an attacker impersonate a user/service? | Weak auth, missing CSRF, forged JWTs |
| **T**ampering | Can data be modified in transit/at rest? | Missing validation, SQL injection |
| **R**epudiation | Can actions be denied without evidence? | Missing audit logs, unsigned transactions |
| **I**nfo Disclosure | Can sensitive data leak? | PII in logs, verbose errors, debug endpoints |
| **D**enial of Service | Can the service be disrupted? | Missing rate limits, regex DoS |
| **E**levation of Privilege | Can a user gain unauthorized access? | IDOR, broken access control, path traversal |

### OWASP Top 10 coverage

Each iteration targets uncovered OWASP categories:

| ID | Category | Checks |
|----|----------|--------|
| A01 | Broken Access Control | IDOR, missing auth middleware, privilege escalation |
| A02 | Cryptographic Failures | Plaintext secrets, weak hashing, missing encryption |
| A03 | Injection | SQL/NoSQL/command/XSS/template injection |
| A04 | Insecure Design | Missing rate limits, race conditions, CSRF gaps |
| A05 | Security Misconfiguration | Debug mode, default creds, missing headers |
| A06 | Vulnerable Components | Known CVEs in dependencies |
| A07 | Auth Failures | JWT flaws, session fixation, weak passwords |
| A08 | Data Integrity Failures | Unsigned webhooks, insecure deserialization |
| A09 | Logging Failures | Missing audit logs, sensitive data in logs |
| A10 | SSRF | Unvalidated URLs, DNS rebinding |

### Red-team adversarial lenses

| Persona | Mindset | Focus |
|---------|---------|-------|
| **Security Adversary** | "I'm a hacker breaching this system" | Auth bypass, injection, data exposure |
| **Supply Chain Attacker** | "I'm compromising deps or CI/CD" | CVEs, typosquatting, unsigned artifacts |
| **Insider Threat** | "I'm a malicious employee" | Privilege escalation, data exfiltration |
| **Infrastructure Attacker** | "I'm attacking deployment, not code" | Container escape, exposed services, env vars |

### Example session output

```
> /autoresearch:security
> Iterations: 10

[Setup] Scanning codebase...
  Tech stack: Next.js 16, TypeScript, MongoDB, JWT auth
  Assets: 3 data stores, 14 API routes, 2 external services
  Trust boundaries: 4 identified
  STRIDE threats: 18 modeled
  Attack vectors: 22 mapped

[Iteration 1] Testing: IDOR on /api/users/:id
  → CONFIRMED HIGH (A01/EoP) — src/api/users.ts:42

[Iteration 2] Testing: JWT validation
  → CONFIRMED CRITICAL (A07/Spoofing) — src/middleware/auth.ts:18

[Iteration 3] Testing: Rate limiting on /api/auth/login
  → CONFIRMED MEDIUM (A04/DoS) — src/api/auth.ts:15
...

=== Security Audit Complete (10/10 iterations) ===
STRIDE Coverage: S[✓] T[✓] R[✗] I[✓] D[✓] E[✓] — 5/6
OWASP Coverage: A01[✓] A02[✓] A03[✓] A04[✓] A05[✓] A06[✓] A07[✓] A08[✗] A09[✗] A10[✗] — 7/10
Findings: 2 Critical, 3 High, 4 Medium, 1 Low
```

### Finding format (proof-of-concept)

Every finding requires **code evidence**:

```markdown
### [CRITICAL] Finding: JWT Algorithm Confusion
- **OWASP:** A07 — Auth Failures
- **STRIDE:** Spoofing
- **Location:** `src/middleware/auth.ts:18`
- **Confidence:** Confirmed
- **Attack Scenario:**
  1. Attacker crafts JWT with `"alg": "none"`
  2. Server accepts token without signature verification
  3. Attacker gains access as any user
- **Code Evidence:**
  // Line 18 — no algorithm restriction
  const decoded = jwt.verify(token, process.env.JWT_SECRET);
- **Mitigation:**
  const decoded = jwt.verify(token, process.env.JWT_SECRET, {
    algorithms: ['HS256']
  });
```

### Security metric

```
metric = (owasp_tested/10)*50 + (stride_tested/6)*30 + min(findings, 20)
```

Higher = more thorough. Max theoretical: 100.

### Flags

| Flag | Purpose |
|------|---------|
| `--diff` | Only audit files changed since last audit (delta mode) |
| `--fix` | Auto-fix confirmed Critical/High after audit |
| `--fail-on <severity>` | Exit non-zero for CI/CD gating (`critical`, `high`, `medium`) |

Flags combine: `/autoresearch:security --diff --fix --fail-on critical --iterations 15`

Execution order: `--diff` narrows scope → audit runs → `--fix` remediates → `--fail-on` gates remaining findings.

### CI/CD GitHub Action (auto-generated)

When a `.github/workflows/` directory is detected, the wizard offers to generate:

```yaml
# .github/workflows/security-audit.yml
name: Security Audit
on:
  pull_request:
    branches: [main]
  schedule:
    - cron: '0 2 * * 1'  # Weekly Monday 2am

jobs:
  security-audit:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run Security Audit
        run: |
          if [ "${{ github.event_name }}" = "pull_request" ]; then
            claude -p "/autoresearch:security --diff --fail-on critical --iterations 5"
          else
            claude -p "/autoresearch:security --fail-on high --iterations 15"
          fi
      - name: Upload Report
        uses: actions/upload-artifact@v4
        with:
          name: security-report
          path: security/
```

### When to run security audits

| Scenario | Recommendation |
|----------|---------------|
| Before a major release | `/autoresearch:security` with `Iterations: 15` |
| Quick sanity check | `/autoresearch:security` with `Iterations: 5` |
| Comprehensive overnight | `/autoresearch:security` (unlimited) |
| CI/CD gate | `/autoresearch:security --fail-on critical --iterations 10` |
| PR review (changed files) | `/autoresearch:security --diff --iterations 5` |
| After auth/API changes | `/autoresearch:security --diff --fix` |
| Compliance preparation | `/autoresearch:security` with `Iterations: 20` |

---

## Ship Workflow Examples

### Ship a code PR

```
/autoresearch:ship --auto
```

### Dry-run a deployment

```
/autoresearch:ship --type deployment --dry-run
```

### Ship with monitoring

```
/autoresearch:ship --type deployment --monitor 10
```

### Ship a blog post

```
/autoresearch:ship
Target: content/blog/my-new-post.md
Type: content
```

### Ship a sales deck

```
/autoresearch:ship --type sales
Target: decks/q1-enterprise-proposal.pdf
```

### Iterate on readiness then ship

```
/autoresearch:ship
Iterations: 5
```

### Just check readiness

```
/autoresearch:ship --checklist-only
```

### Rollback a bad deployment

```
/autoresearch:ship --rollback
```

### Flag combinations

```bash
# Full combo: delta security + auto-fix + CI gate
/autoresearch:security --diff --fix --fail-on critical --iterations 15

# Quick delta check, block on criticals
/autoresearch:security --diff --fail-on critical --iterations 5

# Overnight comprehensive + auto-remediation
/autoresearch:security --fix

# Plan then run
/autoresearch:plan

# Ship with auto-approve
/autoresearch:ship --auto

# Dry-run deployment
/autoresearch:ship --type deployment --dry-run

# Ship with post-deploy monitoring (10 minutes)
/autoresearch:ship --type deployment --monitor 10

# Iterate on readiness (5 preparation iterations)
/autoresearch:ship --iterations 5

# Just check if ready
/autoresearch:ship --checklist-only
```

---

## Scenario Examples

### Explore a checkout flow (software)

```
/autoresearch:scenario
Scenario: User completes checkout with multiple payment methods
Domain: software
Depth: standard
Iterations: 25
```

### Edge cases for file upload

```
/autoresearch:scenario --depth deep --focus edge-cases
Scenario: User uploads profile picture via drag-and-drop
```

### Security-focused scenario exploration

```
/autoresearch:scenario --domain security
Scenario: OAuth2 login flow with third-party providers
Iterations: 30
```

### Generate test scenarios for an API

```
/autoresearch:scenario --format test-scenarios --domain software
Scenario: REST API pagination with filtering and sorting
Iterations: 20
```

### Product/UX user journey mapping

```
/autoresearch:scenario --domain product --format user-stories
Scenario: New user onboarding from signup to first value moment
```

### Business process exploration

```
/autoresearch:scenario --domain business --depth deep
Scenario: Employee submits expense report for approval
Iterations: 30
```

### Interactive mode (no context — ask everything)

```
/autoresearch:scenario
```

Claude asks 4-8 adaptive questions based on what you provide. Just type the command and it guides you.

### Chain: scenario → debug → fix

```bash
# Step 1: Discover what could go wrong
/autoresearch:scenario --domain software
Scenario: User resets password with expired token
Iterations: 15

# Step 2: Hunt bugs in the discovered areas
/autoresearch:debug --scope src/auth/**
Symptom: edge cases from scenario exploration

# Step 3: Fix what was found
/autoresearch:fix --from-debug
Iterations: 20
```

### Flag combinations

```bash
# Quick shallow scan for edge cases
/autoresearch:scenario --depth shallow --focus edge-cases API rate limiting behavior

# Deep security threat modeling
/autoresearch:scenario --domain security --depth deep --format threat-scenarios --iterations 50

# Scoped to specific files
/autoresearch:scenario --scope src/payments/** --domain software User processes refund

# Generate test scenarios then ship
/autoresearch:scenario --format test-scenarios --domain software --iterations 20
/autoresearch:ship --auto
```

---

## Writing Verification Scripts

The skill works best when verification is **fast and mechanical**. Here's a template:

```javascript
// scripts/score-example.js — Template for custom scoring
const fs = require('fs');
const file = process.argv[2];
const content = fs.readFileSync(file, 'utf-8');

// Your scoring logic here
const score = content.split('\n').filter(l => l.startsWith('- ')).length;

// Output MUST be a single number on its own line for easy parsing
console.log(`SCORE: ${score}`);
process.exit(score > 0 ? 0 : 1);
```

### Rules for good verification

| Rule | Why |
|------|-----|
| Runs in under 10 seconds | Fast = more iterations = more experiments |
| Outputs a single parseable number | Claude needs to extract the metric mechanically |
| Exit code 0 = success, non-zero = crash | Clean pass/fail signal |
| No human judgment required | Agent must decide autonomously |
| Deterministic (same input = same output) | Non-deterministic metrics break the feedback loop |

---

## Core Principles

7 principles extracted from [Karpathy's autoresearch](https://github.com/karpathy/autoresearch), generalized to any domain:

### 1. Constraint = Enabler

Autonomy succeeds through intentional constraint, not despite it.

| Autoresearch | Generalized |
|---|---|
| 630-line codebase | Bounded scope that fits agent context |
| 5-minute time budget | Fixed iteration cost |
| One metric (val_bpb) | Single mechanical success criterion |

### 2. Separate Strategy from Tactics

Humans set direction (**what** to improve). Agents execute iterations (**how** to improve it).

| Strategic (Human) | Tactical (Agent) |
|---|---|
| "Improve page load speed" | "Lazy-load images, code-split routes" |
| "Increase test coverage" | "Add tests for uncovered edge cases" |

### 3. Metrics Must Be Mechanical

**Good:** `npm test -- --coverage | grep "All files"` → outputs `87.3%`

**Bad:** "Looks better", "probably improved" → kills the loop.

### 4. Verification Must Be Fast

| Fast (enables iteration) | Slow (kills iteration) |
|---|---|
| Unit tests (seconds) | Full E2E suite (minutes) |
| Type check (seconds) | Manual QA (hours) |
| Lint check (instant) | Code review (async) |

### 5. Iteration Cost Shapes Behavior

Cheap iteration → bold exploration, many experiments.
Expensive iteration → conservative, few experiments.

### 6. Git as Memory

Every successful change is committed. Failures are reverted. Enables causality tracking, stacking wins, pattern learning.

### 7. Honest Limitations

If the agent hits a wall (missing permissions, external dependency, needs human judgment), it says so clearly instead of guessing.

---

## Domain Adaptation Reference

| Domain | Metric | Scope | Verify Command | Guard |
|--------|--------|-------|----------------|-------|
| Backend code | Tests pass + coverage % | `src/**/*.ts` | `npm test` | — |
| Frontend UI | Lighthouse score | `src/components/**` | `npx lighthouse` | `npm test` |
| ML training | val_bpb / loss | `train.py` | `uv run train.py` | — |
| Blog/content | Word count + readability | `content/*.md` | Custom script | — |
| Performance | Benchmark time (ms) | Target files | `npm run bench` | `npm test` |
| Refactoring | Tests pass + LOC reduced | Target module | `npm test && wc -l` | `npm run typecheck` |
| Security | OWASP + STRIDE coverage | API/auth/middleware | `/autoresearch:security` | — |
| Shipping | Checklist pass rate (%) | Any artifact | `/autoresearch:ship` | Domain-specific |

Adapt the loop to your domain. The **principles** are universal; the **metrics** are domain-specific.

---

## Bounded Iterations

By default, autoresearch loops **forever**. Add `Iterations: N` to your inline config for fixed iterations.

```
/autoresearch
Goal: Increase test coverage to 90%
Iterations: 25
```

### When to use bounded iterations

| Scenario | Recommendation |
|----------|---------------|
| Run overnight | Unlimited (default) |
| Quick 30-min session | `Iterations: 10` |
| Targeted fix | `Iterations: 5` |
| Exploratory | `Iterations: 15` |
| CI/CD integration | `--iterations N` flag (set N based on time budget) |

### Final summary format

```
=== Autoresearch Complete (25/25 iterations) ===
Baseline: 72.0% → Final: 89.3% (+17.3%)
Keeps: 12 | Discards: 11 | Crashes: 2
Best iteration: #18 — add tests for payment processing edge cases
```
