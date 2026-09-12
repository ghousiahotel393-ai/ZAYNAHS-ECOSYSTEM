# PHASE 02 — LOCAL DATABASE ENGINE (DRIFT/SQLITE)

## OBJECTIVE
Establish the cross-platform local SQLite / Drift database engine.

## ARCHITECTURAL CONSTRAINTS
- Local-first: every device has its own complete, isolated local database.
- Database access through repositories only. No raw SQL in presentation widgets.
- WAL (Write-Ahead Logging) mode enabled for high concurrency.
- Foreign keys strictly enforced on all connections.
