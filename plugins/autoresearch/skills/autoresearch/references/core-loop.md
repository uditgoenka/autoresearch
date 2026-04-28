# Core Loop

Use for `autoresearch`.

Setup gate:
- Require `Goal`, `Scope`, `Metric`, and `Verify`.
- If any are missing, gather them before modifying files or starting the loop.

Execution:
1. Run git precondition checks.
2. Establish a baseline metric value.
3. Review in-scope files, recent results, and recent git history.
4. Make one focused change.
5. Verify the metric.
6. Run the optional `Guard`.
7. Keep or discard the change.
8. Log the result and repeat.

Loop behavior:
- Unbounded by default.
- If `Iterations:` or `--iterations` is set, run exactly that many iterations.

Rules:
- One atomic change per iteration.
- Mechanical verification only.
- Use git as memory.
- Prefer `git revert` over destructive history edits.
