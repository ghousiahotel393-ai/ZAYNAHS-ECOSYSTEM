# AGENTS — CODE QUALITY & RECONCILIATION CHECKS

# 136. CODE QUALITY

Prefer:

    readable names
    small focused functions
    explicit state
    typed models
    validated inputs
    deterministic calculations
    testable services

Avoid:

    clever hacks
    hidden global state
    unnecessary abstractions
    magic numbers
    duplicated logic

---

# 137. COMMENTS

Comments should explain:

    why

not simply:

    what

Avoid comments that become incorrect when code changes.

---

# 138. TODO POLICY

TODO is allowed only when:

    clearly non-blocking
    documented
    not part of claimed completed feature

Critical TODOs prevent completion.

---

# 139. DEPENDENCIES

Before adding dependency:

    inspect existing dependencies
    verify compatibility
    check platform support
    check maintenance status
    check license
    assess security
    assess package size

Do not add dependency for trivial functionality already supported internally.

---

# 140. VERSION UPDATES

Do not upgrade unrelated dependencies during a feature task unless:

    required
    security-critical
    compatibility-critical

Document significant upgrades.

---

# 141. API CONTRACTS

Before changing API:

    search consumers
    search tests
    search sync protocol
    search platform clients
    search documentation

Avoid breaking consumers silently.

---

# 142. DATABASE API

Database changes must preserve:

    migration compatibility
    repository contracts
    sync compatibility
    backup compatibility

---

# 143. SYNC API

Protocol changes require:

    protocol version
    compatibility strategy
    migration/version handling
    tests across versions where needed

---

# 144. UNKNOWN DATA

Never discard unknown fields unless:

    explicitly safe
    documented
    compatible with forward/backward strategy

---

# 145. DATA PRESERVATION

When uncertain:

    preserve

Prefer:

    conflict
    quarantine
    failed state
    recovery

over:

    deletion
    overwrite
    guessing

---

# 146. RECONCILIATION

After implementation compare:

    expected behavior
    actual behavior

Check:

    DB
    ledger
    projections
    UI
    reports
    audit
    sync

---

# 147. RECONCILIATION EXAMPLE

If UI says:

    Stock = 50

but ledger calculates:

    Stock = 47

DO NOT simply set cache to 47.

Investigate:

    missing event
    duplicate event
    incorrect projection
    migration issue
    sync issue

Then fix root cause.

---

# 148. NO SILENT DATA CORRECTION

Never silently modify business data to make tests pass.

Create:

    correction event
    migration
    repair tool
    controlled adjustment

when appropriate.

---

# 149. REPAIR TOOLS

If repair functionality is needed:

    make it explicit
    permission-protected
    audited
    reversible where possible
    tested

Never hide repair behavior inside ordinary reads.

---

# 150. ADMIN TOOLS

Administrative tools may include:

    rebuild projections
    verify ledger
    verify wallet
    inspect sync
    verify backup
    verify storage
    inspect device health

These must be permission-controlled.

---

# 151. RELEASE CHECKLIST

Before release:

    [ ] Build passes
    [ ] Static analysis passes
    [ ] Unit tests pass
    [ ] Integration tests pass
    [ ] E2E critical paths pass
    [ ] Migration tests pass
    [ ] Offline tests pass
    [ ] Sync tests pass
    [ ] Permission tests pass
    [ ] Backup tests pass
    [ ] Restore tests pass
    [ ] Security checks pass
    [ ] Performance checks pass
    [ ] Documentation updated
    [ ] MASTER_SCHEMA updated

---

# 152. AGENT FINAL REPORT

After a meaningful task, report:

    Implemented:
    ...

    Modified:
    ...

    Database:
    ...

    Migration:
    ...

    Permissions:
    ...

    Offline:
    ...

    Sync:
    ...

    Backup:
    ...

    Audit:
    ...

    Tests:
    ...

    Known Limitations:
    ...

    Remaining Risks:
    ...

---

# 153. FAILED TEST REPORTING

Never hide failed tests.

Report:

    test
    failure
    cause
    impact
    workaround if any
    next action

---

# 154. BUILD FAILURE

If build fails:

    inspect root cause

Do not randomly modify unrelated files until build turns green.

---

# 155. TEST FAILURE

If test fails:

    reproduce
    inspect
    determine whether test or implementation is wrong
    fix root cause
    rerun affected tests
    rerun regression suite

---

# 156. REGRESSION RULE

After changing shared infrastructure:

    run all affected module tests

Examples:

Changing:

    PermissionService

requires checking:

    POS
    CCTV
    Communication
    Backup
    Users

---

# 157. SHARED DATABASE CHANGE

Changing database schema requires checking:

    repositories
    projections
    sync
    backup
    restore
    reports
    migrations
    tests

---

# 158. SHARED STORAGE CHANGE

Changing FileStorageService requires checking:

    product images
    chat files
    documents
    CCTV
    backups
    exports
    file transfer

---

# 159. SHARED SYNC CHANGE

Changing SyncService requires checking:

    POS
    inventory
    wallet
    chat
    device state
    files
    CCTV metadata
    settings
    audit

---

# 160. SHARED PERMISSION CHANGE

Changing permissions requires checking:

    every protected module
    UI visibility
    application enforcement
    deep links
    direct API calls

---
