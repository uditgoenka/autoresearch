# Ship Workflow — /autoresearch_ship

Universal shipping workflow that applies autoresearch loop principles to the last mile — taking anything from "done" to "deployed/published/delivered." Works for code, content, marketing, sales, research, design, or any artifact that needs to reach its audience.

**Core idea:** Shipping has a universal pattern regardless of domain. Identify → Checklist → Prepare → Dry-run → Ship → Verify → Log.

## Trigger

- User invokes `/autoresearch_ship`
- User says "ship it", "deploy this", "publish this", "launch this", "release this"
- User says "get this out the door", "push to prod", "send this out", "go live"

## Loop Support

Works with bounded mode for iterative pre-ship preparation:

```
# Ship with automatic preparation loop
/autoresearch_ship

# Bounded preparation — iterate N times before shipping
/autoresearch_ship
Iterations: 10

# Ship specific artifact
/autoresearch_ship
Target: src/features/auth/**
Destination: production
```

## PREREQUISITE: Interactive Setup (when invoked without flags)

**CRITICAL — BLOCKING PREREQUISITE:** If `/autoresearch_ship` is invoked without `--type` or target, you MUST scan for staged changes, open PRs, and recent commits, then use `question` to gather user input BEFORE proceeding to ANY phase. DO NOT skip this step.

**Single batched call — all 3 questions at once:**

You MUST call `question` with all 3 questions in ONE call:

| # | Header | Question | Options (from context scan) |
|---|--------|----------|----------------------------|
| 1 | `What` | "What are you shipping?" | "Code PR", "Release / version tag", "Deployment to production", "Blog post / documentation" |
| 2 | `Mode` | "How should I ship it?" | "Full workflow (checklist → dry-run → ship → verify)", "Dry-run only (validate without shipping)", "Checklist only (just check readiness)", "Auto-approve (ship if checklist passes)" |
| 3 | `Monitor` | "Post-ship monitoring?" | "No monitoring", "5 minutes", "10 minutes", "30 minutes" |

**IMPORTANT:** Always ask all questions in a single call — never one at a time.

If `--type`, `--dry-run`, `--auto`, or `--checklist-only` flags are provided, skip interactive setup and proceed directly.

## Architecture

```
/autoresearch_ship
  ├── Phase 1: Identify (what are we shipping?)
  ├── Phase 2: Inventory (what's the current state?)
  ├── Phase 3: Checklist (domain-specific pre-ship gates)
  ├── Phase 4: Prepare (autoresearch loop until checklist passes)
  ├── Phase 5: Dry-run (simulate the ship action)
  ├── Phase 6: Ship (execute the actual delivery)
  ├── Phase 7: Verify (post-ship health check)
  └── Phase 8: Log (record the shipment)
```

## Phase 1: Identify — What Are We Shipping?

Auto-detect the shipment type from context, or ask the user.

**Detection algorithm:**
```
FUNCTION detectShipmentType(context):
  # Check explicit user input first
  IF user specifies type → USE IT

  # Auto-detect from context
  IF git diff has staged changes OR user mentions "deploy/release/merge":
    IF has Dockerfile/k8s/deploy configs → "deployment"
    IF has open PR or branch changes → "code-pr"
    ELSE → "code-release"

  IF context mentions "blog/article/post" OR target files are *.md in content/:
    → "content"

  IF context mentions "email/campaign/newsletter":
    → "marketing-email"

  IF context mentions "landing page/ad/social":
    → "marketing-campaign"

  IF context mentions "deck/proposal/pitch/quote":
    → "sales"

  IF context mentions "paper/report/analysis/findings":
    → "research"

  IF context mentions "assets/mockup/design/figma":
    → "design"

  # Default: ask user
  → ASK "What are you shipping? (code/content/marketing/sales/research/design/other)"
```

**Output:** `✓ Phase 1: Identified shipment — [type]: [brief description]`

## Phase 2: Inventory — Current State Assessment

Scan the artifact and its environment to understand readiness.

**For each shipment type, gather:**

| Type | Inventory Checks |
|------|-----------------|
| code-pr | Changed files, test status, lint status, PR description, review status |
| code-release | Version tag, changelog, migration status, dependency audit |
| deployment | Build status, env vars, infra health, rollback plan |
| content | Word count, links checked, images present, metadata/frontmatter |
| marketing-email | Subject line, preview text, links, unsubscribe, CAN-SPAM compliance |
| marketing-campaign | Assets ready, tracking pixels, UTM params, A/B variants |
| sales | Pricing current, branding consistent, contact info, CTA clear |
| research | Citations complete, methodology documented, data sources linked |
| design | Formats exported, responsive variants, accessibility checked |

