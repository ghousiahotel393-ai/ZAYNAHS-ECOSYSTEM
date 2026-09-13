# PHASE 12 — GOLDEN BACKUP TEST (RULE 102) & DISASTER RECOVERY

## TEST CRITERIA
1. **Archive Serialization**: Create verified `.zynb` backup archive with binary magic `ZYNB`, format version 1, GZIP compressed JSON tables, per-entry checksums, and a trailing 32-byte cryptographic SHA-256 seal.
2. **1-Byte Corruption Rejection**: Intentionally corrupt 1 byte in the archive payload. Attempting restore MUST fail safely with `ValidationException` during cryptographic verification.
3. **Zero DB Mutation**: The active database MUST remain 100% untouched by any corrupted restore attempt.
4. **Mandatory Pre-Restore Snapshot (Rule 60, 81)**: Restoring from a valid archive MUST automatically generate a `PRE_RESTORE` backup record in `backup_records` and file on disk BEFORE any tables are modified.
5. **Atomic Table Replacement (Rule 90)**: Active data is replaced cleanly using reverse-topological deletion and parent-first insertion with `PRAGMA defer_foreign_keys = ON;`.
6. **Projection Rebuilder (Rule 91)**: Re-derive all ledger projections (stock balance from `inventory_movements`, wallet balances from `wallet_transactions`, customer dues from `sales`, supplier payables from `purchase_orders`).
7. **Structured Audit Log**: Record `DATABASE_RESTORE_COMPLETED` audit event with restore details.

## IMPLEMENTATION & TEST RESULTS
- **Package**: `packages/backup`
- **Schema Migration**: Schema v8 (`backup_records` table, `PRAGMA user_version = 8;`)
- **Master Schema Parity**: 100% byte-for-byte parity between `docs/database/MASTER_SCHEMA.md` and `MASTER_SCHEMA.md` (28 tables)
- **Zero Branch Invariant**: 0 occurrences of `branch_id` across all packages
- **Unit & Golden Test**: `tests/unit/backup_test.dart` (Passed 2/2 tests)
- **Master Suite**: `tests/run_all.dart` (Passed 71/71 tests)
- **Verification Script**: `scripts/verify_phase_12.sh` (Passed 100% green)

## STATUS: ✅ COMPLETED & FULLY VERIFIED
