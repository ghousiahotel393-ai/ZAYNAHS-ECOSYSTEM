# AGENTS — ARCHITECTURE & ABSOLUTE NO-BRANCH RULE

# 3. CORE ARCHITECTURAL LAW

The application is ONE ecosystem.

It contains:

    users
    trusted devices
    communication
    CCTV
    Universal POS
    inventory
    payments
    customers
    suppliers
    reports
    backup
    settings
    audit
    synchronization

There is NO MULTI-BRANCH architecture.

---

---

# 4. ABSOLUTE NO-BRANCH RULE

NEVER introduce:

    branch_id
    branches
    branch table
    branch manager
    branch permissions
    branch reports
    branch settings
    branch inventory
    branch switching
    branch-specific device ownership

A device is NOT a branch.

Correct:

    Ecosystem
        ↓
    Trusted Devices
        ↓
    Users
        ↓
    Modules

Incorrect:

    Ecosystem
        ↓
    Branch
        ↓
    Devices

If an existing code path contains branch concepts, inspect whether it is
legacy code and safely remove/refactor it without breaking required data.

Do not reintroduce branches to solve synchronization.

---

# 5. TRUSTED DEVICE MODEL

Every participating device is an independent peer.

Examples:

    Android phone
    iPhone
    Windows PC
    Web client

A trusted device may operate:

    online
    offline
    LAN
    Internet
    mobile data
    different city/network

A device can later synchronize with other trusted devices.

---

---
