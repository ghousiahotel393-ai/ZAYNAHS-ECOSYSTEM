# AGENTS — PRODUCTION QUALITY GATES & FINAL CONTRACT

# 161. NO UI-ONLY FIX

If a bug is caused by domain/database/sync:

    fix root layer

Do not simply manipulate UI to hide it.

---

# 162. NO CACHE-ONLY FIX

If source data is wrong:

    fix source

Do not only refresh cache.

---

# 163. NO REPORT-ONLY FIX

If report is wrong:

    determine whether source ledger/projection/query is wrong

Do not hardcode report correction.

---

# 164. NO SYNC-ONLY FIX

If remote balance is wrong:

    inspect authoritative event history

Do not overwrite remote total.

---

# 165. DEVICE CLOCK

Use:

    UTC storage
    local display

Do not trust client wall clock as sole financial ordering mechanism.

---

# 166. EVENT ORDERING

Use:

    event ID
    logical version
    causal metadata where appropriate

Do not assume:

    timestamp = causality

---

# 167. EVENT SIGNING

Where ecosystem security model requires:

    authenticate event origin
    validate signature
    verify trusted device

Never accept privileged event merely because payload looks valid.

---

# 168. EVENT HASH

Hash event content where required.

Receiver verifies:

    payload integrity
    expected schema
    event identity

---

# 169. SYNC QUEUE DURABILITY

Queue state must survive:

    app restart
    device restart
    temporary network failure

Do not keep critical unsent events only in memory.

---

# 170. FILE TRANSFER DURABILITY

Transfer metadata must survive:

    app restart
    connection interruption

Partial files must be recoverable or safely cleaned.

---

# 171. BACKUP DURABILITY

Backup generation must not leave corrupted archive marked successful.

---

# 172. CAMERA FAILURE

If camera disconnects:

    recording state must change
    user must see failure
    reconnect logic may retry
    no fake recording status

---

# 173. STORAGE FAILURE

If recording cannot write:

    stop/mark recording safely
    preserve metadata
    notify
    do not report successful recording

---

# 174. CAMERA PERMISSIONS

If OS permission revoked:

    stop affected operation
    update status
    explain permission requirement

---

# 175. LOCATION PERMISSIONS

If permission unavailable:

    show unavailable

Do not fake last-known location as current location.

---

# 176. NETWORK STATUS

Connection status must represent actual state.

Avoid:

    permanent "online"
    permanent "syncing"

---

# 177. DEVICE HEALTH

Device health must be based on actual measurements.

Never hardcode:

    battery
    storage
    network

---

# 178. CLEANUP

Temporary files must have lifecycle.

Clean safely:

    stale temporary files
    failed partial transfers
    incomplete exports

Never clean:

    active transfer
    active backup
    protected recording
    unsent sync event

---

# 179. CONCURRENCY

Consider concurrent:

    sales
    returns
    inventory updates
    wallet transactions
    sync
    backup
    recording
    file transfer

Use appropriate locking/transactions/serialization.

---

# 180. DEADLOCK AVOIDANCE

Keep locks:

    short
    ordered
    scoped

Avoid waiting for network while holding DB locks.

---

# 181. UI RESPONSIVENESS

Never block UI thread with:

    hashing
    compression
    large queries
    video processing
    backup
    huge exports

---

# 182. OBSERVABILITY

Provide diagnostics for:

    database
    sync
    P2P
    WebRTC
    CCTV
    backup
    storage
    network

---

# 183. DIAGNOSTIC SECURITY

Diagnostics must not expose:

    passwords
    tokens
    private keys
    secret URLs
    camera credentials

---

# 184. ADMIN DIAGNOSTICS

Authorized users may inspect:

    device
    connection
    sync state
    retry count
    backup status
    storage
    CCTV health

according to permissions.

---

# 185. HEALTH STATES

Use clear states:

    HEALTHY
    WARNING
    DEGRADED
    OFFLINE
    FAILED
    BLOCKED
    CONFLICT

---

