# Security Workflow — $autoresearch security

Autonomous security auditing that uses the autoresearch loop to iteratively discover, validate, and report vulnerabilities. Combines STRIDE threat modeling, OWASP Top 10 sweeps, and red-team adversarial analysis into a single autonomous loop.

**Output:** A severity-ranked security report with threat model, findings, mitigations, and iteration log.

## Trigger

- User invokes `$autoresearch security`
- User says "security audit", "run a security sweep", "threat model this codebase", "find vulnerabilities"
- User says "red-team this app", "OWASP audit", "STRIDE analysis"

## Loop Support

Works with both unbounded and bounded modes:

```
# Unlimited — keep finding vulnerabilities until interrupted
$autoresearch security

# Bounded — run exactly N security sweep iterations
$autoresearch security
Iterations: 10

# With target scope
$autoresearch security
Scope: src/api/**/*.ts, src/middleware/**/*.ts
Focus: authentication and authorization flows
```

## PREREQUISITE: Interactive Setup (when invoked without flags)

**CRITICAL — BLOCKING PREREQUISITE:** If `$autoresearch security` is invoked without `--diff`, scope, or focus, you MUST scan the codebase first, then use direct prompting to gather user input BEFORE proceeding to ANY phase. DO NOT skip this step.

**Single batched call — all 3 questions at once:**

You MUST call direct prompting with all 3 questions in ONE call:

| # | Header | Question | Options (from codebase scan) |
|---|--------|----------|------------------------------|
| 1 | `Scope` | "What should I audit?" | "Entire codebase (comprehensive)", "API routes + middleware only", "Authentication + authorization", "External-facing code only" |
| 2 | `Depth` | "How thorough?" | "Quick scan (5 iterations)", "Standard audit (15 iterations)", "Deep audit (30+ iterations)", "Unlimited" |
| 3 | `Action` | "What should I do with confirmed vulnerabilities?" | "Report only (read-only)", "Report + auto-fix Critical/High", "Report + CI gate (fail on critical)" |

**IMPORTANT:** Always ask all questions in a single call — never one at a time.

If flags are provided inline, skip interactive setup and proceed directly.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                  SETUP PHASE (once)                         │
│                                                             │
│  1. Scan codebase → identify tech stack, frameworks, APIs   │
│  2. Map assets → data stores, auth, external services       │
│  3. Identify trust boundaries → client/server, API/DB       │
│  4. Generate STRIDE threat model                            │
│  5. Build attack surface map                                │
│  6. Create security-audit-results.tsv log                   │
│  7. Establish baseline (count known issues)                 │
│                                                             │
├─────────────────────────────────────────────────────────────┤
│                  AUTONOMOUS LOOP                            │
│                                                             │
│  Each iteration: pick ONE attack vector from the threat     │
│  model, attempt to find/validate the vulnerability,         │
│  log the result, move to next vector.                       │
│                                                             │
│  LOOP (FOREVER or N times):                                 │
│    1. Review: threat model + past findings + results log    │
│    2. Select: pick next untested attack vector              │
│    3. Analyze: deep-dive into target code for the vector    │
│    4. Validate: construct proof (code path, input, output)  │
│    5. Classify: severity + OWASP category + STRIDE category │
│    6. Log: append to results log                            │
│    7. Repeat                                                │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## Setup Phase — Threat Model Generation

### Step 1: Codebase Reconnaissance

Scan the project to build context:

```
READ:
  - package.json / requirements.txt / go.mod (dependencies)
  - .env.example / config files (secrets handling)
  - Dockerfile / docker-compose.yml (infrastructure)
  - API route files (attack surface)
  - Auth/middleware files (trust boundaries)
  - Database schemas/models (data assets)
  - CI/CD configs (supply chain)
```

### Step 2: Asset Identification

Catalog every asset that has security relevance:

| Asset Type | Examples | Priority |
|------------|----------|----------|
| **Data stores** | Database, Redis, file storage, cookies, localStorage | Critical |
| **Authentication** | Login, OAuth, JWT, sessions, API keys | Critical |
| **API endpoints** | REST routes, GraphQL resolvers, webhooks | High |
| **External services** | Payment APIs, email providers, CDN, analytics | High |
| **User input surfaces** | Forms, URL params, headers, file uploads | High |
| **Configuration** | Environment variables, feature flags, CORS settings | Medium |
| **Static assets** | Public files, uploaded content, generated files | Low |

### Step 3: Trust Boundary Mapping

Identify where trust levels change:

