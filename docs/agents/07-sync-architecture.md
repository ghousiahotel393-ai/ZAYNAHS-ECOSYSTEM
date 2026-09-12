# AGENTS — SYNC ARCHITECTURE, EVENTS & CONFLICT HANDLING

# 37. SYNC ARCHITECTURE

Synchronization is event-driven.

Never synchronize mutable totals as the primary truth.

Correct:

    Local Transaction
        ↓
    Durable Event
        ↓
    Queue
        ↓
    Peer
        ↓
    Validate
        ↓
    Apply
        ↓
    Projection
        ↓
    ACK

---

# 38. SYNC EVENT

Each sync event should contain appropriate:

    event_id
    event_type
    aggregate_id
    aggregate_type
    device_id
    user_id
    created_at
    logical_version
    payload
    hash
    signature
    schema_version
    state

---

# 39. SYNC STATES

Use:

    LOCAL_ONLY
    QUEUED
    SENDING
    SENT
    RECEIVED
    APPLIED
    CONFLICT
    FAILED

---

# 40. ACK RULE

ACK only after:

    event has been validated
    event has been durably accepted/applied

Never ACK before durable application.

---

# 41. CURSOR RULE

Never advance sync cursor before durable application.

Correct:

    Receive
      ↓
    Validate
      ↓
    Persist
      ↓
    Apply
      ↓
    ACK
      ↓
    Cursor advance

---

# 42. DUPLICATE EVENT

If event_id already exists:

    do not apply again

Return appropriate ACK/idempotent result.

---

# 43. CONFLICT RULE

Never use generic:

    last-write-wins

for financial/inventory events.

Independent offline sales must survive.

Example:

    Initial stock = 100

    Device A offline:
        SALE -20

    Device B offline:
        SALE -30

After sync:

    stock = 50

Both sales remain.

---

# 44. CONFLICT HANDLING

If true entity conflict exists:

    preserve both states where possible
    create conflict record
    expose conflict
    require domain-specific resolution

Never silently discard data.

---

# 45. UNKNOWN EVENT

If event schema is unknown:

    preserve raw event
    quarantine if required
    mark compatibility problem

Never silently drop.

---

# 46. FAILED EVENT

Failed events remain inspectable.

Transient:

    retry with backoff

Non-retryable:

    FAILED / CONFLICT

with visible diagnostics.

---
