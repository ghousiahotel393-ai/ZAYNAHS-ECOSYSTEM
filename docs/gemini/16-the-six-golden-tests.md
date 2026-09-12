# GEMINI — THE SIX MASTER GOLDEN TESTS

# 100. GOLDEN POS TEST

Input:

    item price = 100

Sales:

    4 cash
    5 online
    10 bank

Expected:

    cash = 400
    online = 500
    bank = 1000

Discount:

    5 items
    gross = 500
    discount = 50
    net = 450

Split:

    cash = 225
    bank = 225

Return:

    quantity = 3
    refund = 270
    cash refund = 135
    bank refund = 135
    inventory = +3

Verify every ledger/report/audit/sync layer.

---

# 101. MULTI-DEVICE GOLDEN TEST

Initial:

    stock = 100

Device A offline:

    sale -20

Device B offline:

    sale -30

After sync:

    stock = 50

Both transactions survive.

---

# 102. BACKUP GOLDEN TEST

Create:

    product
    sale
    return
    inventory
    wallet
    customer

Backup.

Verify checksum.

Corrupt archive.

Expected:

    verification failure.

---

# 103. SECURITY GOLDEN TEST

Verify:

    untrusted device denied
    revoked device denied
    unauthorized user denied
    direct API denied
    deep-link bypass denied
    restore permission enforced
    recording delete permission enforced
    secrets absent from logs

---

# 104. FILE GOLDEN TEST

    start transfer
    interrupt at 50%
    reconnect
    resume
    verify SHA-256
    complete

Expected:

    one valid final file

---

# 105. CCTV GOLDEN TEST

    discover camera
    preview
    record
    disconnect
    reconnect
    resume
    playback
    timeline
    protect
    retention

Expected:

    no corrupt completed segment
    no fake recording state

---
