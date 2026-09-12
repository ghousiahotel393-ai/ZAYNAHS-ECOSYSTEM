# PHASE 04 — BOUNDED CHUNKED STREAMING & DEDUPLICATION

## STREAMING RULES
- Never read whole large files into memory; use bounded 64KB-256KB streams.
- Calculate SHA-256 hash on-the-fly.
- If physical file with identical SHA-256 already exists, link record without duplicating file on disk.
