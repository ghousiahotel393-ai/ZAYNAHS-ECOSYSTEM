# AGENTS — OPERATING MODE & INSPECTION BEFORE CODING

# 6. AGENT OPERATING MODE

For every task use:

    INSPECT
    ↓
    UNDERSTAND
    ↓
    IMPACT ANALYSIS
    ↓
    PLAN
    ↓
    IMPLEMENT
    ↓
    TEST
    ↓
    RECONCILE
    ↓
    VERIFY
    ↓
    DOCUMENT
    ↓
    REPORT

Do not skip INSPECT.

Do not skip TEST.

Do not skip RECONCILE.

Do not claim completion before VERIFY.

---

---

# 7. INSPECT BEFORE MODIFYING

Before changing code inspect:

    repository structure
    relevant module
    related modules
    domain entities
    application services
    repositories
    database
    migrations
    permissions
    sync
    offline behavior
    backup
    deep links
    shared UI
    tests
    platform adapters
    existing documentation

Search the repository before creating:

    component
    helper
    service
    repository
    validator
    formatter
    model
    utility

Reuse existing implementations where appropriate.

---

---

# 8. DO NOT REWRITE WORKING CODE

If an existing implementation works:

    understand it
    test it
    extend it

Do not replace it simply because another implementation looks cleaner.

Only rewrite when:

    current implementation is incorrect
    current architecture blocks required functionality
    security requires replacement
    data integrity requires replacement
    performance requires replacement
    maintainability is genuinely compromised

Document major rewrites.

---

# 9. 360-DEGREE IMPACT ANALYSIS

Every meaningful change MUST consider:

    UI
    Domain
    Application
    Database
    Migration
    Permissions
    Offline
    Sync
    Audit
    Backup
    Restore
    Reports
    Printing
    Barcode
    Deep Links
    Error Handling
    Performance
    Security
    Platform
    Tests
    Documentation

Example:

Changing a sale item may affect:

    product
    variant
    inventory
    sale
    return
    replacement
    payment
    wallet
    customer ledger
    reports
    barcode
    receipt
    audit
    sync
    backup
    permissions
    deep links
    tests

---

---

# 10. DEFINITION OF DONE

A feature is DONE only when applicable:

    UI
    Domain
    Application
    Database
    Migration
    Permissions
    Offline
    Sync
    Audit
    Backup
    Deep Links
    Error Handling
    Performance
    Security
    Unit Tests
    Integration Tests
    E2E Tests
    Documentation

are complete and verified.

If a layer does not apply:

    explicitly document why.

---

# 11. NO FAKE FEATURES

Never ship fake core functionality.

Forbidden:

    fake camera status
    fake recording
    fake sync success
    fake backup success
    fake P2P connected state
    hardcoded inventory
    hardcoded wallet balance
    fake report totals
    mock-only production service
    fake file transfer completion

Mocks are allowed for:

    unit tests
    integration tests
    isolated development

They must never silently become production implementations.

---

# 12. NO PLACEHOLDER CORE

Do not write:

    TODO implement later

for a required production core feature and then declare the feature done.

If implementation cannot safely be completed:

    report incomplete
    identify blocker
    preserve working behavior

---