```
Trust Boundaries:
  ├── Browser ←→ Server (client-side vs server-side)
  ├── Server ←→ Database (application vs data layer)
  ├── Server ←→ External APIs (internal vs third-party)
  ├── Public routes ←→ Authenticated routes
  ├── User role ←→ Admin role (privilege levels)
  ├── CI/CD ←→ Production (deployment boundary)
  └── Container ←→ Host (infrastructure boundary)
```

### Step 4: STRIDE Threat Model

For each asset + trust boundary combination, analyze threats using STRIDE:

| Threat | Question | Example Findings |
|--------|----------|------------------|
| **S**poofing | Can an attacker impersonate a user/service? | Weak auth, missing CSRF, forged JWTs |
| **T**ampering | Can data be modified in transit or at rest? | Missing input validation, SQL injection, prototype pollution |
| **R**epudiation | Can actions be denied without evidence? | Missing audit logs, unsigned transactions |
| **I**nformation Disclosure | Can sensitive data leak? | Error messages expose internals, PII in logs, debug endpoints |
| **D**enial of Service | Can the service be disrupted? | Missing rate limiting, regex DoS, resource exhaustion |
| **E**levation of Privilege | Can a user gain unauthorized access? | IDOR, broken access control, path traversal |

Output the threat model as a structured table in the security report.

### Step 5: Attack Surface Map

Generate an attack surface map showing:

```
Attack Surface:
  ├── Entry Points
  │   ├── GET /api/users/:id          → IDOR risk (user enumeration)
  │   ├── POST /api/auth/login        → Brute force, credential stuffing
  │   ├── POST /api/upload            → File upload, path traversal
  │   ├── WebSocket /ws               → Auth bypass, injection
  │   └── Webhook /api/webhooks/*     → Signature verification
  ├── Data Flows
  │   ├── User input → DB query       → Injection risk
  │   ├── JWT → route handler          → Token validation
  │   └── File upload → storage        → Malicious file execution
  └── Abuse Paths
      ├── Rate limit bypass → account takeover
      ├── IDOR chain → data exfiltration
      └── SSRF → internal service access
```

### Step 6: Baseline

Count existing security issues before the loop starts:
- Run any existing security linting (`npm audit`, `eslint-plugin-security`, `bandit`, etc.)
- Count issues as baseline metric
- Record in results log as iteration #0

## The Security Loop

### Iteration Protocol

Each iteration follows the autoresearch pattern but adapted for security:

#### Phase 1: Review (Select Attack Vector)

Priority order for selecting the next vector to test:

1. **Critical STRIDE threats** not yet tested
2. **OWASP Top 10 categories** not yet covered
3. **High-severity attack paths** from the surface map
4. **Dependency vulnerabilities** (supply chain)
5. **Configuration weaknesses** (headers, CORS, CSP)
6. **Business logic flaws** (race conditions, state manipulation)
7. **Information disclosure** (error handling, debug modes)

Track coverage in the results log. The goal is comprehensive coverage.

#### Phase 2: Analyze (Deep Dive)

For the selected vector:
1. Read all relevant code files
2. Trace data flow from entry point to data store
3. Identify missing validation, sanitization, or access checks
4. Look for known vulnerability patterns

#### Phase 3: Validate (Proof Construction)

For each potential finding, construct proof:

```
Finding Proof Structure:
  ├── Vulnerable code location (file:line)
  ├── Attack scenario (step-by-step)
  ├── Input that triggers the vulnerability
  ├── Expected vs actual behavior
  ├── Impact assessment
  └── Confidence level (Confirmed / Likely / Possible)
```

**Validation Rules:**
- **Confirmed** — Code path clearly allows the attack, no guards present
- **Likely** — Guards exist but are bypassable or incomplete
- **Possible** — Theoretical risk, depends on configuration or runtime conditions

Do NOT report findings without supporting code evidence.

**Credential hygiene in finding output (mandatory):**

Findings, PoCs, attack scenarios, and reproduction commands SHOULD NOT contain real secrets even when the secret IS the vulnerability. Always mask before writing to any file:

| Pattern | Mask form |
|---|---|
| API keys, JWTs, OAuth tokens | `<REDACTED_TOKEN>` (preserve length class: short/medium/long) |
| Connection strings with embedded passwords | `protocol://user:<REDACTED_PASSWORD>@host/db` |
| Environment variable values | reference the var name only: `$DATABASE_URL`, never the value |
| Private keys, certs | first 8 chars + `<...REDACTED...>` + last 8 chars |
| Sample request bodies | replace value, keep field name: `{"api_key": "<REDACTED>"}` |

