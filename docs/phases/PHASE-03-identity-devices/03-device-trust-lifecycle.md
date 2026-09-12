# PHASE 03 — DEVICE TRUST LIFECYCLE

## TRUST STATES
`PENDING` → `TRUSTED` → `REVOKED` / `BLOCKED`

## REVOCATION LAW
When a device is revoked:
- Trusted sync access is immediately cut.
- Active WebRTC and P2P sessions are terminated.
- Historical sync events originating from the device remain preserved for audit integrity.
