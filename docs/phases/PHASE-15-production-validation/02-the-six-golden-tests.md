# PHASE 15 — THE SIX MASTER GOLDEN TESTS

## Executive Certification
All 6 Master Golden Tests mandated by the **Zaynahs Ecosystem Engineering Contract (Rules 120–135)** are 100% implemented, verified, and continuously passing in the automated test runner.

---

## 1. Golden Test 100: Universal POS Engine (`tests/unit/pos_test.dart`)
- **Objective**: Multi-sale execution, split payment allocation, customer ledger reconciliation, and partial return verification.
- **Scenario**:
  1. Initial Stock: Item A (100 units @ 10,000 cost, 15,000 retail).
  2. Sale #1: 3x Item A = 45,000 retail. Paid via Split: 20,000 Cash, 15,000 Bank, 10,000 Customer Due.
  3. Verification: Stock decreases to 97 units; Cash wallet +20,000; Bank wallet +15,000; Customer due +10,000.
  4. Return: 1x Item A returned for refund to Cash wallet.
  5. Final Ledger State: Stock = 98 units; Cash wallet = +5,000; Bank wallet = +15,000; Customer due = +10,000.
- **Mathematical Accuracy**: Zero penny discrepancies.

---

## 2. Golden Test 101: Multi-Device Offline Split Ledger Sync (`tests/unit/sync_test.dart`)
- **Objective**: Zero Last-Write-Wins (LWW) data loss across concurrently operating offline peer devices.
- **Scenario**:
  1. Device A and Device B start with 100 units of Item X in stock.
  2. Both devices go offline (network severed).
  3. Device A sells 20 units locally (`-20` movement event). Local stock = 80.
  4. Device B sells 30 units locally (`-30` movement event). Local stock = 70.
  5. Network reconnects; both devices exchange sync events via `SyncEngine`.
  6. Idempotent application and additive merge: Both ledgers record both events.
  7. Final Stock on both peers: `100 - 20 - 30 = 50` units.
- **Data Integrity**: Zero LWW overwrites, 100% additive convergence.

---

## 3. Golden Test 102: Backup Disaster Recovery & Corrupt Rejection (`tests/unit/backup_test.dart`)
- **Objective**: Verifiable `.zynb` binary archive creation, mandatory pre-restore snapshot, projection rebuild, and 1-byte corrupt restore rejection.
- **Scenario**:
  1. Create complete dataset backup `.zynb` archive with SHA-256 integrity seal.
  2. Mutate 1 single byte in the archive data payload.
  3. Attempt restore: `BackupReader` detects checksum mismatch and immediately aborts before touching database.
  4. Perform valid restore: Mandatory pre-restore snapshot is automatically captured first.
  5. Projection rebuilder recalculates derived stock levels and customer balances directly from raw movement events.

---

## 4. Golden Test 103: Security Hardening, Device Trust & RBAC (`tests/unit/security_hardening_test.dart`)
- **Objective**: Runtime enforcement of device trust lifecycle, deny-by-default permission resolution, direct API protection, deep link guards, and zero secret leakage.
- **Assertions Verified**:
  1. Untrusted devices (`PENDING`, `BLOCKED`, `UNKNOWN`) are strictly blocked.
  2. Revoked devices are immediately and permanently blocked from all operations.
  3. Unauthorized roles (`Cashier`, `Salesman`) are denied privileged endpoints.
  4. Direct API calls without valid authenticated session throw typed `AuthException`.
  5. Deep-link bypass attempts intercepted by `NavigationGuard` and redirected to access-denied.
  6. Backup restore strictly restricted to Owner and Admin only.
  7. CCTV segment deletion strictly restricted to Owner only.
  8. Scanner verifies zero unredacted tokens or secret keys in logs.
  9. Mid-transaction crash triggers SQLite WAL rollback with zero orphan records.
  10. Resource profiling confirms zero dangling file or database handles.

---

## 5. Golden Test 104: Resumable Chunked File Transfer (`tests/unit/collaboration_test.dart`)
- **Objective**: 6-step chunked file transfer protocol over P2P DataChannels, resilient to network drops.
- **Scenario**:
  1. Sender chunks a 256KB binary file into 64KB blocks.
  2. Receiver accepts transfer request and initializes scratch assembly buffer.
  3. Blocks 0 and 1 (50% of file) transmitted successfully.
  4. Network disconnect simulated; transfer interrupted.
  5. Reconnect and handshake: Receiver requests offset starting at Chunk 2.
  6. Remaining chunks transferred; Receiver computes SHA-256 and validates 100% bit-for-bit parity with sender.

---

## 6. Golden Test 105: CCTV Segmented Recording & Sacred Retention Law (`tests/unit/cctv_test.dart`)
- **Objective**: Continuous video segmentation, atomic file promotion, disconnect recovery, and purge protection.
- **Scenario**:
  1. `SegmentedRecorder` streams RTSP chunks into bounded time/size segment files.
  2. Completed segments atomically promoted to persistent storage with SHA-256 digest in `cctv_segments`.
  3. Sudden camera disconnect simulated: Partial buffer safely finalized without file corruption.
  4. Reconnect: Recorder resumes new segment seamlessly.
  5. Disk pressure triggers `RetentionCleaner`.
  6. Protected segments (`is_protected = 1`) strictly survive retention purge.
