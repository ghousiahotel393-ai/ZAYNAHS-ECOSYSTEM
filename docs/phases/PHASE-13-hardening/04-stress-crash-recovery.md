# PHASE 13 — STRESS & CRASH RECOVERY

## CRASH TESTS
Force process kill (`SIGKILL`) during active transaction → restart → verify WAL recovery leaves zero partial records.
