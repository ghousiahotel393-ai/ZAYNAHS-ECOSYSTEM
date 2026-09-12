# GEMINI — SYNC EVENT FLOW & CONFLICT POLICIES

# 69. SYNC EVENT FLOW

    Local Transaction
        ↓
    Durable Event
        ↓
    Queue
        ↓
    Peer Discovery
        ↓
    Authenticate
        ↓
    Exchange IDs/Cursors
        ↓
    Send Missing Events
        ↓
    Validate
        ↓
    Apply Atomically
        ↓
    Projection
        ↓
    ACK

---

# 70. SYNC DUPLICATION

If event already exists:

    do not apply twice

Return idempotent ACK.

---

# 71. SYNC CONFLICT

Financial/inventory data:

    NEVER use generic last-write-wins.

Preserve both valid offline operations.

---

# 72. SYNC FAILURE

Transient:

    retry with backoff

Permanent:

    FAILED / CONFLICT

Keep diagnostics.

---
