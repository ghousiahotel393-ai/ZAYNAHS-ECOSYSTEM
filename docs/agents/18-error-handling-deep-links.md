# AGENTS — ERROR HANDLING, DEEP LINKS & PLATFORM CODE

# 106. NO FALSE SUCCESS

Never display:

    Synced

if:

    queued
    failed
    conflicted

Never display:

    Backup complete

if verification failed.

Never display:

    Recording

if recorder is not actually recording.

---

# 107. RETRY

Retry only transient failures.

Retry:

    temporary network loss
    temporary peer unavailable
    transient storage issue where recoverable

Do NOT blindly retry:

    permission denial
    invalid schema
    corrupt data
    invalid transaction

---

# 108. TIMEOUT

Network operations must have bounded:

    connect
    send
    receive
    transfer

timeouts.

No infinite waits.

---

# 109. CANCELLATION

Long-running operations should support cancellation:

    backup
    restore preparation
    export
    report
    file transfer
    sync operation where safe
    media processing

---

# 110. DEEP LINKS

Required routes:

    /product/:productId
    /product/:productId/ledger
    /sale/:saleId
    /sale/:saleId/payment
    /return/:returnId
    /customer/:customerId
    /supplier/:supplierId
    /payment/:paymentId
    /wallet/:walletId
    /inventory/:movementId
    /user/:userId
    /device/:deviceId
    /recording/:recordingId
    /backup/:backupId

---

# 111. DEEP LINK SECURITY

Every deep link must still perform:

    authentication
    permission
    entity existence

Never bypass access control because a URL is known.

---

# 112. PLATFORM

Initial:

    Android
    iOS
    Windows
    Web

Architecture should remain ready for:

    macOS
    Linux

---

# 113. PLATFORM ADAPTERS

Never scatter platform-specific code throughout domain logic.

Use adapters for:

    camera
    location
    screen capture
    printer
    storage
    background service
    notifications

---

# 114. NATIVE CAPABILITIES

Before implementing native functionality:

    inspect platform restrictions
    inspect permission requirements
    inspect background limitations
    inspect lifecycle behavior

Never assume Android/iOS/Desktop behave identically.

---

# 115. SECURITY CREDENTIALS

Production credentials must come from:

    environment
    secure secret storage
    platform secure storage
    approved server-side secret management

Never hard-code credentials.

---

# 116. ENVIRONMENT

Maintain:

    .env.example

with names only.

Never commit:

    production secrets
    private keys
    service credentials

---

# 117. CLOUD

Cloud infrastructure may support:

    signaling
    rendezvous
    optional storage
    optional backup
    authenticated metadata

Cloud should not replace local-first functionality unnecessarily.

---

# 118. SUPABASE

Supabase may provide:

    PostgreSQL
    Storage
    Auth
    Realtime

Use least privilege.

Never expose privileged service credentials to client.

---

# 119. CLOUDFLARE

Cloudflare Workers/Durable Objects may provide:

    signaling
    WebSocket coordination
    rendezvous

Do not use signaling for:

    large files
    CCTV recordings
    large image binaries

---
