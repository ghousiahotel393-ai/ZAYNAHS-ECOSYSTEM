# PHASE 04 — SAFE DIRECTORY TAXONOMY

## DIRECTORY STRUCTURE
`app_data/database`, `media/products`, `media/chat`, `media/documents`, `cctv/recordings`, `cctv/snapshots`, `backups/daily`, `backups/manual`, `cache`, `temp`.

## PATH SECURITY
- Sanitize all input file names; prevent `../` traversal attacks.
- Atomic file writing: `write_to_temp` → `flush` → `verify_checksum` → `atomic_rename`.
