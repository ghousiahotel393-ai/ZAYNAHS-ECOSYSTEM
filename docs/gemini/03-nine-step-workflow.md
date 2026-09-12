# GEMINI — NINE-STEP OPERATING WORKFLOW

# 8. AGENT WORKFLOW

For EVERY feature:

    STEP 1  INSPECT
    STEP 2  IMPACT ANALYSIS
    STEP 3  PLAN
    STEP 4  IMPLEMENT
    STEP 5  TEST
    STEP 6  RECONCILE
    STEP 7  VERIFY
    STEP 8  DOCUMENT
    STEP 9  REPORT

---

# 9. STEP 1 — INSPECT

Before coding:

    inspect repository
    inspect existing architecture
    inspect relevant module
    inspect database
    inspect migrations
    inspect permissions
    inspect sync
    inspect backup
    inspect shared components
    inspect tests
    inspect platform adapters

Search before creating anything.

---

# 10. STEP 2 — IMPACT ANALYSIS

For every change identify affected:

    UI
    domain
    application
    database
    migration
    permissions
    offline
    sync
    audit
    backup
    restore
    reports
    printing
    barcode
    deep links
    performance
    security
    platform
    tests
    documentation

---

# 11. REQUIRED IMPACT FORMAT

Before implementation internally establish:

    Feature:
    Current behavior:
    Required behavior:
    Root cause:
    Affected modules:
    Affected database:
    Affected permissions:
    Affected sync:
    Affected backup:
    Affected reports:
    Affected tests:
    Risks:
    Rollback strategy:

---

# 12. STEP 3 — PLAN

Plan the smallest complete production implementation.

Avoid:

    unnecessary rewrites
    duplicate engines
    duplicate services
    unrelated dependency changes
    unrelated UI changes

---

# 13. STEP 4 — IMPLEMENT

Implement:

    shared
    typed
    testable
    secure
    offline-safe
    sync-safe
    recoverable

Do not implement only the visible screen.

---

# 14. STEP 5 — TEST

Run:

    unit tests
    integration tests
    relevant E2E tests
    offline tests
    sync tests
    permission tests
    failure tests

according to feature impact.

---

# 15. STEP 6 — RECONCILE

Compare:

    UI values
    database values
    ledger calculations
    projections
    reports
    audit
    sync state

Any mismatch requires investigation.

---

# 16. STEP 7 — VERIFY

Verify:

    happy path
    invalid input
    duplicate request
    retry
    offline
    reconnect
    permission denial
    crash
    restart
    storage pressure
    network failure

where applicable.

---

# 17. STEP 8 — DOCUMENT

Update:

    architecture docs
    database docs
    MASTER_SCHEMA
    protocol docs
    testing docs
    relevant README/docs

---

# 18. STEP 9 — REPORT

Final report must state:

    Implemented
    Modified
    Database changes
    Migration
    Permissions
    Offline behavior
    Sync behavior
    Backup impact
    Audit
    Tests
    Verification
    Known limitations
    Remaining risks

---
