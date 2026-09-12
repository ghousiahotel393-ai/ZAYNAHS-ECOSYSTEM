# PHASE 05 — DURABLE OUTBOX & EVENT QUEUE

## EVENT LIFECYCLE
`LOCAL_ONLY` → `QUEUED` → `SENDING` → `SENT` → `RECEIVED` → `APPLIED` → `ACK`
Events persist durably in SQLite before network transmission.
