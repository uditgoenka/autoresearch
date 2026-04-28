# Plan

Use for `autoresearch:plan`.

Goal:
- Convert a plain-language goal into a validated autoresearch configuration.

Flow:
1. Capture the goal.
2. Analyze the repo and likely toolchain.
3. Propose one to three scope options.
4. Propose mechanical metric options.
5. Suggest an optional guard command.
6. Validate the verify command with a dry run.
7. Return a ready-to-run `autoresearch` configuration or launch it.

Rules:
- Do not accept a subjective metric.
- Do not accept a verify command that fails dry-run validation.