When a finding's reproduction needs real credentials, write the PoC as a *template* the user fills in at runtime — never as a copy-paste-ready command containing the live secret. Reject any draft finding that contains a value matching: a JWT (`eyJ...`), 32+ char hex, AWS key prefixes (`AKIA`, `ASIA`), or known token formats. Re-mask and re-emit.

#### Phase 4: Classify

Assign severity and categories:

**Severity (CVSS-inspired):**

| Severity | Criteria |
|----------|----------|
| **Critical** | RCE, auth bypass, SQL injection, data breach, admin takeover |
| **High** | XSS (stored), SSRF, privilege escalation, mass data exposure |
| **Medium** | CSRF, open redirect, info disclosure, missing rate limits |
| **Low** | Missing headers, verbose errors, weak session config |
| **Info** | Best practice suggestions, hardening recommendations |

**OWASP Top 10 (2021) mapping:**

| ID | Category |
|----|----------|
| A01 | Broken Access Control |
| A02 | Cryptographic Failures |
| A03 | Injection |
| A04 | Insecure Design |
| A05 | Security Misconfiguration |
| A06 | Vulnerable Components |
| A07 | Auth & Identification Failures |
| A08 | Software & Data Integrity Failures |
| A09 | Security Logging & Monitoring Failures |
| A10 | Server-Side Request Forgery |

**STRIDE mapping:** Tag each finding with the applicable STRIDE category.

#### Phase 5: Log

Append to security-audit-results.tsv:

```tsv
iteration	vector	severity	owasp	stride	confidence	location	description
0	-	-	-	-	-	-	baseline — 3 npm audit warnings
1	IDOR	High	A01	EoP	Confirmed	src/api/users.ts:42	GET /api/users/:id returns any user data without ownership check
2	XSS	Medium	A03	Tampering	Likely	src/components/comment.tsx:18	User input rendered via dangerouslySetInnerHTML
3	rate-limit	Medium	A05	DoS	Confirmed	src/api/auth.ts:15	POST /login has no rate limiting — brute force possible
```

#### Phase 6: Repeat

- **Unbounded:** Keep finding vulnerabilities. Never stop. Never ask.
- **Bounded (Iterations: N):** After N iterations, generate final report and stop.
- **Coverage tracking:** Every 5 iterations, print coverage summary.

### Coverage Summary Format

```
=== Security Audit Progress (iteration 10) ===
STRIDE Coverage: S[✓] T[✓] R[✗] I[✓] D[✓] E[✓] — 5/6
OWASP Coverage: A01[✓] A02[✗] A03[✓] A04[✗] A05[✓] A06[✓] A07[✓] A08[✗] A09[✗] A10[✗] — 5/10
Findings: 4 Critical, 2 High, 3 Medium, 1 Low
Confirmed: 7 | Likely: 2 | Possible: 1
```

## Final Report Structure

Generated at loop completion (bounded) or on interrupt (unbounded):

```markdown
# Security Audit Report

## Executive Summary
- **Date:** {date}
- **Scope:** {files/directories scanned}
- **Iterations:** {N}
- **Total Findings:** {count} ({critical} Critical, {high} High, {medium} Medium, {low} Low)

## Threat Model

### Assets
{table of identified assets}

### Trust Boundaries
{diagram of trust boundaries}

### STRIDE Analysis
{threat model table}

### Attack Surface Map
{entry points, data flows, abuse paths}

## Findings (Descending Severity)

### [CRITICAL] Finding 1: {title}
- **OWASP:** {category}
- **STRIDE:** {category}
- **Location:** `{file}:{line}`
- **Confidence:** Confirmed / Likely / Possible
- **Description:** {what's wrong}
- **Attack Scenario:** {step-by-step exploitation}
- **Code Evidence:**
  ```{lang}
  {vulnerable code snippet}
  ```
- **Mitigation:**
  ```{lang}
  {fixed code snippet}
  ```
- **References:** {CWE, CVE if applicable}

### [HIGH] Finding 2: ...
...

## Coverage Matrix

| OWASP Category | Tested | Findings |
|----------------|--------|----------|
| A01 Broken Access Control | ✓ | 2 |
| A02 Cryptographic Failures | ✓ | 0 |
| ... | ... | ... |

| STRIDE Category | Tested | Findings |
|-----------------|--------|----------|
| Spoofing | ✓ | 1 |
| Tampering | ✓ | 2 |
| ... | ... | ... |

## Dependency Audit
{npm audit / pip audit / go vulnerabilities}

## Security Headers Check
{CSP, HSTS, X-Frame-Options, etc.}

## Recommendations (Priority Order)
1. {Critical fix 1}
2. {Critical fix 2}
...

## Iteration Log
{full TSV content}
```