**Output:** `✓ Phase 2: Inventory complete — [N] items assessed, [M] gaps found`

## Phase 3: Checklist — Domain-Specific Pre-Ship Gates

Generate a mechanical checklist based on shipment type. Every item must be verifiable (pass/fail).

### Code Checklists

**code-pr:**
- [ ] All tests pass (`npm test` / `pytest` / language-specific)
- [ ] Lint clean (no errors, warnings acceptable)
- [ ] Type check passes (if applicable)
- [ ] PR description explains the "why"
- [ ] No secrets in diff (`git diff --cached | grep -i "password\|secret\|api_key"`)
- [ ] No TODO/FIXME in new code (or documented as intentional)
- [ ] Breaking changes documented (if any)
- [ ] Reviewer assigned or review complete

**code-release:**
- [ ] All code-pr checks pass
- [ ] Version bumped in package.json/pyproject.toml/Cargo.toml
- [ ] CHANGELOG updated with release notes
- [ ] Migration scripts tested (if DB changes)
- [ ] Dependency audit clean (`npm audit` / `pip audit`)
- [ ] Tag created matching version

**deployment:**
- [ ] All code-release checks pass
- [ ] Build succeeds in CI
- [ ] Environment variables set for target env
- [ ] Health check endpoint responds
- [ ] Rollback plan documented
- [ ] Monitoring/alerting configured
- [ ] Feature flags set correctly

### Content Checklists

**content (blog/docs):**
- [ ] Title present and descriptive
- [ ] No broken links (internal or external)
- [ ] Images have alt text
- [ ] Meta description present (≤160 chars)
- [ ] No placeholder text ("Lorem ipsum", "TODO", "TBD")
- [ ] Grammar/spell check passes
- [ ] Publish date set
- [ ] Author attribution present

### Marketing Checklists

**marketing-email:**
- [ ] Subject line present (≤60 chars recommended)
- [ ] Preview text set
- [ ] All links working and tracked (UTM parameters)
- [ ] Unsubscribe link present and functional
- [ ] Physical address included (CAN-SPAM)
- [ ] Responsive on mobile (test render)
- [ ] Plain text fallback exists
- [ ] Sender name and reply-to configured

**marketing-campaign:**
- [ ] All creative assets finalized
- [ ] Tracking pixels/UTM parameters configured
- [ ] Target audience defined and segmented
- [ ] Budget allocated and approved
- [ ] Landing page live and tested
- [ ] A/B test variants set (if applicable)
- [ ] Schedule confirmed

### Sales Checklists

**sales (deck/proposal):**
- [ ] Company/prospect name correct throughout
- [ ] Pricing is current and approved
- [ ] Contact information accurate
- [ ] Branding consistent (logos, colors, fonts)
- [ ] No competitor names misspelled
- [ ] CTA is clear and actionable
- [ ] Attached case studies/testimonials current
- [ ] File format appropriate (PDF for external, editable for internal)

### Research Checklists

**research (paper/report):**
- [ ] Abstract/executive summary present
- [ ] All citations properly formatted
- [ ] Data sources linked and accessible
- [ ] Methodology section complete
- [ ] Figures/charts labeled and referenced
- [ ] Conclusion addresses stated hypothesis
- [ ] Acknowledgments included
- [ ] No placeholder references ("[citation needed]")

### Design Checklists

**design (assets/mockups):**
- [ ] All requested formats exported (PNG, SVG, PDF)
- [ ] Responsive variants provided (mobile, tablet, desktop)
- [ ] Color contrast meets WCAG AA (4.5:1 for text)
- [ ] No placeholder images or text
- [ ] Source files organized and named
- [ ] Brand guidelines followed
- [ ] Handoff notes/specs documented

**Output:** `✓ Phase 3: Checklist generated — [N] items, [P] passing, [F] failing`

## Phase 4: Prepare — Iterative Improvement Loop

Apply the autoresearch loop to fix failing checklist items.

```
metric = count_passing_checklist_items / total_checklist_items * 100
direction = higher_is_better
target = 100 (all items pass)

LOOP (until all pass OR max iterations):
  1. Read checklist status
  2. Pick highest-priority failing item
  3. Fix it (one atomic change)
  4. Re-run checklist verification
  5. IF item now passes → keep, log "fixed: [item]"
  6. IF item still fails → revert, try different approach
  7. IF all items pass → EXIT LOOP with "ready to ship"
```

