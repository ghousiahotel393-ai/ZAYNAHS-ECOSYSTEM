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

# 80. MASTER SCHEMA RULE

Every migration:

    create migration
    ↓
    run migration
    ↓
    test
    ↓
    update MASTER_SCHEMA
    ↓
    verify actual DB

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
