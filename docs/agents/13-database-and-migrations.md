# AGENTS — DATABASE REPOSITORIES, TRANSACTIONS & MIGRATIONS

# 81. DATABASE RULE

Database operations must be performed through:

    repositories
    database services

Do not put raw SQL inside UI widgets.

---

# 82. DATABASE TRANSACTIONS

Financial/inventory operations must use atomic DB transactions.

Never:

    modify inventory
    wait for network
    then create sale

Correct:

    complete local transaction
    create durable sync event
    synchronize later

---

# 83. MIGRATIONS

Every schema change requires:

    migration
    migration test
    MASTER_SCHEMA update
    actual database verification

---

# 84. MASTER_SCHEMA — MANDATORY SINGLE SOURCE OF TRUTH

`MASTER_SCHEMA.md` is the single source of truth for the complete database schema.

Canonical schema documentation:

    docs/database/MASTER_SCHEMA.md

If root copy exists:

    MASTER_SCHEMA.md

They must NEVER diverge. `MASTER_SCHEMA.md` must NEVER be partial, outdated, or manually guessed.

---

# 85. MIGRATION WORKFLOW

EVERY database/schema change MUST follow:

    1. Inspect current DB + migrations + MASTER_SCHEMA.md.
    2. Create/run the migration.
    3. Test the migration and affected features.
    4. Immediately update MASTER_SCHEMA.md with the COMPLETE current schema.
    5. Verify MASTER_SCHEMA.md exactly matches the actual database.
    6. Update schema version.
    7. Do not mark the task/phase complete until this verification passes.

For every new table/column/index/constraint/enum/relationship/migration:
**Migration → Test → MASTER_SCHEMA update → Actual DB verification**.

- Fresh clone/install MUST be able to recreate the complete database from migrations.
- Existing user data MUST be preserved during migrations unless an explicitly approved destructive migration is required.
- If `MASTER_SCHEMA.md` and the actual DB differ, STOP treating the phase as complete and reconcile them first.

---

# 86. SCHEMA INVARIANTS & FORBIDDEN PATTERNS

- **ZERO Branches**: Strictly forbidden to add `branch_id`, `branch_code`, `branches`, or branch references to any table.
- **Immutable Ledgers**: `inventory_movements` and `wallet_transactions` are insert-only append ledgers. Never update or delete finalized ledger entries.
- **Engine Standards**: SQLite WAL mode (`PRAGMA journal_mode = WAL;`) and Foreign Key enforcement (`PRAGMA foreign_keys = ON;`) are non-negotiable.
- **Data Types**: All timestamps must be ISO-8601 UTC strings (`TEXT`). Monetary amounts must use integer smallest currency units (cents/paisa) or high-precision deterministic representations, never floating point.
- **Stop Condition**: If `MASTER_SCHEMA.md` and the actual database differ by even a single column, constraint, or index, STOP treating the task/phase as complete and reconcile them immediately.

---
