# Core Principles — From Karpathy's Autoresearch

7 universal principles extracted from autoresearch, applicable to ANY autonomous work.

## 1. Constraint = Enabler

Autonomy succeeds through intentional constraint, not despite it.

| Autoresearch | Generalized |
|--------------|-------------|
| 630-line codebase | Bounded scope that fits agent context |
| 5-minute time budget | Fixed iteration cost |
| One metric (val_bpb) | Single mechanical success criterion |

**Why:** Constraints enable agent confidence (full context understood), verification simplicity (no ambiguity), iteration velocity (low cost = rapid feedback loops).

**Apply:** Before starting, define: what files are in-scope? What's the ONE metric? What's the time budget per iteration?

## 2. Separate Strategy from Tactics

Humans set direction. Agents execute iterations.

| Strategic (Human) | Tactical (Agent) |
|-------------------|------------------|
| "Improve page load speed" | "Lazy-load images, code-split routes" |
| "Increase test coverage" | "Add tests for uncovered edge cases" |
| "Refactor auth module" | "Extract middleware, simplify handlers" |

**Why:** Humans understand WHY. Agents handle HOW. Mixing these roles wastes both human creativity and agent iteration speed.

**Apply:** Get clear direction from user (or program.md). Then iterate autonomously on implementation.

## 3. Metrics Must Be Mechanical

If you can't verify with a command, you can't iterate autonomously.

- Tests pass/fail (exit code 0)
- Benchmark time in milliseconds
- Coverage percentage
- Lighthouse score
- File size in bytes
- Lines of code count

**Anti-pattern:** "Looks better", "probably improved", "seems cleaner" → these KILL autonomous loops because there's no decision function.

**Apply:** Define the `grep` command (or equivalent) that extracts your metric BEFORE starting.

### ML Accuracy Metric — Complete Configuration

```
/autoresearch
Goal: Improve model accuracy from 85% to 95%
Scope: model.py, config.yaml, data/preprocessing.py
Metric: validation accuracy (higher is better)
Verify: python train.py --eval-only 2>&1 | grep 'val_accuracy' | awk '{print $2}'
Guard: python -c "import torch; m=torch.load('model.pt'); assert m is not None"
Iterations: 20
```

**Python metric extraction patterns for ML:**

```bash
# Classification accuracy
python train.py --eval 2>&1 | grep 'accuracy' | awk '{print $NF}'

# Validation loss (lower is better)
python train.py 2>&1 | grep 'val_loss' | tail -1 | awk '{print $NF}'

# F1 score
python evaluate.py --metric f1 2>&1 | grep 'f1_score' | awk '{print $2}'

# BLEU score (NLP)
python evaluate.py 2>&1 | grep 'BLEU' | grep -oP '[\d.]+'

# Custom metric extraction script
python -c "
import json
with open('eval_results.json') as f:
    results = json.load(f)
print(results['accuracy'])
"
```

**Error handling for ML verification:**

```bash
# Wrap verify command with timeout and error handling
timeout 300 python train.py --eval-only 2>&1 | grep 'val_accuracy' | awk '{print $2}' || echo "0.0"
# → Returns 0.0 on timeout/crash instead of hanging the loop

# Verify the metric is a valid number
METRIC=$(python train.py --eval 2>&1 | grep 'accuracy' | awk '{print $NF}')
echo "$METRIC" | grep -qP '^\d+\.?\d*$' || { echo "WARN: metric '$METRIC' is not a number"; METRIC="0.0"; }
```

**Integrating custom metrics programmatically:**

```python
# verify_metric.py — reusable verification script for autoresearch
import subprocess, sys, json

def extract_metric(command: str, pattern: str) -> float:
    """Run command, extract metric using pattern, return float."""
    try:
        result = subprocess.run(command, shell=True, capture_output=True, text=True, timeout=300)
        for line in result.stdout.split('\n'):
            if pattern in line:
                # Extract the last number on the line
                numbers = [float(x) for x in line.split() if x.replace('.','',1).isdigit()]
                if numbers:
                    return numbers[-1]
        return 0.0  # Pattern not found
    except subprocess.TimeoutExpired:
        return 0.0  # Timeout — treat as crash
    except Exception as e:
        print(f"WARN: metric extraction failed: {e}", file=sys.stderr)
        return 0.0

if __name__ == "__main__":
    # Usage: python verify_metric.py "python train.py --eval" "accuracy"
    metric = extract_metric(sys.argv[1], sys.argv[2])
    print(metric)
```

```
# Use in autoresearch:
/autoresearch
Verify: python verify_metric.py "python train.py --eval" "accuracy"
```

## 4. Verification Must Be Fast

If verification takes longer than the work itself, incentives misalign.

| Fast (enables iteration) | Slow (kills iteration) |
|-------------------------|----------------------|
| Unit tests (seconds) | Full E2E suite (minutes) |
| Type check (seconds) | Manual QA (hours) |
| Lint check (instant) | Code review (async) |

**Apply:** Use the FASTEST verification that still catches real problems. Save slow verification for after the loop.

## 5. Iteration Cost Shapes Behavior

- Cheap iteration → bold exploration, many experiments
- Expensive iteration → conservative, few experiments

Autoresearch: 5-minute cost → 100 experiments/night.
Software: 10-second test → 360 experiments/hour.

**Apply:** Minimize iteration cost. Use fast tests, incremental builds, targeted verification. Every minute saved = more experiments run.

## 6. Git as Memory and Audit Trail

Every successful change is committed. This enables:
- **Causality tracking** — which change drove improvement?
- **Stacking wins** — each commit builds on prior successes
- **Pattern learning** — agent sees what worked in THIS codebase
- **Human review** — researcher inspects agent's decision sequence

**Apply:** Commit before verify. Revert on failure. Agent reads its own git history to inform next experiment.

**Configuration:**
```
/autoresearch
Git-Memory: enabled     # default — always on, reads git history every iteration
Memory-Depth: 20        # number of past commits to review (default: 20)
```

**Key commands the agent runs every iteration:**
```bash
git log --oneline -20           # see experiment sequence (kept vs reverted)
git diff HEAD~1                 # inspect last kept change to understand WHY it worked
git show <hash> --stat          # deep-dive specific commit to see which files drove improvement
```

**Without Git Memory (agent has no history — repeats failures):**
```
Iteration 1: Try increasing batch size → OOM crash → reverted
Iteration 5: Try increasing batch size → OOM crash → REPEATED!
Iteration 9: Try increasing batch size → OOM crash → WASTED!
# No learning — 3 iterations lost to the same failed idea
```

**With Git Memory (agent reads git log — learns and adapts):**
```
Iteration 1: Try increasing batch size → OOM crash → git revert (preserved in history)
Iteration 2: git log shows "experiment: increase batch size — REVERTED"
             → Agent tries DIFFERENT approach: reduce model layers → metric improves → KEPT
Iteration 3: git diff HEAD~1 shows which layers were removed
             → Agent tries removing another layer → metric improves → KEPT
# Agent learns from history, exploits successes, never repeats failures
```

## 7. Honest Limitations

State what the system can and cannot do. Don't oversell.

Autoresearch CANNOT: change tokenizer, replace human direction, guarantee meaningful improvements.

**Apply:** At setup, explicitly state constraints. If agent hits a wall it can't solve (missing permissions, external dependency, needs human judgment), say so clearly instead of guessing.

## The Meta-Principle

> Autonomy scales when you constrain scope, clarify success, mechanize verification, and let agents optimize tactics while humans optimize strategy.

This isn't "removing humans." It's reassigning human effort from execution to direction. Humans become MORE valuable by focusing on irreducibly creative/strategic work.
