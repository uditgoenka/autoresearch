---
name: autoresearch:ship
description: "Ship anything through 8 phases: checklist, dry-run, deploy, verify"
argument-hint: "[Target: <what>] [--type <type>] [--dry-run] [--auto] [--force] [--rollback] [--checklist-only] [--monitor N]"
---

EXECUTE IMMEDIATELY.

## Parse Arguments

Extract from $ARGUMENTS:
- `Target:` or `--target` — what to ship (path, PR, artifact, deployment)
- `--type <type>` — override auto-detection: code-pr, code-release, deployment, content, docs, package, config
- `--dry-run` — validate everything but don't ship
- `--auto` — auto-approve if no errors found
- `--force` — skip non-critical items (blockers still enforced)
- `--rollback` — undo last ship action
- `--monitor N` — post-ship monitoring for N minutes
- `--checklist-only` — only generate checklist, don't execute
- `--chain`, `--<subcommand>`

Remaining text = description of what to ship.

## Setup (if Target or Type unclear)

1. Auto-detect ship type from context:
   - Has uncommitted changes or PR → code-pr
   - Has version bump / changelog → code-release
   - Has Dockerfile / deploy config → deployment
   - Has markdown / content files → content
   - Has package.json version change → package
2. If still unclear → request_user_input (single batch):
   Q1 (What): "What are you shipping?" — code PR, release, deployment, content, docs, package
   Q2 (Target): "Specific target?" — current branch, specific PR, specific path
   Q3 (Mode): "How to ship?" — full workflow, dry-run only, checklist only
If all clear → skip.

## Phase 1: Identify

- Determine ship type (auto-detected or --type override)
- Identify target artifact(s)
- Map to domain-specific checklist

## Phase 2: Inventory

Gather everything that will be shipped:
- Files changed (git diff)
- Dependencies affected
- Config changes
- Migration files
- Breaking changes

## Phase 3: Checklist

Generate domain-specific checklist:

**Code PR:** tests pass, types check, lint clean, no secrets, PR description, reviewers assigned
**Release:** version bumped, changelog updated, migration tested, rollback plan
**Deployment:** env vars set, health checks configured, rollback ready, monitoring active
**Content:** links valid, images optimized, SEO metadata, spell check
**Package:** version bumped, README updated, breaking changes documented, CI green

If `--checklist-only` → output checklist and stop.

## Phase 4: Prepare

Execute pre-ship tasks:
- Run test suite
- Run type checker
- Run linter
- Check for secrets in diff
- Validate configs
- Flag blockers (must-fix) vs warnings (can-ship-with)

If blockers found → STOP, report blockers, ask user to fix.

## Phase 5: Dry-Run

If `--dry-run` or always before actual ship:
- Simulate the ship action without executing
- Report what WOULD happen
- If `--dry-run` → stop here

## Phase 6: Ship

**REQUIRES EXPLICIT USER APPROVAL** (unless --auto with zero errors).

Execute the ship action:
- Code PR: create/update PR, request reviewers
- Release: tag, build, publish
- Deployment: deploy to target environment
- Content: publish to CMS/platform

## Phase 7: Verify

Post-ship verification:
- Confirm artifact is live/accessible
- Run smoke tests if available
- Check monitoring for errors
- If `--monitor N` → watch for N minutes

## Phase 8: Log

Create output directory: `autoresearch/ship-{YYMMDD}-{HHMM}/`
Write:
- `checklist.md` — completed checklist with pass/fail per item
- `summary.md` — what was shipped, verification results
- `ship-log.tsv` — phase-by-phase log

## Rollback

If `--rollback`:
- Identify last ship action from most recent ship log
- Reverse it (revert PR, unpublish, rollback deployment)
- Verify rollback succeeded

## Chain Handoff

Write handoff.json: version "2.1.0", source "ship", timestamp, status (COMPLETE|DRY_RUN|ROLLBACK|ERROR), findings = blockers/warnings found during prep.
Invoke next target in --chain order.