## OWASP Checks Reference

Detailed checks to perform for each OWASP category:

### A01 — Broken Access Control
- [ ] IDOR on all parameterized routes (`:id`, `:slug`)
- [ ] Missing authorization middleware on protected routes
- [ ] Horizontal privilege escalation (user A accessing user B's data)
- [ ] Vertical privilege escalation (user accessing admin functions)
- [ ] Directory traversal on file operations
- [ ] CORS misconfiguration allowing unauthorized origins
- [ ] Missing function-level access control

### A02 — Cryptographic Failures
- [ ] Sensitive data in plaintext (passwords, tokens, PII)
- [ ] Weak hashing algorithms (MD5, SHA1 for passwords)
- [ ] Hardcoded secrets/API keys in source
- [ ] Missing encryption at rest / in transit
- [ ] Weak random number generation for security tokens
- [ ] Exposed .env files or config with secrets

### A03 — Injection
- [ ] SQL/NoSQL injection in database queries
- [ ] Command injection in shell executions (exec, spawn)
- [ ] XSS (stored, reflected, DOM-based)
- [ ] Template injection (SSTI)
- [ ] LDAP injection
- [ ] Path injection in file operations
- [ ] Header injection (CRLF)

### A04 — Insecure Design
- [ ] Missing rate limiting on sensitive endpoints
- [ ] No account lockout after failed login attempts
- [ ] Predictable resource identifiers
- [ ] Race conditions in critical operations
- [ ] Missing CSRF protection on state-changing operations
- [ ] Insecure direct object references in design

### A05 — Security Misconfiguration
- [ ] Debug mode enabled in production
- [ ] Default credentials / admin pages exposed
- [ ] Verbose error messages exposing internals
- [ ] Missing security headers (CSP, HSTS, X-Content-Type-Options)
- [ ] Unnecessary HTTP methods enabled
- [ ] Directory listing enabled
- [ ] Stack traces in error responses

### A06 — Vulnerable and Outdated Components
- [ ] Known CVEs in dependencies (npm audit, pip audit)
- [ ] Outdated frameworks with security patches available
- [ ] Unmaintained dependencies
- [ ] Dependencies with known prototype pollution

### A07 — Identification and Authentication Failures
- [ ] Weak password policies
- [ ] Missing multi-factor authentication for admin
- [ ] Session fixation vulnerabilities
- [ ] JWT vulnerabilities (none algorithm, weak secret, no expiry)
- [ ] Insecure password reset flows
- [ ] Missing session invalidation on logout/password change

### A08 — Software and Data Integrity Failures
- [ ] Missing integrity checks on CI/CD pipelines
- [ ] Unsigned or unverified updates/dependencies
- [ ] Insecure deserialization
- [ ] Missing CSP or SRI for external scripts
- [ ] Unsigned webhooks / API callbacks

### A09 — Security Logging and Monitoring Failures
- [ ] Missing audit logs for security events
- [ ] No logging of failed authentication attempts
- [ ] Sensitive data in logs (passwords, tokens)
- [ ] Missing alerting on suspicious activity
- [ ] Log injection vulnerabilities

### A10 — Server-Side Request Forgery (SSRF)
- [ ] Unvalidated URLs in server-side requests
- [ ] DNS rebinding vulnerabilities
- [ ] Missing allowlist for external service calls
- [ ] Proxy/redirect endpoints without validation

## Red-Team Adversarial Lenses

Adapted from the plan red-team workflow for security context:

### Security Adversary (Primary)
**Mindset:** "I'm a hacker trying to breach this system"
- Focus: auth bypass, injection, data exposure, privilege escalation
- Method: trace every input to its sink, find missing guards
- Priority: exploitable findings over theoretical risks

### Supply Chain Attacker
**Mindset:** "I'm compromising dependencies or build pipeline"
- Focus: dependency vulnerabilities, CI/CD weaknesses, unsigned artifacts
- Method: audit dependency tree, check for typosquatting, verify integrity
- Priority: dependencies with known CVEs, build pipeline access

### Insider Threat
**Mindset:** "I'm a malicious employee or compromised account"
- Focus: privilege escalation, data exfiltration, access control gaps
- Method: check what a low-privilege user can access, find horizontal movement
- Priority: admin bypass, bulk data export, missing audit trails

### Infrastructure Attacker
**Mindset:** "I'm attacking the deployment, not the code"
- Focus: container escape, exposed services, network segmentation
- Method: check Docker configs, K8s manifests, exposed ports, env vars
- Priority: secrets in environment, overly permissive configs

## Strix-Inspired Patterns

Learned from Strix (AI-powered security testing platform):

### Proof-of-Concept Validation
Never report a finding without proof. For each vulnerability:
1. Identify the exact code path
2. Construct a concrete exploit input
3. Trace execution through the vulnerability
4. Show the impact (data leaked, access gained, etc.)

### Multi-Agent Attack Collaboration
Each iteration should build on prior findings:
- Iteration 1 finds open endpoint → Iteration 2 chains with IDOR
- Iteration 3 finds missing rate limit → Iteration 4 tests brute force feasibility
- Findings compound. Each iteration reads past findings for chaining opportunities.

### Dynamic Analysis Verification
Where possible, suggest or construct verification commands:
```bash
# Test for missing rate limiting
for i in {1..100}; do curl -s -o /dev/null -w "%{http_code}" https://app/api/login; done

# Test for IDOR
curl -H "Authorization: Bearer USER_A_TOKEN" https://app/api/users/USER_B_ID

# Test for XSS
curl https://app/search?q=%3Cscript%3Ealert(1)%3C/script%3E
```

### Comprehensive Vulnerability Categories (from Strix)
- **Access Control** — IDOR, privilege escalation, auth bypass
- **Injection Attacks** — SQL, NoSQL, command injection
- **Server-Side** — SSRF, XXE, deserialization flaws
- **Client-Side** — XSS, prototype pollution, DOM vulnerabilities
- **Business Logic** — Race conditions, workflow manipulation
- **Authentication** — JWT vulnerabilities, session management
- **Infrastructure** — Misconfigurations, exposed services

## Metric for the Loop

The security audit uses a **coverage + finding count** composite metric:

```
metric = (owasp_categories_tested / 10) * 50 + (stride_categories_tested / 6) * 30 + min(finding_count, 20)
```

- **Direction:** higher is better (more coverage + more findings = more thorough)
- **Maximum theoretical:** 50 + 30 + 20 = 100
- **Baseline:** 0 (nothing tested yet)

This incentivizes the loop to cover ALL categories before going deep on any one.

## Flags & Modes

### `--diff` — Delta Mode (v1.0.3)

Only audit files changed since the last audit. Reads the most recent `security/` subfolder to establish what was already tested.

```
$autoresearch security --diff
```

**How it works:**

1. Find the latest `security/*/overview.md` by timestamp in folder name
2. Parse `findings.md` from that folder to get previously tested files
3. Run `git diff --name-only {last_audit_commit}..HEAD` to find changed files
4. Scope the current audit to ONLY those changed files
5. In the final report, mark findings as:
   - **New** — found in changed files, not in previous audit
   - **Fixed** — was in previous audit, no longer present in changed code
   - **Recurring** — still present from previous audit (unchanged)

**Delta report additions:**

The overview.md gains a `## Delta Summary` section:

```markdown
## Delta Summary (vs {previous_audit_folder})

| Status | Count | Details |
|--------|-------|---------|
| New findings | 3 | Found in changed files |
| Fixed | 2 | No longer present |
| Recurring | 5 | Still present from last audit |
| Files changed | 12 | Since last audit |
| Files audited | 8 | (security-relevant subset) |
```

If no previous audit folder exists, `--diff` falls back to full audit with a warning.

### `--fail-on` — Severity Threshold Gate (v1.0.3)

Exit with non-zero code if findings meet or exceed a severity threshold. Designed for CI/CD blocking.

```
$autoresearch security --fail-on critical
$autoresearch security --fail-on high
$autoresearch security --fail-on medium
```

| Flag Value | Blocks on |
|------------|-----------|
| `critical` | Any Critical finding |
| `high` | Any Critical or High finding |
| `medium` | Any Critical, High, or Medium finding |

**Behavior:**
- Runs the full audit normally
- After generating the report, checks findings against threshold
- If threshold met: prints `SECURITY GATE FAILED: {N} findings at {severity} or above` and exits non-zero
- If threshold not met: prints `SECURITY GATE PASSED` and exits 0

**CI/CD usage:**
```bash
# In GitHub Actions or CI scripts
claude -p "$autoresearch security --fail-on critical --iterations 10"
# Exit code 1 if any Critical findings → blocks the pipeline
```

### `--fix` — Auto-Remediation Mode

After completing the audit, switches to standard autoresearch modify→verify loop to fix confirmed findings. Uses the security audit report as its goal.

```
$autoresearch security --fix

$autoresearch security --fix
Iterations: 10
```

**How it works:**

1. Run the full security audit (setup + loop + report)
2. Filter findings: only **Confirmed** severity **Critical** and **High**
3. Switch to `$autoresearch fix` with findings context:
   - **Target:** Re-run the security checks that found each vulnerability
   - **Scope:** Files referenced in findings (file:line locations)
   - Pass the filtered findings list as context so fix knows WHAT to fix
   - Fix picks highest-severity unfixed finding each iteration
4. For each fix iteration:
   - Pick the highest-severity unfixed finding
   - Apply the mitigation from `recommendations.md`
   - Commit the fix
   - Re-verify: does the vulnerability still exist?
   - If fixed → keep commit, mark finding as "Fixed" in report
   - If still vulnerable → revert, try different approach
   - If new findings introduced → revert immediately

**Fix report additions:**

After fixes complete, updates the audit folder:
- `findings.md` gains a `Status` column: `Open` / `Fixed` / `Fix attempted`
- `recommendations.md` gains checkmarks on applied fixes
- New file: `fix-log.md` with iteration details

**Safety rules:**
- NEVER fix Low or Info findings automatically (too subjective)
- NEVER modify test files (fixes must not break existing tests)
- Run existing tests after each fix — revert if any test fails
- Maximum 3 fix attempts per finding, then skip
- User can combine with `--fail-on` for gated fix: fix first, then gate

### Combining Flags

Flags can be combined:

```
# Delta audit + auto-fix critical/high + block on remaining criticals
$autoresearch security --diff --fix --fail-on critical
Iterations: 15

# Quick delta check in CI
$autoresearch security --diff --fail-on high
Iterations: 5
```

**Execution order when combined:**
1. `--diff` narrows scope
2. Security audit runs (with narrowed scope if `--diff`)
3. `--fix` runs remediation loop on confirmed Critical/High
4. `--fail-on` checks remaining (unfixed) findings against threshold

### CI/CD GitHub Action Template

When `$autoresearch security` detects a `.github/workflows/` directory, it offers to generate a security workflow:

```
direct prompting:
  question: "I see you use GitHub Actions. Want me to generate a security audit workflow?"
  header: "CI/CD"
  options:
    - label: "Yes, generate it (Recommended)"
      description: "Creates .github/workflows/security-audit.yml"
    - label: "No, skip"
      description: "Continue without CI/CD setup"
```

**Generated workflow:** `.github/workflows/security-audit.yml`

```yaml
name: Security Audit

on:
  pull_request:
    branches: [main, master]
  schedule:
    - cron: '0 2 * * 1'  # Weekly Monday 2am UTC

permissions:
  contents: read
  pull-requests: write

jobs:
  security-audit:
    runs-on: ubuntu-latest
    timeout-minutes: 30
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0  # Full history for delta mode

      - name: Install Claude Code
        run: npm install -g @anthropic-ai/claude-code

      - name: Install Autoresearch Skill
        run: |
          git clone https://github.com/uditgoenka/autoresearch.git /tmp/autoresearch
          cp -r /tmp/autoresearch/skills/autoresearch .agents/skills/autoresearch
          cp -r /tmp/autoresearch/commands/autoresearch .claude/commands/autoresearch
          cp /tmp/autoresearch/commands/autoresearch.md .claude/commands/autoresearch.md

      - name: Run Security Audit
        env:
          ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
        run: |
          # Delta mode on PRs, full audit on schedule
          if [ "${{ github.event_name }}" = "pull_request" ]; then
            claude -p "$autoresearch security --diff --fail-on critical --iterations 5"
          else
            claude -p "$autoresearch security --fail-on high --iterations 15"
          fi

      - name: Upload Security Report
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: security-audit-report
          path: security/
          retention-days: 90

      - name: Comment PR with Summary
        if: github.event_name == 'pull_request' && always()
        uses: actions/github-script@v7
        with:
          script: |
            const fs = require('fs');
            const glob = require('glob');
            const overviews = glob.sync('security/*/overview.md');
            if (overviews.length > 0) {
              const latest = overviews.sort().pop();
              const content = fs.readFileSync(latest, 'utf-8');
              const summary = content.split('## Summary')[1]?.split('##')[0] || 'See full report in artifacts.';
              await github.rest.issues.createComment({
                owner: context.repo.owner,
                repo: context.repo.repo,
                issue_number: context.issue.number,
                body: `## 🔒 Security Audit Results\n\n${summary}\n\n> Full report available in workflow artifacts.`
              });
            }