**Priority order for fixes:**
1. **Blockers** — security issues, broken builds, missing critical content
2. **Required** — tests, lint, links, compliance items
3. **Recommended** — descriptions, documentation, polish

**Auto-fix capabilities:**
- Run test suites and fix failures
- Fix lint errors automatically
- Add missing meta descriptions
- Generate changelog entries from git log
- Check and fix broken links
- Add alt text to images (describe or prompt user)
- Format citations
- Export missing design formats

**Items that require human input:**
- Pricing approval
- Legal review sign-off
- Brand approval
- Strategic decisions (A/B test variants)
- → Flag these and ask user, don't block on them

**Output:** `✓ Phase 4: Preparation complete — [N/N] checklist items passing`

## Phase 5: Dry-Run — Simulate Before Shipping

Execute a simulation of the ship action without side effects.

| Type | Dry-Run Action |
|------|---------------|
| code-pr | `gh pr create --draft` or preview PR diff |
| code-release | Create tag locally (don't push), preview changelog |
| deployment | Build Docker image, run health checks locally |
| content | Preview render, check all links resolve |
| marketing-email | Send test email to sender's own address |
| marketing-campaign | Preview in ad platform, estimate reach |
| sales | Preview PDF render, check all pages |
| research | Export to final format, check pagination |
| design | Preview all exported formats, check dimensions |

**Dry-run gate:**
- Present dry-run results to user
- `--auto` flag: auto-approve if no errors
- Default: ask user "Ready to ship?" before proceeding
- `--dry-run` flag: stop here, don't actually ship

**Output:** `✓ Phase 5: Dry-run complete — [result summary]`

## Phase 6: Ship — Execute the Delivery

The actual ship action. Domain-specific.

| Type | Ship Action |
|------|------------|
| code-pr | `gh pr create` with full description, request reviewers |
| code-release | `git tag`, `git push --tags`, create GitHub release |
| deployment | `git push` to deploy branch, trigger CI/CD, or `kubectl apply` |
| content | Publish via CMS API, or commit to content branch |
| marketing-email | Send via ESP API (SendGrid, Mailchimp, etc.) |
| marketing-campaign | Activate campaign in ad platform |
| sales | Send email with attachment, or share link |
| research | Upload to repository, submit to journal/platform |
| design | Upload to asset library, share with stakeholders |

**Safety rails:**
- Confirm target (staging vs production, draft vs publish)
- Log the exact command/action taken
- Record timestamp
- Capture any response/confirmation IDs

**Output:** `✓ Phase 6: Shipped — [action taken] at [timestamp]`

## Phase 7: Verify — Post-Ship Health Check

Confirm the shipment actually landed and is healthy.

| Type | Verification |
|------|-------------|
| code-pr | PR created, CI running, link accessible |
| code-release | Tag visible, release page published, assets attached |
| deployment | Health endpoint returns 200, no error spike in logs |
| content | Page loads, links work, appears in sitemap |
| marketing-email | Delivery rate > 95%, no bounce spike |
| marketing-campaign | Ads serving, landing page loading, tracking firing |
| sales | Email delivered, link tracking active |
| research | Accessible via URL/DOI, properly indexed |
| design | Assets downloadable, correct dimensions |

**Post-ship monitoring (with `--monitor N` flag):**
```
FOR N minutes:
  Check health metrics every 60 seconds
  IF anomaly detected → ALERT user immediately
  Log metrics to ship-log
```

**Output:** `✓ Phase 7: Verified — [health status summary]`

## Phase 8: Log — Record the Shipment

Create a ship log entry for traceability.

**Log format (append to `ship-log.tsv`):**
```tsv
timestamp	type	target	checklist_score	dry_run	shipped	verified	duration	notes
2026-03-16T14:30:00Z	code-pr	#42	18/18	pass	pass	pass	4m32s	auth feature PR
```

**Summary output:**
```
=== Ship Complete ===
Type: [shipment type]
Target: [where it went]
Checklist: [P/T] items passed
Duration: [total time]
Status: SHIPPED ✓
```

## Flags

| Flag | Purpose |
|------|---------|
| `--dry-run` | Run all phases except actual ship (stop at Phase 5) |
| `--auto` | Auto-approve dry-run gate if no errors found |
| `--force` | Skip non-critical checklist items (still enforce blockers) |
| `--rollback` | Undo the last ship action (if reversible) |
| `--monitor N` | Post-ship monitoring for N minutes |
| `--type <type>` | Override auto-detection with explicit shipment type |
| `--checklist-only` | Only generate and evaluate checklist (stop at Phase 3) |
| `--chain <targets>` | Chain to downstream tool(s) after completion. Comma-separated for multi-chain. Spaces after commas tolerated. | `--chain debug` or `--chain scenario,debug,fix` |

## Composite Metric

For bounded loop mode, the ship readiness metric:

```
ship_score = (checklist_passing / checklist_total) * 80
           + (dry_run_passed ? 15 : 0)
           + (no_blockers ? 5 : 0)
```

- **100** = fully ready to ship
- **80-99** = ready with minor items (can ship with `--force`)
- **<80** = not ready, continue preparing

## Rollback Protocol

If `--rollback` is specified or post-ship verification fails:

| Type | Rollback Action |
|------|----------------|
| code-pr | Close PR: `gh pr close` |
| code-release | Delete tag: `git tag -d` + `git push --delete origin` |
| deployment | Revert deploy: `git revert` or `kubectl rollback` |
| content | Unpublish/revert to draft |
| marketing-email | Cannot rollback (flag as "sent") |
| marketing-campaign | Pause campaign in ad platform |
| sales | Send correction/follow-up |
| research | Request retraction or update |
| design | Revert to previous version in asset library |

**Non-reversible actions** (email, some publications) are flagged before Phase 6 ship action.

## Chain Conversion

When `--chain` is specified, ship passes results forward after Phase 8 completes. Output includes: ship results, deployment status, monitoring data.

#### `--chain learn`

Document what was shipped for codebase learning — update docs to reflect the new deployed state.

```
/autoresearch_learn
Mode: update
Context: Post-ship state from {shipment_type} — {target} shipped at {timestamp}
Scope: {files changed in this ship}
```

#### `--chain security`

Post-ship security verification — audit the newly deployed code or content.

```
/autoresearch_security
Scope: {files/artifacts shipped}
Focus: Post-ship verification — confirm no regressions introduced during {shipment_type} delivery
```

#### `--chain debug`

Post-ship monitoring revealed issues — investigate immediately.

```
/autoresearch_debug
Scope: {files shipped}
Symptom: Post-ship anomaly detected — {health check failure or monitoring alert}
Context: Shipped {shipment_type} at {timestamp}, verify phase result: {verify_result}
```

#### `--chain scenario`

Post-ship edge case exploration — probe the deployed artifact under unusual conditions.

```
/autoresearch_scenario
Scenario: {shipment description} just deployed — explore edge cases and failure modes
Domain: {inferred from shipment_type}
Depth: standard
```

#### `--chain predict`

Predict post-ship impact using swarm analysis on the newly shipped artifact.

```
/autoresearch_predict
Scope: {files shipped}
Goal: Post-ship impact prediction — what issues might emerge after {shipment_type} delivery
Depth: standard
```

#### `--chain fix`

Post-ship issues need fixing — route findings directly to the fix workflow.

```
/autoresearch_fix
Target: {post-ship issue description}
Scope: {files shipped}
Context: Regression introduced during {shipment_type} delivery at {timestamp}
```

#### `--chain plan`

Plan next iteration based on ship results and post-ship observations.

```
/autoresearch_plan
Goal: Next iteration planning after {shipment_type} delivery — {checklist_score} readiness score achieved
Context: Ship log: {summary of this shipment}
```

#### `--chain reason`

Reason about post-ship observations — adversarial refinement of next steps.

```
/autoresearch_reason
Task: Post-ship review — {shipment_type} delivered, observations: {verify_result}
Domain: {inferred from shipment_type}
```

#### `--chain probe`

Interrogate post-ship requirements for next cycle — surface hidden constraints before the next iteration.

```
/autoresearch_probe
Topic: Requirements for next iteration after shipping {target}
Context: Ship results: {checklist_score}, verify: {verify_result}
```

### Multi-Chain Execution

`--chain scenario,debug,fix` executes sequentially:
1. Write `summary.md` after Phase 8 completes
2. Launch first chain target with ship results as context
3. Each stage's output feeds the next via handoff
4. All targets receive: shipment type, checklist score, dry-run result, verify status

**Empirical evidence rule:** Downstream loop results ALWAYS override upstream findings. If a debug or fix loop disproves a post-ship assumption, log: `Ship observation [X] REVISED by empirical [tool] loop — [evidence]`. Do NOT revert to pre-loop assumptions.

## Output Directory

Creates `ship/{YYMMDD}-{HHMM}-{ship-slug}/` with:
- `checklist.md` — full checklist with pass/fail status
- `ship-log.tsv` — iteration log (if preparation loop ran)
- `summary.md` — final ship report
