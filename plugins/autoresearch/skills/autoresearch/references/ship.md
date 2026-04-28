# Ship

Use for `autoresearch:ship`.

Setup gate:
- Require a target and type unless they can be inferred with high confidence.

Flow:
1. Identify what is being shipped.
2. Inventory readiness gaps.
3. Build a mechanically verifiable checklist.
4. Prepare until blockers are cleared.
5. Dry-run if requested.
6. Ship.
7. Verify the ship landed.
8. Log the result.

Outputs:
- `ship/{YYMMDD}-{HHMM}-{slug}/checklist.md`
- `ship/{YYMMDD}-{HHMM}-{slug}/summary.md`
- `ship/{YYMMDD}-{HHMM}-{slug}/ship-log.tsv`

Rules:
- `--checklist-only` stops after readiness evaluation.
- `--rollback` undoes the most recent reversible shipment.
