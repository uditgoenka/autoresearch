# Fix

Use for `autoresearch:fix`.

Setup gate:
- Require a `Target` verify command and a `Scope`.
- If absent, auto-detect the main failures and then ask for confirmation.

Flow:
1. Detect the highest-value failure.
2. Apply one fix.
3. Run the target verify command.
4. Run the optional guard.
5. Keep the fix only if verification improves and no regression appears.
6. Repeat until the error count reaches zero or iterations are exhausted.

Rules:
- One fix per iteration.
- Never suppress errors just to go green.
- Revert failed fixes cleanly.
