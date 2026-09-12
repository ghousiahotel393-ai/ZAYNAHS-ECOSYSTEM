# PHASE 00 — SYSTEM ARCHITECTURE MAP
# Zaynahs Ecosystem Production Monorepo Topology

> **Status:** ✅ VERIFIED & APPROVED  
> **Topology:** Monorepo (`apps/` + `packages/` + `services/`)  
> **Architecture Pattern:** Clean Layered Architecture (Presentation → Application → Domain → Infrastructure → Platform)

---

## 1. ECOSYSTEM MONOREPO TOPOLOGY

```
zaynahs_ecosystem/
├── apps/
│   └── ecosystem_app/              # Main multi-platform application entry point
│       ├── lib/
│       │   ├── main.dart           # App bootstrap, DI initialization, root router
│       │   └── app.dart            # Global MaterialApp, theme configuration, error boundary
│       ├── android/                # Android native host project
│       ├── ios/                    # iOS native host project
│       ├── windows/                # Windows native host project
│       └── web/                    # Web native host project
│
├── packages/                       # Decoupled Domain & Infrastructure Modules
│   ├── core/                       # Result types, domain errors, UUIDv7, value objects
│   ├── crypto/                     # Ed25519 signatures, AES-256-GCM, SHA-256 streams
│   ├── database/                   # SQLite/Drift engine, tables, migrations, repositories
│   ├── device/                     # Device identity, capabilities, hardware specs
│   ├── discovery/                  # LAN mDNS discovery and local subnet broadcaster
│   ├── pairing/                    # Cryptographic device pairing protocol (6-digit PIN)
│   ├── p2p/                        # WebRTC PeerConnection, DataChannel multiplexer
│   ├── signaling/                  # Cloudflare Workers WebSocket rendezvous client
│   ├── sync/                       # Event-driven sync engine, durable outbox, cursors
│   ├── communication/              # E2E encrypted chat, voice/video calls, attachments
│   ├── sharing/                    # Resumable chunked file transfers, clipboard, links
│   ├── location/                   # Ephemeral GPS coordinate streaming
│   ├── cctv/                       # IP/RTSP & USB camera host, segmented MP4 recording
│   ├── pos/                        # Universal POS engine, catalog, cart, checkout
│   ├── inventory/                  # Immutable inventory movement ledger, stock valuation
│   ├── customers/                  # Customer profiles, credit ledger, dues derivation
│   ├── suppliers/                  # Vendor management, purchase orders, payables
│   ├── payments/                   # Multi-wallet engine (Cash, Bank, Online), split pay
│   ├── users_access/               # Users, roles, session tokens, local pin unlock
│   ├── backup/                     # .zynb backup archive creator, integrity validator
│   ├── permissions/                # Deny-by-default RBAC permission resolver
│   ├── reports/                    # Authoritative reporting engine, P&L, shift closeouts
│   ├── printing/                   # ESC/POS thermal renderer, PDF generator
│   ├── barcode/                    # Barcode & QR code generator, camera & HID scanner
│   ├── storage/                    # Unified FileStorageService, directory sandboxes
│   └── ui/                         # Shared UI component library (27 shared widgets)
│
├── services/                       # Standalone daemons & cloud-assisted micro-workers
│   ├── signaling_worker/           # Cloudflare Worker with Durable Objects for WebRTC
│   └── camera_host/                # Standalone background camera streaming daemon
│
├── docs/                           # Authoritative Documentation Suites
│   ├── agents/                     # 21 modular files covering AGENTS.md rules
│   ├── gemini/                     # 17 modular files covering GEMINI.md protocols
│   └── phases/                     # 16 detailed phase execution folders (00 to 15)
│
└── tests/                          # Master Golden & Integration Test Batteries
    ├── golden/                     # Golden Tests (POS 100, Multi-device 101, etc.)
    └── integration/                # Cross-module integration test suites
```

---

## 2. STRICT ARCHITECTURAL LAYERING

```
+-------------------------------------------------------------+
|                     PRESENTATION LAYER                      |
| (UI Screens, ViewModels/Controllers, Shared Widgets, Theme) |
+-------------------------------------------------------------+
                              ↓
+-------------------------------------------------------------+
|                      APPLICATION LAYER                      |
|     (Use Cases, Workflow Orchestration, State Notifiers)    |
+-------------------------------------------------------------+
                              ↓
+-------------------------------------------------------------+
|                        DOMAIN LAYER                         |
|   (Entities, Business Rules, Value Objects, Error Types)    |
+-------------------------------------------------------------+
                              ↓
+-------------------------------------------------------------+
|                    INFRASTRUCTURE LAYER                     |
|  (Repositories, SQLite/Drift, Sync Outbox, Storage Service) |
+-------------------------------------------------------------+
                              ↓
+-------------------------------------------------------------+
|                       PLATFORM LAYER                        |
|       (OS Platform Adapters: Camera, Printer, Location)     |
+-------------------------------------------------------------+
```

### Inviolable Layering Rules:
1. **Zero Downward Leakage**: Presentation layer widgets NEVER execute raw SQL queries or touch low-level OS file handles.
2. **Domain Isolation**: Domain entities have ZERO Flutter UI framework dependencies.
3. **Dependency Inversion**: Higher layers depend strictly on abstract service/repository interfaces registered in the Dependency Injection container.
4. **No-Branch Absolute Law**: Zero `branch_id`, zero `branches` table, zero multi-branch concepts across all packages.
