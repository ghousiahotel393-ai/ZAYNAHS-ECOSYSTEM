# AGENTS — PERFORMANCE, PAGINATION & MEMORY BOUNDS

# 99. PERFORMANCE

Always consider:

    pagination
    lazy loading
    thumbnails
    caching
    incremental sync
    bounded queues
    background workers
    hardware acceleration
    resource cleanup

---

# 100. MEMORY

Never load unlimited:

    products
    messages
    ledger rows
    images
    videos
    files
    recordings

into memory.

---

# 101. DATABASE QUERY PERFORMANCE

Avoid:

    SELECT everything
    loading full history unnecessarily
    repeated N+1 queries
    unindexed high-volume queries

Use:

    pagination
    cursor pagination
    indexes
    aggregation
    targeted queries

---

# 102. NETWORK PERFORMANCE

Avoid unnecessary:

    polling
    reconnect loops
    duplicate transfers
    repeated metadata transfer

Prefer:

    events
    subscriptions
    cursors
    incremental sync

---

# 103. BATTERY

Mobile must avoid unnecessary:

    GPS
    camera
    microphone
    WebRTC
    network polling

Release resources when inactive.

---

# 104. STORAGE PRESSURE

Monitor:

    total
    used
    free

and:

    CCTV
    backups
    media
    cache
    temp

Never automatically delete:

    protected recordings
    unuploaded sync data
    active backup
    in-progress transfers

---

# 105. ERROR HANDLING

Every failure must have:

    safe state
    user-readable message
    technical diagnostic where appropriate
    retry path where appropriate

Do not swallow errors.

---