```

**The template is generated ONCE** — after initial creation, it's the user's file to customize.

### Historical Comparison

When a previous audit exists in `security/`, the current run automatically generates a comparison section.

**Detection:** At setup, scan `security/` for existing audit folders sorted by date.

**Comparison logic:**

```
For each finding in current audit:
  Search previous audit findings.md for same location (file:line) or same description
  If found → mark as "Recurring"
  If not found → mark as "New"

For each finding in previous audit:
  Search current audit findings for same location or description
  If not found → mark as "Fixed"
```

**Output in overview.md:**

```markdown
## Historical Comparison

**Previous audit:** security/260310-1430-stride-owasp-full-audit/ (5 days ago)

### Trend
| Metric | Previous | Current | Change |
|--------|----------|---------|--------|
| Critical | 3 | 1 | ↓ -2 (improved) |
| High | 4 | 5 | ↑ +1 (regressed) |
| Medium | 2 | 3 | ↑ +1 |
| Total | 9 | 9 | → 0 |
| OWASP coverage | 6/10 | 8/10 | ↑ +2 |
| STRIDE coverage | 4/6 | 5/6 | ↑ +1 |

### Finding Status
| Status | Count | Details |
|--------|-------|---------|
| Fixed since last audit | 4 | JWT algo, CORS, 2 XSS |
| New findings | 4 | SSRF, rate limit, 2 IDOR |
| Recurring (unfixed) | 5 | See findings.md |

