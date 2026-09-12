# GEMINI — BACKUP ARCHIVE (.ZYNB) & RESTORE PROCESS

# 73. BACKUP STRUCTURE

Recommended:

    .zynb

Containing:

    backup.zynb
    manifest.json
    metadata/
    database/
    ledger/
    media/
    cctv/
    settings/
    checksums/

---

# 74. BACKUP TYPES

Support:

    daily
    manual
    pre_restore

---

# 75. CCTV BACKUP POLICY

Do not automatically place every CCTV binary into every ecosystem backup.

Support modes:

    metadata-only
    selected media
    full media

---

# 76. BACKUP PROCESS

    flush safe writes
    ↓
    create manifest
    ↓
    database export
    ↓
    metadata
    ↓
    checksums
    ↓
    compress
    ↓
    encrypt
    ↓
    local save
    ↓
    verify
    ↓
    optional cloud upload
    ↓
    verify cloud object

---

# 77. RESTORE PROCESS

    authenticate
    ↓
    authorize
    ↓
    verify archive
    ↓
    verify schema
    ↓
    pre-restore backup
    ↓
    show scope
    ↓
    stop conflicting writes
    ↓
    restore
    ↓
    rebuild projections
    ↓
    verify
    ↓
    audit
    ↓
    resume

---
