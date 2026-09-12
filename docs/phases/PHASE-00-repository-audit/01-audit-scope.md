# PHASE 00 — AUDIT SCOPE & METHODOLOGY

## OBJECTIVE
Perform a comprehensive static analysis and architecture audit of the repository before making any code modifications.

## INSPECTION CHECKLIST
- [ ] Inspect root directory structure and configuration files.
- [ ] Check `pubspec.yaml` dependencies and target platforms.
- [ ] Inspect existing Flutter/Dart source packages under `apps/` and `packages/`.
- [ ] Inspect database schema, existing migration files, and models.
- [ ] Check for any existing branch concepts (`branch_id`, `branch_manager`, branch tables). Flag for removal.
- [ ] Verify no hardcoded credentials or API secrets exist in the repository.

## STRICT OPERATING LAW
- **Zero code changes** during Phase 00.
- Report all findings in the Gap Analysis document before beginning Phase 01.