### Regression Alert
⚠️ 4 new findings detected since last audit. Review [findings.md](./findings.md) for details.
```

**findings.md additions:**

Each finding gets a `History` tag:
- `🆕 New` — first time detected
- `🔄 Recurring` — present in previous audit too
- `✅ Fixed` (only in previous audit's context) — no longer present

## Error Recovery

| Error | Recovery |
|-------|----------|
| Can't determine tech stack | Ask user for framework/language |
| No API routes found | Scan for all exported functions with HTTP-like patterns |
| Dependency audit fails | Skip, note in report, continue with code analysis |
| Code too large for context | Focus on files matching attack surface (API, auth, DB) |
| False positive suspected | Mark as "Possible" confidence, include caveats |

## Anti-Patterns

- **Do NOT report theoretical risks without code evidence** — every finding needs a file:line reference
- **Do NOT skip categories** — the loop should aim for 100% OWASP + STRIDE coverage
- **Do NOT auto-fix vulnerabilities** — report only, user decides what to fix
- **Do NOT test against live production** — analyze code statically, suggest dynamic tests
- **Do NOT report the same finding twice** — check results log for duplicates before logging
- **Do NOT prioritize quantity over quality** — 5 confirmed critical > 50 theoretical lows

## Report Output — Structured Folder

Every `$autoresearch security` run creates a dedicated folder inside a `security/` directory at the project root (similar to how `/plan --hard` creates plan directories).

### Folder Structure

```
{project_root}/
└── security/
    ├── 260315-0945-stride-owasp-full-audit/
    │   ├── overview.md                    ← Executive summary + links to all reports
    │   ├── threat-model.md                ← STRIDE threat model (assets, boundaries, threats)
    │   ├── attack-surface-map.md          ← Entry points, data flows, abuse paths
    │   ├── findings.md                    ← All findings ranked by severity (Critical → Low)
    │   ├── owasp-coverage.md              ← OWASP Top 10 coverage matrix + per-category results
    │   ├── dependency-audit.md            ← npm audit / pip audit / go vuln results
    │   ├── recommendations.md             ← Prioritized mitigations with code snippets
    │   └── security-audit-results.tsv     ← Iteration log (every vector tested)
    │
    ├── 260320-1430-auth-api-focused-audit/
    │   ├── overview.md
    │   ├── threat-model.md
    │   ├── ...
    │   └── security-audit-results.tsv
    │
    └── ...                                ← One subfolder per audit run
