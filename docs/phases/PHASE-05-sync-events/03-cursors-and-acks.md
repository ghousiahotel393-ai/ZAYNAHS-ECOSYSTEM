# PHASE 05 — CURSORS, ACKS & IDEMPOTENCY

## SACRED SYNC LAWS
1. ACK only AFTER event is durably applied to peer database.
2. NEVER advance sync cursor before durable application.
3. Duplicate events (matching event_id) are acknowledged idempotently without re-applying.
