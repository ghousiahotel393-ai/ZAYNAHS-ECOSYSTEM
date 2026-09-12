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

# 84. MASTER_SCHEMA

Canonical schema documentation:

    docs/database/MASTER_SCHEMA.md

If root copy exists:

    MASTER_SCHEMA.md

they must not diverge.

---

# 85. MIGRATION WORKFLOW

Mandatory:

    1. Inspect current schema
    2. Create migration
    3. Run migration
    4. Test migration
    5. Update MASTER_SCHEMA
    6. Verify actual DB
    7. Test fresh install
    8. Test upgrade
    9. Document

---