```

### Folder Naming Convention

```
security/{YYMMDD}-{HHMM}-{audit-type-slug}/
```

| Component | Source | Example |
|-----------|--------|---------|
| `YYMMDD` | Current date | `260315` |
| `HHMM` | Current time (24h) | `0945` |
| `audit-type-slug` | Inferred from scope/focus | `stride-owasp-full-audit` |

**Slug generation rules:**
- If no scope/focus specified → `stride-owasp-full-audit`
- If scope is auth-related → `auth-authorization-audit`
- If scope is API-related → `api-security-audit`
- If scope is infra-related → `infrastructure-security-audit`
- If user provides a focus string → kebab-case it (e.g., "payment flow" → `payment-flow-audit`)

### File Descriptions

#### overview.md
```markdown
# Security Audit — {audit-type}

**Date:** {YYYY-MM-DD HH:MM}
**Scope:** {files/directories}
**Focus:** {user-provided focus or "comprehensive"}
**Iterations:** {N completed} ({bounded or unlimited})
**Duration:** {approximate time}

## Summary

- **Total Findings:** {count}
  - Critical: {n} | High: {n} | Medium: {n} | Low: {n} | Info: {n}
- **STRIDE Coverage:** {n}/6 categories tested
- **OWASP Coverage:** {n}/10 categories tested
- **Confirmed:** {n} | Likely: {n} | Possible: {n}

