# Release Process

## Versioning Scheme

| Type | Pattern | When to use | Example |
|------|---------|-------------|---------|
| **Patch** | `vX.Y.Z` | Bugfixes, typos, small updates, dependency bumps | `v2.2.3` |
| **Minor** | `v2.X.0` | New features, new commands, significant changes | `v2.2.0` |
| **Major** | `vX.0.0` | Breaking changes, full rewrites | `v3.0.0` |

## Quick Reference

```bash
# Stabilization release
./scripts/release.sh 2.2.3 --title "Autoresearch v2.2.3 stabilization"
```

## Release Gates

The preparation script stops after the PR is opened. It does not merge, tag, or publish.

| Gate | Verified by |
|------|-------------|
| Identity and workspace | clean tree, `master`, `gh`, `uditgoenka` Git author, `uditgoenka` GitHub login |
| Transform cleanliness | `bash scripts/transform.sh`, then `git diff --exit-code` and `git status --porcelain` |
| Version alignment | `claude-plugin/.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, `.claude/skills/autoresearch/SKILL.md`, `README.md`, `guide/README.md`, and the generated `SKILL.md` mirrors |
| Release suites | `bash tests/test-hooks.sh`, `bash tests/test-orchestrator.sh`, `bash tests/test-regression.sh`, `bash tests/test-maintenance.sh` |
| Clean-install smoke | disposable installs for Claude, OpenCode, and Codex run bundled `scripts/orchestrate.sh classify`, `scripts/score-regression.sh verdict`, and `scripts/score-regression.sh rubric` from outside the source checkout |
| Publication boundary | PR creation only; merge, tag creation, and GitHub release creation are separate explicit owner actions |

## Pre-Release Checklist

Before running the script, verify:

- [ ] `git config user.name` is `uditgoenka`
- [ ] `gh api user --jq .login` is `uditgoenka`
- [ ] The working tree is clean and on `master`
- [ ] `scripts/orchestrate.sh` and `scripts/score-regression.sh` are executable in every installed bundle
- [ ] `bash tests/test-hooks.sh`
- [ ] `bash tests/test-orchestrator.sh`
- [ ] `bash tests/test-regression.sh`
- [ ] `bash tests/test-maintenance.sh`

## Release-Readiness Matrix

The GitHub Actions matrix runs on Ubuntu, macOS, and Windows/Git Bash. Every
job is required; do not mark a release candidate ready while any job is not
green at the exact head.

## Release Flow

The release script prepares the branch, verifies the release gates, commits, pushes, and opens the PR. It stops there.

## Distribution Sync

The `claude-plugin/` directory is the **distribution package** — what Claude Code downloads when users install the plugin. The `.claude/` versions are the development source of truth.

Before every release, `scripts/transform.sh` regenerates `claude-plugin/` and the generated mirrors from `.claude/`.

## Merge and Recovery

Merge, tag creation, and GitHub release creation are separate explicit owner actions after PR review.

If an exact-release smoke check fails after tagging, leave the existing tag immutable and cut a new patch version instead. Do not move `v2.2.3`.

## Troubleshooting

| Issue | Fix |
|-------|-----|
| "Working tree is dirty" | Commit or stash changes first |
| "Must be on master branch" | `git checkout master` |
| "gh CLI not found" | Install from https://cli.github.com |
| PR merge conflicts | Resolve on the PR, then re-run merge step manually |
| Forgot to update docs | Edit on the PR branch, push, then merge |
| "Tag already exists" | Choose a different version number |
| ENAMETOOLONG on install | Ensure `marketplace.json` has `"source": "./claude-plugin"` (not `"./"`) |
