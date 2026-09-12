# GEMINI — FINAL REVIEWS, QUALITY GATES & PROHIBITIONS

# 106. NO LAST-WRITE-WINS

Never use generic LWW for:

    inventory
    financial records
    wallet transactions
    sale events
    return events

Domain-specific conflict resolution only.

---

# 107. NO SILENT DELETION

Never silently delete:

    sync events
    financial history
    audit
    protected recordings
    failed recovery data
    unknown events

---

# 108. NO SILENT OVERWRITE

When conflict exists:

    preserve
    inspect
    reconcile

Do not overwrite just to make UI look correct.

---

# 109. NO SECRET IN SOURCE

Never commit:

    passwords
    tokens
    private keys
    service-role keys
    production secrets

---

# 110. ENV

Use:

    .env

for local configuration.

Maintain:

    .env.example

without real secrets.

---

# 111. GIT

Git is source control.

Agent may:

    inspect
    branch
    commit
    test
    prepare changes

Do not perform destructive operations without explicit authorization.

Never:

    force-reset user work
    delete unrelated changes
    rewrite history unnecessarily

---

# 112. DEPLOYMENT

Do not invent deployment infrastructure.

Follow existing project configuration.

Never expose production credentials in client builds.

---

# 113. SECURITY REVIEW

For each feature ask:

    Can unauthorized user call it?
    Can revoked device call it?
    Can deep link bypass it?
    Can offline mode bypass it?
    Can sync bypass it?
    Can stale permissions bypass it?
    Are secrets exposed?
    Is sensitive data logged?

---

# 114. DATA REVIEW

Ask:

    Is operation atomic?
    Is it idempotent?
    Is history immutable?
    Is audit recorded?
    Is sync event recorded?
    Is offline supported?
    Can retry duplicate it?
    Can projection rebuild recover it?
    Can backup restore it?

---

# 115. PERFORMANCE REVIEW

Ask:

    Does it load everything?
    Does it block UI?
    Does it allocate huge memory?
    Does it poll unnecessarily?
    Does it leak resources?
    Does it drain battery?

---

# 116. RECOVERY REVIEW

Ask:

    What happens after crash?
    What happens after restart?
    What happens after network loss?
    What happens after peer disconnect?
    What happens when disk is full?
    What happens after duplicate retry?
    What happens after corrupted data?

---

# 117. STOP CONDITIONS

STOP and report instead of guessing if:

    schema is ambiguous
    migration could destroy data
    security model is unclear
    existing behavior conflicts with required architecture
    sync semantics are undefined for destructive operation
    backup compatibility is unknown
    required platform capability is unavailable

---

# 118. SAFE RESPONSE TO BLOCKER

When blocked:

    identify blocker
    explain impact
    provide evidence
    preserve working code
    do not fabricate completion

---

# 119. NO "DONE" WITHOUT VERIFICATION

The following do NOT mean complete:

    code compiles
    screen renders
    button responds
    mock passes
    one-device test passes
    online test passes

Completion requires relevant full verification.

---

# 120. PRODUCTION DEFINITION

A feature is production-ready only if:

    correct
    secure
    durable
    recoverable
    testable
    observable
    documented
    synchronized
    permission-controlled
    performant

---

# 121. FINAL QUALITY GATE

Before declaring release:

    [ ] No multi-branch logic
    [ ] No duplicate core engines
    [ ] No fake core feature
    [ ] No fake success state
    [ ] No secret in code
    [ ] No UI-only authorization
    [ ] No financial overwrite
    [ ] No inventory history mutation
    [ ] No LWW financial sync
    [ ] No silent conflict deletion
    [ ] No silent unknown-event deletion
    [ ] No unsafe file path
    [ ] No unbounded memory
    [ ] All required migrations created
    [ ] MASTER_SCHEMA updated
    [ ] Tests pass
    [ ] Offline verified
    [ ] Sync verified
    [ ] Backup verified
    [ ] Restore verified
    [ ] Security verified
    [ ] Performance verified
    [ ] Documentation updated

---

# 122. FINAL EXECUTION RULE

When user asks:

    "build"
    "implement"
    "fix"
    "complete"
    "add"
    "update"

DO NOT immediately start random coding.

First:

    inspect
    understand
    impact-analyze
    plan

Then implement.

After implementation:

    test
    reconcile
    verify
    document

---

# 123. FINAL PROJECT PRINCIPLES

Always preserve:

    ONE ECOSYSTEM
    TRUSTED DEVICES
    LOCAL-FIRST
    OFFLINE-FIRST
    EVENT-DRIVEN SYNC
    IMMUTABLE LEDGERS
    ATOMIC TRANSACTIONS
    EXPLICIT PERMISSIONS
    AUDITABILITY
    VERIFIED BACKUPS
    RECOVERABILITY
    P2P COMMUNICATION
    SHARED SERVICES
    SHARED POS ENGINE
    SHARED REPORT ENGINE
    SHARED PRINT ENGINE
    SHARED STORAGE
    SHARED SYNC
    CROSS-PLATFORM ARCHITECTURE

---

# 124. ABSOLUTE PROHIBITIONS

NEVER:

    introduce multi-branch
    create duplicate POS engines
    create duplicate sync engines
    hardcode credentials
    bypass permissions
    put SQL in UI
    put filesystem paths in modules
    overwrite financial history
    rewrite inventory history
    use LWW for financial events
    silently discard conflicts
    silently discard unknown events
    fake camera/recording state
    fake location
    perform covert camera capture
    perform covert microphone capture
    perform covert screen capture
    fabricate successful backup
    fabricate successful sync
    load huge files fully into memory
    claim complete without verification

---

# 125. FINAL COMMAND TO THE AGENT

For every task:

    THINK BEFORE CODE.

    INSPECT BEFORE MODIFY.

    SEARCH BEFORE DUPLICATE.

    IMPACT-ANALYZE BEFORE ARCHITECTURE CHANGE.

    USE TRANSACTIONS FOR ATOMIC BUSINESS OPERATIONS.

    USE IMMUTABLE EVENTS FOR HISTORY.

    USE DURABLE QUEUES FOR SYNC.

    USE PERMISSIONS AT THE SERVICE BOUNDARY.

    PRESERVE DATA WHEN UNCERTAIN.

    TEST FAILURE CASES.

    VERIFY ACTUAL RESULTS.

    UPDATE MASTER_SCHEMA AFTER EVERY SCHEMA CHANGE.

    NEVER CLAIM SUCCESS WITHOUT EVIDENCE.


# END OF GEMINI.md

---