## Top 3 Critical Findings

1. [{title}]({findings.md#finding-1}) — {one-line description}
2. [{title}]({findings.md#finding-2}) — {one-line description}
3. [{title}]({findings.md#finding-3}) — {one-line description}

## Files in This Report

- [Threat Model](./threat-model.md) — STRIDE analysis, assets, trust boundaries
- [Attack Surface Map](./attack-surface-map.md) — entry points, data flows, abuse paths
- [Findings](./findings.md) — all findings ranked by severity
- [OWASP Coverage](./owasp-coverage.md) — per-category test results
- [Dependency Audit](./dependency-audit.md) — known CVEs in dependencies
- [Recommendations](./recommendations.md) — prioritized mitigations
- [Iteration Log](./security-audit-results.tsv) — raw data from every iteration
```

#### threat-model.md
Contains the full STRIDE analysis generated in the Setup Phase:
- Asset inventory table
- Trust boundary diagram
- STRIDE threat matrix (per asset × boundary)
- Risk ratings per threat

#### attack-surface-map.md
Contains the attack surface generated in the Setup Phase:
- Entry points (all API routes, webhooks, WebSocket endpoints)
- Data flows (input → processing → storage)
- Abuse paths (chained attack scenarios)

#### findings.md
All findings from the loop, in descending severity:
- Each finding uses the full proof structure (OWASP, STRIDE, location, evidence, mitigation)
- Findings are numbered and linkable via anchors (`#finding-1`, `#finding-2`)

#### owasp-coverage.md
Coverage matrix showing which OWASP categories were tested and results:
```markdown
| ID | Category | Tested | Findings | Status |
|----|----------|--------|----------|--------|
| A01 | Broken Access Control | ✓ | 2 | ⚠️ Issues found |
| A02 | Cryptographic Failures | ✓ | 0 | ✅ Clean |
| A03 | Injection | ✓ | 1 | ⚠️ Issues found |
| ... | ... | ... | ... | ... |
```

Also includes per-category detail: which specific checks were run and their results.

#### dependency-audit.md
Output of dependency security tools:
- `npm audit` / `yarn audit` (Node.js)
- `pip audit` / `safety check` (Python)
- `go vuln` (Go)
- `cargo audit` (Rust)
- Known CVEs, severity, affected versions, fix versions

#### recommendations.md
Prioritized action items with code fix snippets:
```markdown
## Priority 1 — Critical (Fix Immediately)

### 1. Restrict JWT Algorithm
**Finding:** [JWT Algorithm Confusion](./findings.md#finding-2)
**Effort:** 5 minutes
**Fix:**
\```typescript
// Before (vulnerable)
jwt.verify(token, secret);

// After (secure)
jwt.verify(token, secret, { algorithms: ['HS256'] });
\```

### 2. Add IDOR Protection
...

## Priority 2 — High (Fix This Sprint)
...

## Priority 3 — Medium (Plan for Next Sprint)
...
```

### Creation Protocol

1. At the **start** of `$autoresearch security`, create the folder:
   ```
   mkdir -p security/{YYMMDD}-{HHMM}-{slug}
   ```

2. During the **Setup Phase**, write:
   - `threat-model.md` (after STRIDE analysis)
   - `attack-surface-map.md` (after surface mapping)
   - `security-audit-results.tsv` (header row + baseline iteration)

3. During the **Loop**, append to:
   - `security-audit-results.tsv` (after each iteration)

4. At **completion** (bounded loop end or interrupt), write:
   - `findings.md` (all findings consolidated)
   - `owasp-coverage.md` (coverage matrix)
   - `dependency-audit.md` (tool output)
   - `recommendations.md` (prioritized mitigations)
   - `overview.md` (executive summary — written LAST, links to all other files)

5. Print the folder path to the user:
   ```
   Security audit complete. Report saved to:
   security/260315-0945-stride-owasp-full-audit/overview.md
   ```

### Gitignore

Add to `.gitignore` (if not already present):
```
security-audit-results.tsv
```

The `.tsv` iteration log is a working file. The `.md` reports are meant to be committed and shared.
