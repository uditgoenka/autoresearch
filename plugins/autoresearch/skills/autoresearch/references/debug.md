# Debug

Use for `autoresearch:debug`.

Setup gate:
- Require a `Scope` and `Symptom`.

Flow:
1. Map the failing surface.
2. Form a falsifiable hypothesis.
3. Run one experiment.
4. Classify the outcome as confirmed, disproven, or inconclusive.
5. Log evidence with file and line references.
6. Repeat until the error surface is exhausted or bounded iterations stop the run.

Rules:
- One investigation technique at a time.
- Preserve disproven hypotheses as useful evidence.
- If `--fix` is present, hand off confirmed findings into the fix workflow.
- If `--chain` is present, hand off confirmed findings into the requested downstream workflow after the debug report is written.
