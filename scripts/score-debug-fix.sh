#!/bin/bash
# Scores debug-workflow.md and fix-workflow.md against a comprehensive rubric
# Output: single number (0-150) representing protocol quality

DEBUG_FILE="skills/autoresearch/references/debug-workflow.md"
FIX_FILE="skills/autoresearch/references/fix-workflow.md"

score=0

# === DEBUG SCORING (50 points max) ===

# Investigation techniques (1pt each, max 7)
for technique in "Binary Search" "Differential" "Minimal Reproduction" "Trace" "Pattern Search" "Working Backwards" "Rubber Duck"; do
  grep -qi "$technique" "$DEBUG_FILE" && ((score++))
done

# Cognitive bias guards (1pt each, max 4)
for bias in "Confirmation bias" "Anchoring" "Sunk cost" "Availability"; do
  grep -qi "$bias" "$DEBUG_FILE" && ((score++))
done

# Hypothesis format fields (1pt each, max 6)
for field in "Location" "Evidence" "Reproduction" "Impact" "Root cause" "Suggested fix"; do
  grep -qi "$field" "$DEBUG_FILE" && ((score++))
done

# Severity levels (1pt each, max 4)
for level in "CRITICAL" "HIGH" "MEDIUM" "LOW"; do
  grep -q "$level" "$DEBUG_FILE" && ((score++))
done

# Key sections (1pt each, max 8)
for section in "Gather" "Reconnaissance" "Hypothesize" "Classify" "Composite Metric" "Flags" "Output Directory" "Chaining"; do
  grep -qi "$section" "$DEBUG_FILE" && ((score++))
done

# Evidence requirements (1pt each, max 3)
for req in "file:line" "reproduction" "code evidence"; do
  grep -qi "$req" "$DEBUG_FILE" && ((score++))
done

# Anti-patterns / rules (1pt each, max 5)
for rule in "ONE experiment" "timeout" "git stash" "disproven" "diminishing returns"; do
  grep -qi "$rule" "$DEBUG_FILE" && ((score++))
done

# Hypothesis priority strategy table (2pt)
grep -q "Priority.*Strategy" "$DEBUG_FILE" && ((score+=2))

# Progress tracking format (2pt)
grep -q "debug-results.tsv" "$DEBUG_FILE" && ((score+=2))

# Example session output (2pt)
grep -q "iteration.*hypothesis.*result" "$DEBUG_FILE" && ((score+=2))

# Error surface mapping (2pt)
grep -qi "error surface" "$DEBUG_FILE" && ((score+=2))

# Technique selection guidance (1pt)
grep -qi "Best For" "$DEBUG_FILE" && ((score++))

# === FIX SCORING (50 points max) ===

# Auto-detect categories (1pt each, max 7)
for cat in "test" "type" "lint" "build" "bug" "ci" "warning"; do
  grep -qi "\"$cat\"" "$FIX_FILE" 2>/dev/null || grep -qi "type.*$cat" "$FIX_FILE" && ((score++))
done

# Priority ordering (2pt)
grep -qi "Priority.*Category" "$FIX_FILE" && ((score+=2))

# Fix strategies by category (1pt each, max 6)
for strat in "Build failure" "Type error" "Test failure" "Lint error" "Bug" "Warning"; do
  grep -qi "$strat" "$FIX_FILE" && ((score++))
done

# Decision matrix rows (1pt each, max 5)
for decision in "KEEP" "DISCARD" "REWORK" "RECOVER" "delta"; do
  grep -qi "$decision" "$FIX_FILE" && ((score++))
done

# Guard integration (2pt)
grep -qi "guard" "$FIX_FILE" && ((score+=2))

# Auto-stop at zero (2pt)
grep -qi "zero.*error\|current_errors == 0" "$FIX_FILE" && ((score+=2))

# Flags (1pt each, max 6)
for flag in "target" "guard" "scope" "category" "skip-lint" "from-debug"; do
  grep -qi "\-\-$flag" "$FIX_FILE" && ((score++))
done

# Anti-pattern rules (1pt each, max 6)
for rule in "ts-ignore" "eslint-disable" "never.*any\|any.*never" "never.*delete.*test\|delete.*test.*never" "ONE fix" "suppress"; do
  grep -qiE "$rule" "$FIX_FILE" && ((score++))
done

# Chaining patterns (1pt each, max 3)
chains=$(grep -c "autoresearch:" "$FIX_FILE" 2>/dev/null)
[ "$chains" -ge 3 ] && ((score+=3)) || ((score+=chains))

# Progress tracking (2pt)
grep -q "fix-results.tsv" "$FIX_FILE" && ((score+=2))

# Composite metric formula (2pt)
grep -qi "fix_score" "$FIX_FILE" && ((score+=2))

