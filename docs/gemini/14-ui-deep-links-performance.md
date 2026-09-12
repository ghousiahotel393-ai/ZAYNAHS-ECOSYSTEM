# GEMINI — UI DESIGN, DEEP LINKS & SYSTEM PERFORMANCE

# 84. UI DESIGN

UI should be:

    clean
    modern
    responsive
    accessible
    fast
    focused

Avoid:

    unnecessary animations
    clutter
    excessive cards
    duplicate controls

---

# 85. RESPONSIVE

Support:

    phone
    tablet
    desktop
    web

Do not simply stretch mobile UI onto desktop.

---

# 86. SHARED UI

Use shared:

    AppScaffold
    AppBar
    Sidebar
    BottomNav
    SearchField
    DateFilter
    FilterBar
    DataTable
    Pagination
    ProductCard
    DeviceCard
    StatusBadge
    EmptyState
    ErrorState
    LoadingState
    Skeleton
    ConfirmDialog
    FormDialog
    PermissionMatrix
    AuditTimeline
    LedgerTable
    StatCard
    ActionButton
    PrimaryButton
    SecondaryButton
    IconButton
    FilePicker
    ImagePicker
    BarcodePreview
    QRPreview
    PrintPreview

---

# 87. DEEP LINKS

Maintain:

    /product/:productId
    /product/:productId/ledger
    /sale/:saleId
    /sale/:saleId/payment
    /return/:returnId
    /customer/:customerId
    /supplier/:supplierId
    /payment/:paymentId
    /wallet/:walletId
    /inventory/:movementId
    /user/:userId
    /device/:deviceId
    /recording/:recordingId
    /backup/:backupId

---

# 88. DEEP LINK FAILURE

If entity missing:

    Not Found

If unauthorized:

    Access Denied

Never:

    crash
    expose protected data

---

# 89. PERFORMANCE RULE

Every implementation must consider:

    query size
    memory
    CPU
    battery
    disk
    network
    handles
    sockets

---

# 90. PAGINATION

Use pagination/cursors for:

    large products
    ledger
    messages
    sales
    reports
    recordings
    files

---

# 91. THUMBNAILS

For image-heavy views:

    thumbnail first
    medium when needed
    original on demand

---

# 92. VIDEO

Do not load full video.

Use:

    streaming
    segments
    timeline
    on-demand playback

---

# 93. BACKGROUND WORK

CPU-heavy operations may use:

    isolates
    workers
    native background execution

Do not block UI thread.

---

# 94. MEMORY LEAK REVIEW

Check:

    camera handles
    microphone
    WebRTC
    sockets
    streams
    DB connections
    file handles
    timers
    subscriptions

---
