# PHASE 11 — SEGMENTED CONTINUOUS RECORDING

## RECORDING PIPELINE
1–5 minute MP4 segments. Atomic write: `temp/` → `flush` → `hash` → atomic rename to `cctv/recordings/YYYY/MM/DD/...`.