# Auto-detection reference table (2pt)
grep -qi "Signal.*Detected" "$FIX_FILE" && ((score+=2))

# Cascading impact priority (1pt)
grep -qi "cascading" "$FIX_FILE" && ((score++))

# Rework strategy (1pt)
grep -qi "rework" "$FIX_FILE" && ((score++))

# === DEBUG ADDITIONS (+25 points) ===

# Common bug patterns by language table (3pt)
# Checks for a language-keyed table of known bug patterns
grep -qiE "(javascript|typescript|python|go|rust|java).*(null|undefined|race|overflow|inject)" "$DEBUG_FILE" && ((score+=3))

# Domain-specific debugging sections (3pt)
# Checks for dedicated domain sections: frontend, backend, database, etc.
grep -qiE "(frontend|backend|database|api|network|async).*(debug|issue|fail)" "$DEBUG_FILE" && ((score+=3))

# Root cause vs symptom guidance (2pt)
grep -qiE "root cause.*(not|vs|versus|symptom)|symptom.*(not|vs|versus|root cause)" "$DEBUG_FILE" && ((score+=2))

# Regression prevention section (2pt)
grep -qi "regression" "$DEBUG_FILE" && ((score+=2))

# Multi-file tracing guidance (2pt)
grep -qiE "multi.?file|cross.?file|trace.*across|across.*file" "$DEBUG_FILE" && ((score+=2))

# Environment-specific debugging (2pt)
grep -qiE "staging|production|local.*(vs|versus|vs\.).*ci|ci.*(vs|versus|vs\.).*local" "$DEBUG_FILE" && ((score+=2))

# Performance bug investigation (2pt)
grep -qiE "performance.*(bug|issue|debug)|profil(e|ing)|slow.*(query|request|render)" "$DEBUG_FILE" && ((score+=2))

# Flaky/intermittent bug handling (2pt)
grep -qiE "flaky|intermittent|non.?deterministic|heisenbug" "$DEBUG_FILE" && ((score+=2))

# Third-party dependency debugging (2pt)
grep -qiE "third.?party|vendor|dependency.*(debug|issue)|upstream" "$DEBUG_FILE" && ((score+=2))

# The 5 Whys technique (2pt)
grep -qiE "5 why|five why|ask.*why.*5|why.*why.*why" "$DEBUG_FILE" && ((score+=2))

# Debug anti-patterns section (3pt)
# "Anti-patterns" heading OR a dedicated section listing debug anti-patterns
grep -qiE "debug.*anti.?pattern|anti.?pattern.*debug" "$DEBUG_FILE" && ((score+=3))

# === FIX ADDITIONS (+25 points) ===

# Language-specific fix strategies (3pt)
grep -qiE "(typescript|python|go|rust|java).*(fix|strategy|approach|pattern)" "$FIX_FILE" && ((score+=3))

# Dependency fix patterns (2pt)
grep -qiE "dependency.*(fix|update|pin|lock)|package.*(outdated|conflict|mismatch)" "$FIX_FILE" && ((score+=2))

# CI/CD fix patterns (2pt)
grep -qiE "ci.*(fix|pattern|workflow|action)|github.action|pipeline.*(fail|fix)" "$FIX_FILE" && ((score+=2))

# Fix anti-patterns section (3pt)
grep -qiE "fix.*anti.?pattern|anti.?pattern.*fix" "$FIX_FILE" && ((score+=3))

# Fix verification depth levels (2pt)
# unit → integration → e2e or similar multi-level verification
grep -qiE "unit.*(integrat|e2e)|integrat.*(e2e|unit)|depth.*(verif|level)|level.*(verif|depth)" "$FIX_FILE" && ((score+=2))

# Compound fix detection (2pt)
grep -qiE "compound|multiple.*(fix|error|change).*single|related.*(fix|error)" "$FIX_FILE" && ((score+=2))

# Fix impact assessment (2pt)
grep -qiE "impact.*(assess|analys|scope)|assess.*(impact|blast.?radius)|blast.?radius" "$FIX_FILE" && ((score+=2))

# Rollback protocol (2pt)
grep -qiE "rollback|roll.?back|revert.*protocol|undo.*fix" "$FIX_FILE" && ((score+=2))

# Fix history pattern learning (2pt)
grep -qiE "fix.*histor|pattern.*learn|recurring|repeat.*fix|fix.*recur" "$FIX_FILE" && ((score+=2))

# Parallel fix detection (2pt)
grep -qiE "parallel.*(fix|issue)|concurrent.*(fix|change)|simultaneous" "$FIX_FILE" && ((score+=2))

# Escalation path when fixes fail (3pt)
grep -qiE "escalat|when.*fix.*fail|fix.*fail.*escalat|skip.*escalat|move.*on.*escalat" "$FIX_FILE" && ((score+=3))

echo "SCORE: $score"
