# AGENTS — TESTING MATRIX & MASTER GOLDEN TESTS

# 120. TESTING

Testing is mandatory.

Minimum categories:

    unit
    integration
    E2E
    offline
    sync
    security
    performance
    failure recovery

---

# 121. UNIT TESTS

Test:

    totals
    taxes
    discounts
    split payments
    wallet formulas
    inventory formulas
    returns
    replacements
    permission resolution
    backup manifest
    hashes
    sync deduplication
    conflict handling
    projection rebuild

---

# 122. INTEGRATION TESTS

Test:

    database
    migrations
    repositories
    WebRTC adapters
    signaling
    DataChannel
    backup
    restore
    storage
    printing
    sync

---

# 123. E2E TESTS

Where supported:

    Android ↔ Android
    Android ↔ iPhone
    iPhone ↔ iPhone
    Android ↔ Windows
    iPhone ↔ Windows
    Windows ↔ Web
    Android ↔ Web
    iPhone ↔ Web

---

# 124. NETWORK TESTS

Test:

    same Wi-Fi
    different Wi-Fi
    mobile data
    Wi-Fi → mobile
    no Internet
    latency
    packet loss
    NAT
    restrictive firewall

---

# 125. OFFLINE TESTS

Test:

    offline sale
    offline return
    offline inventory
    offline chat
    offline file queue
    offline CCTV
    reconnect
    simultaneous operations

---

# 126. LONG-RUN TESTS

Test:

    CCTV 24+ hours
    large file transfer
    sync worker
    WebRTC
    multi-camera
    large reports
    large gallery
    backup generation

Monitor:

    RAM
    CPU
    battery
    sockets
    handles
    DB connections
    storage

---

# 127. FAILURE RECOVERY

Test:

    app crash
    app restart
    device restart
    power loss
    network loss
    peer disconnect
    camera disconnect
    storage full
    transfer interruption
    sync failure
    backup interruption

---

# 128. DATA INTEGRITY TEST

Every state-changing operation must leave either:

    complete valid state

or:

    unchanged state

Never:

    half sale
    half payment
    half inventory event

---

# 129. GOLDEN POS TEST

Use:

    Item price = 100

    4 cash sales
        = 400

    5 online sales
        = 500

    10 bank sales
        = 1000

    5 discounted items
        gross = 500
        discount = 50
        net = 450
        cash = 225
        bank = 225

    return 3
        refund = 270
        cash = 135
        bank = 135
        inventory = +3

Verify:

    totals
    inventory
    wallets
    customer ledger
    reports
    audit
    sync

---

# 130. MULTI-DEVICE GOLDEN TEST

Initial stock:

    100

Device A:

    offline sale -20

Device B:

    offline sale -30

Reconnect.

Expected:

    stock = 50

Both transactions must survive.

---

# 131. BACKUP GOLDEN TEST

Create:

    product
    sale
    return
    inventory movement
    wallet transaction
    customer record

Backup.

Verify:

    archive
    manifest
    checksum

Corrupt backup.

Expected:

    verification fails.

---

# 132. RESTORE GOLDEN TEST

    backup
    ↓
    change data
    ↓
    pre-restore backup
    ↓
    restore
    ↓
    rebuild projections
    ↓
    verify
    ↓
    audit

---

# 133. SECURITY GOLDEN TEST

Verify:

    untrusted device denied
    revoked device denied
    unauthorized user denied
    hidden UI does not bypass authorization
    backup restore protected
    CCTV deletion protected
    secrets absent from logs

---

# 134. FILE TRANSFER GOLDEN TEST

    start
    ↓
    transfer 50%
    ↓
    network loss
    ↓
    reconnect
    ↓
    resume
    ↓
    SHA-256 verify
    ↓
    complete

---

# 135. CCTV GOLDEN TEST

    connect camera
    ↓
    discover
    ↓
    preview
    ↓
    record
    ↓
    disconnect
    ↓
    reconnect
    ↓
    resume
    ↓
    playback
    ↓
    timeline
    ↓
    protect
    ↓
    retention

---
