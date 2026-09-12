# GEMINI — DATABASE CORE TABLES & MASTER_SCHEMA

# 78. DATABASE CORE TABLES

Maintain architecture around:

    ecosystems
    users
    roles
    permissions
    role_permissions
    user_permissions

    devices
    device_trusts
    pairing_sessions

    products
    product_variants
    product_images
    product_image_refs
    categories
    brands
    units

    inventory_balances
    inventory_movements
    stock_counts

    sales
    sale_items
    returns
    return_items
    replacements

    purchases
    purchase_items
    suppliers
    supplier_ledger

    customers
    customer_ledger

    wallets
    wallet_transactions
    payment_allocations
    expenses
    expense_categories

    barcodes
    print_jobs
    print_templates

    conversations
    conversation_members
    messages
    message_attachments
    calls
    call_participants
    locations

    cameras
    camera_hosts
    recordings
    recording_events

    files
    file_transfers

    sync_events
    sync_cursors
    sync_conflicts

    audit_events
    app_settings

    backup_jobs
    backup_manifests

---

# 79. NO BRANCH TABLE

There must be NO:

    branches

unless architecture is explicitly changed by project owner.

Default rule:

    never add it.

---

# 80. MASTER SCHEMA — MANDATORY SINGLE SOURCE OF TRUTH

`MASTER_SCHEMA.md` is the single source of truth for the complete database schema.

EVERY database/schema change MUST follow:

    1. Inspect current DB + migrations + MASTER_SCHEMA.md.
    2. Create/run the migration.
    3. Test the migration and affected features.
    4. Immediately update MASTER_SCHEMA.md with the COMPLETE current schema.
    5. Verify MASTER_SCHEMA.md exactly matches the actual database.
    6. Update schema version.
    7. Do not mark the task/phase complete until this verification passes.

`MASTER_SCHEMA.md` must NEVER be partial, outdated, or manually guessed.

For every new table/column/index/constraint/enum/relationship/migration:
**Migration → Test → MASTER_SCHEMA update → Actual DB verification**.

- Fresh clone/install MUST be able to recreate the complete database from migrations.
- Existing user data MUST be preserved during migrations unless an explicitly approved destructive migration is required.
- If `MASTER_SCHEMA.md` and the actual DB differ, STOP treating the phase as complete and reconcile them first.

---

# 81. MASTER_SCHEMA CONTENT

Document:

    schema version
    tables
    columns
    types
    indexes
    foreign keys
    unique constraints
    check constraints
    enums
    event types
    relationships
    migration order

---

# 82. LOCAL STORAGE

Use:

    app_data/database
    media/product
    media/chat
    media/documents
    media/thumbnails
    cctv/recordings
    cctv/snapshots
    cctv/exports
    backups/daily
    backups/manual
    backups/pre_restore
    cache
    logs
    temp

---

# 83. STORAGE ABSTRACTION

Modules must call:

    FileStorageService

Never directly construct platform-specific paths.

---
