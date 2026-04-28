# Predict

Use for `autoresearch:predict`.

Setup gate:
- Require a `Scope` and a `Goal`.

Flow:
1. Build the analysis scope.
2. Generate the configured persona set.
3. Run the requested number of rounds.
4. Debate and converge on the strongest findings.
5. Emit a summary and handoff artifact.
6. If `--chain` is present, pass the result into the next workflow sequentially.

Outputs:
- `predict/{YYMMDD}-{HHMM}-{slug}/summary.md`
- `predict/{YYMMDD}-{HHMM}-{slug}/debate.md`
- `predict/{YYMMDD}-{HHMM}-{slug}/handoff.json`
