# AGENTS — BACKUP ARCHIVE (.ZYNB), RESTORE & REBUILD PROJECTIONS

# 86. BACKUP

Backup must be:

    local-first
    verifiable
    integrity-protected
    encrypted where required
    recoverable

---

# 87. BACKUP FORMAT

Recommended:

    .zynb

Structure:

    manifest.json
    metadata/
    database/
    ledger/
    media/
    cctv/
    settings/
    checksums/

---

# 88. BACKUP SAFE WRITE

Use:

    temp file
      ↓
    flush
      ↓
    verify
      ↓
    checksum
      ↓
    atomic rename
      ↓
    success

---

# 89. RESTORE

Restore requires:

    authentication
    permission
    integrity check
    schema check
    pre-restore backup
    scope confirmation
    restore
    projection rebuild
    verification
    audit

---

# 90. NEVER SILENTLY MERGE BACKUP

Restore must clearly state scope.

Supported concepts:

    replace local
    selected records
    inspect
    create new workspace

Do not silently merge potentially conflicting data.

---

# 91. PROJECTION REBUILD

After restore/reconciliation rebuild:

    inventory balances
    wallet projections
    customer balances
    supplier balances
    report indexes
    search indexes where applicable

---
