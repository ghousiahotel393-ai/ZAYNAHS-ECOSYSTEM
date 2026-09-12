# AGENTS — ROLE-BASED PERMISSION RESOLVER & ACCESS CONTROL

# 69. PERMISSIONS

Permission resolution:

    DENY BY DEFAULT
        ↓
    ROLE TEMPLATE
        ↓
    ROLE PERMISSIONS
        ↓
    USER OVERRIDES
        ↓
    VALUE CONSTRAINTS
        ↓
    FINAL DECISION

---

# 70. UI SECURITY

Hiding UI is NOT authorization.

Protected action must be checked in:

    application/service/domain boundary

not only widget visibility.

---

# 71. OWNER

Owner may have:

    full ecosystem access
    users
    devices
    pairing
    revoke
    backup
    restore
    security
    audit
    settings
    POS
    CCTV
    communication

---

# 72. ADMIN

Admin generally has broad operational access.

Owner-root security actions may remain Owner-only.

---

# 73. MANAGER

Manager may receive:

    communication
    CCTV
    POS
    reports
    operational staff management
    settings

according to explicit permissions.

---

# 74. CASHIER

Typical:

    sales
    returns if allowed
    payments
    customers
    barcode
    printing
    inventory view
    daily reports

No default:

    user administration
    restore
    security root

---

# 75. SALESMAN

Typical:

    product search
    customers
    cart
    sale
    barcode
    printing
    inventory view

No default:

    wallet management
    expenses
    user management
    backup restore
    security root

---

# 76. PERMISSION EXAMPLES

POS:

    pos.sale.create
    pos.sale.view
    pos.sale.cancel
    pos.return.create
    pos.exchange.create
    pos.discount.apply
    pos.discount.override
    pos.discount.max_percent
    pos.payment.cash
    pos.payment.bank
    pos.payment.online
    pos.wallet.transfer
    pos.expense.create
    pos.inventory.view
    pos.inventory.adjust
    pos.purchase.create
    pos.product.create
    pos.product.edit
    pos.product.delete
    pos.barcode.generate
    pos.print
    pos.report.view
    pos.report.export

---

# 77. CCTV PERMISSIONS

    cctv.camera.view
    cctv.camera.manage
    cctv.live.view
    cctv.recording.start
    cctv.recording.stop
    cctv.recording.view
    cctv.recording.download
    cctv.recording.delete
    cctv.recording.protect
    cctv.settings.manage
    cctv.retention.manage
    cctv.detection.view

---

# 78. BACKUP PERMISSIONS

    backup.view
    backup.create
    backup.download
    backup.verify
    backup.restore
    backup.delete
    backup.cloud_upload
    backup.cloud_delete
    backup.retention_manage

---
