# PHASE 07 — RESUMABLE CHUNKED FILE TRANSFERS (GOLDEN TEST 104)

## 6-STEP FILE PROTOCOL
`START` → `META` → `CHUNK` → `ACK` → `VERIFY` → `COMPLETE`
Cut connection at 50%, reconnect, resume from offset, verify SHA-256 match.
