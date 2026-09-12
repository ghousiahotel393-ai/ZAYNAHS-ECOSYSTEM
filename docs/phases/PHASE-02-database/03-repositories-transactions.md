# PHASE 02 — REPOSITORY PATTERN & ATOMIC TRANSACTIONS

## TRANSACTION MANAGEMENT
- All financial and inventory state changes MUST execute in atomic DB transactions.
- TransactionCoordinator provides rollback guarantees: if one entity fails, all changes roll back.
- Durable sync events are written in the SAME transaction as domain changes.
