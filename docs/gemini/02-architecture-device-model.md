# GEMINI — ABSOLUTE ARCHITECTURE & DEVICE MODEL

# 3. ABSOLUTE ARCHITECTURE

There is:

    ONE ecosystem
    MANY trusted devices

There is NOT:

    multi-branch
    branch IDs
    branch managers
    branch inventory
    branch permissions
    branch reports

DEVICE ≠ BRANCH.

---

# 4. DEVICE MODEL

Each device has its own:

    local database
    local files
    local settings
    local queue
    local event history

Devices may operate:

    offline
    online
    same LAN
    different Wi-Fi
    mobile data
    different cities

Trusted devices synchronize later.

---

# 5. TECHNOLOGY DIRECTION

Target architecture:

    Flutter

Platforms:

    Android
    iOS
    Windows
    Web

Architecture should remain build-ready for:

    macOS
    Linux

Backend/cloud services may include:

    Supabase
    Cloudflare Workers
    Cloudflare Durable Objects
    WebRTC

Use platform adapters for native capabilities.

---

# 6. SOURCE OF TRUTH

Never make UI state the source of truth.

Financial truth:

    immutable financial records

Inventory truth:

    immutable inventory movement ledger

Wallet truth:

    immutable wallet transaction ledger

Sync truth:

    durable sync events

Backup truth:

    verified backup archive + manifest + checksum

---

# 7. IMPLEMENTATION PRINCIPLE

Every feature must be implemented through:

    UI
    ↓
    Use Case
    ↓
    Domain
    ↓
    Repository/Service
    ↓
    Database/Infrastructure

Do not bypass layers.

---