# 186. NO FALSE HEALTH

A system with queued/failed sync must not show:

    fully synchronized

A failed backup must not show:

    backup healthy

---

# 187. DOCUMENTATION RULE

When behavior changes, update:

    relevant docs
    architecture docs
    database docs
    protocol docs
    testing docs

Do not leave documentation describing old behavior.

---

# 188. MASTER_SCHEMA ENFORCEMENT

If schema changes and MASTER_SCHEMA is not updated:

    task is INCOMPLETE

---

# 189. AGENTS.MD ENFORCEMENT

This document is a project engineering contract.

If another instruction conflicts with:

    data integrity
    security
    explicit architecture

follow the safer production architecture.

---

# 190. USER REQUEST INTERPRETATION

When user requests a feature:

    determine exact intended behavior
    inspect existing system
    identify dependencies
    implement minimal complete solution

Do not expand scope unnecessarily.

---

# 191. SCOPE CONTROL

Do not change unrelated:

    UI
    dependencies
    database
    architecture
    styling
    modules

unless impact analysis shows necessity.

---

# 192. CLEAN IMPLEMENTATION

Prefer:

    minimal change
    shared abstraction
    tested behavior
    backward compatibility

over:

    large rewrite

---

# 193. SECURITY-FIRST FEATURE REVIEW

Before finishing any feature ask:

    Can unauthorized user invoke it?
    Can unauthorized device invoke it?
    Can deep link bypass it?
    Can offline state bypass it?
    Can sync bypass it?
    Can stale permission bypass it?
    Are secrets exposed?
    Is sensitive data logged?

---

# 194. DATA-INTEGRITY FEATURE REVIEW

Ask:

    Is operation atomic?
    Is it idempotent?
    Is history immutable?
    Is audit recorded?
    Is sync event created?
    Does offline mode work?
    Does retry duplicate data?
    Does restore preserve it?
    Can projection rebuild recover it?

---

# 195. PERFORMANCE FEATURE REVIEW

Ask:

    Does it load everything?
    Does it allocate huge memory?
    Does it poll unnecessarily?
    Does it block UI?
    Does it leak handles?
    Does it increase battery drain?
    Does it scale with large datasets?

---

# 196. RECOVERY FEATURE REVIEW

Ask:

    What if app crashes?
    What if power fails?
    What if network disconnects?
    What if peer disappears?
    What if storage becomes full?
    What if operation is retried?
    What if data is corrupted?

---

# 197. PRODUCTION CONTRACT

Never claim:

    "complete"

until actual verification supports it.

Allowed status:

    IMPLEMENTED
    PARTIALLY IMPLEMENTED
    TESTED
    VERIFIED
    BLOCKED
    FAILED
    NOT IMPLEMENTED

Use truthful status.

---

# 198. FINAL AGENT CHECK

Before final response:

    [ ] No branch architecture introduced
    [ ] No duplicate core engine introduced
    [ ] No security bypass
    [ ] No fake success
    [ ] No fake core functionality
    [ ] No hardcoded secrets
    [ ] No financial overwrite
    [ ] No inventory history rewrite
    [ ] No last-write-wins financial sync
    [ ] No silent conflict deletion
    [ ] No silent unknown-event deletion
    [ ] No UI-only authorization
    [ ] No unsafe filesystem paths
    [ ] No unbounded memory operation
    [ ] No missing migration
    [ ] No stale MASTER_SCHEMA
    [ ] Tests run
    [ ] Results reported
    [ ] Documentation updated

---

# 199. FINAL PROJECT LAW

ZAYNAHS ECOSYSTEM is:

    local-first
    offline-capable
    event-driven
    ledger-driven
    permission-controlled
    trusted-device based
    P2P capable
    cloud-assisted
    recoverable
    auditable
    cross-platform
    production-oriented

---

# 200. FINAL RULE

When choosing between:

    easy implementation

and:

    correct production architecture

ALWAYS choose:

    correct production architecture.


# END OF AGENTS.md

---
