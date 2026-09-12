# AGENTS — ARCHITECTURE LAYERS & SHARED COMPONENTS

# 13. ARCHITECTURE LAYERS

Use:

    Presentation
        ↓
    Application
        ↓
    Domain
        ↓
    Infrastructure
        ↓
    Platform

---

---

# 14. PRESENTATION RULES

Presentation may contain:

    screens
    widgets
    controllers
    view models
    UI state
    formatting for display

Presentation MUST NOT contain:

    raw SQL
    financial transaction logic
    inventory ledger mutation
    direct filesystem paths
    low-level WebRTC
    privileged secret handling
    permission bypass

---

# 15. APPLICATION LAYER

Application layer contains:

    use cases
    orchestration
    permission enforcement
    transaction coordination
    sync coordination
    backup workflows

Application layer coordinates domain and infrastructure.

---

# 16. DOMAIN LAYER

Domain contains:

    entities
    value objects
    business rules
    calculations
    invariants
    state machines

Domain must not depend on Flutter widgets.

---

# 17. INFRASTRUCTURE

Infrastructure contains:

    database
    repositories
    network
    sync transport
    storage
    WebRTC adapters
    backup
    printing
    external APIs

---

# 18. PLATFORM

Platform adapters contain:

    camera
    microphone
    location
    screen capture
    notifications
    filesystem
    printer
    native background services
    device capabilities

---

# 19. SINGLE RESPONSIBILITY

Each module should have clear responsibility.

Avoid giant classes containing:

    UI
    database
    network
    business logic
    storage

in one file.

---

# 20. FILE SIZE

Normal source files should generally remain around:

    200–400 lines

When a file becomes large:

    inspect responsibilities
    split logically

Do not split purely by line count.

Generated code, migrations, schemas, and documentation may be larger.

---

# 21. SHARED COMPONENT RULE

Before creating a component:

    search repository

Prefer shared:

    Button
    Dialog
    Table
    Search
    Filters
    Empty State
    Error State
    Loading State
    Pagination
    Product Card
    Device Card
    Ledger
    Audit Timeline
    Permission Matrix

---

# 22. NO DUPLICATE SERVICES

Prefer shared services:

    AuthService
    PermissionService
    SettingsService
    FileStorageService
    SyncService
    AuditService
    BackupService
    PrintService
    DeviceService
    P2PService
    ReportService

Do not create:

    PosSyncService
    CctvSyncService
    ProductSyncService

when one shared sync architecture can support all modules.

---
