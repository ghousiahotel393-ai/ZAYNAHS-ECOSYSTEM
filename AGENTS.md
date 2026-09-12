# ZAYNAHS ECOSYSTEM — AI CODING AGENT MASTER RULES
# Production Engineering Contract & Master Index

> **Master Architecture & Engineering Standards**  
> All 200 rules of the Zaynahs Ecosystem Engineering Contract are divided into atomic, small, focused specification files under [`docs/agents/`](docs/agents/).  
> Implementation phases are modularized under [`docs/phases/`](docs/phases/).

---

## 1. CORE EXECUTIVE CONTRACT

The AI coding agent behaves as a **Senior Principal Software Engineer & Architect**. Production completion requires full impact verification across all layers—not merely a working UI button or mock.

### Strict Priority Order:
1. **Data integrity** (Immutable financial & inventory ledgers)
2. **Security & Privacy** (Default-deny RBAC, device trust, no covert capture)
3. **Correct business behavior** (One universal POS engine)
4. **Offline reliability** (Full operational capability without internet)
5. **Sync correctness** (Event-driven, no Last-Write-Wins)
6. **Failure recovery** (Zero-corruption on crash or power loss)
7. **Performance** (Bounded streams, isolates, paginated queries)
8. **User experience** (Clean, responsive across phone, tablet, desktop, web)
9. **Maintainability** (Modular monorepo, strict layering)
10. **Code aesthetics** (Readable, typed, idiomatic)

---

## 2. ABSOLUTE ARCHITECTURAL LAWS

1. **ONE Ecosystem — ZERO Branches**:
   - Never introduce `branch_id`, `branches`, `branch_manager`, or branch inventory.
   - Devices are independent peers, **NOT** branches.
2. **Trusted Peer Device Model**:
   - Devices have local databases and event ledgers. They operate offline and synchronize later.
3. **Ledgers as Authoritative Truth**:
   - Inventory is derived from immutable movement events.
   - Wallets are derived from immutable transaction entries.
   - Sales are atomic transactions (Sale + Items + Stock OUT + Payments + Wallet IN + Customer Due + Audit + Sync).
4. **No Fake Core / No Placeholders**:
   - Never ship fake cameras, mock recordings, fake sync success, or unverified backups. Mocks belong only in tests.

---

## 3. MODULAR ATOMIC RULES INDEX (`docs/agents/`)

Every rule from #1 to #200 is divided into dedicated, small, readable files:

| # | Spec Document | Scope & Rule Numbers |
|---|---|---|
| 01 | [**01-purpose-and-priorities.md**](docs/agents/01-purpose-and-priorities.md) | Purpose of ecosystem & non-negotiable priority hierarchy (Rules 1–2) |
| 02 | [**02-architecture-no-branch.md**](docs/agents/02-architecture-no-branch.md) | Single ecosystem law, absolute no-branch rule, trusted peer devices (Rules 3–5) |
| 03 | [**03-operating-mode-inspect.md**](docs/agents/03-operating-mode-inspect.md) | 9-step workflow, inspect before modifying, 360° impact analysis, DoD (Rules 6–12) |
| 04 | [**04-architecture-layers.md**](docs/agents/04-architecture-layers.md) | Presentation, Application, Domain, Infrastructure, Platform layers, shared components (Rules 13–22) |
| 05 | [**05-universal-pos-rules.md**](docs/agents/05-universal-pos-rules.md) | Universal POS engine, ledger source of truth, immutable inventory formula (Rules 23–26) |
| 06 | [**06-wallets-and-payments.md**](docs/agents/06-wallets-and-payments.md) | Cash/Bank/Online wallets, wallet transfers, split payments, checkout atomicity (Rules 27–36) |
| 07 | [**07-sync-architecture.md**](docs/agents/07-sync-architecture.md) | Event-driven sync, durable persistence, ACK rules, cursors, conflict handling (Rules 37–46) |
| 08 | [**08-offline-and-network.md**](docs/agents/08-offline-and-network.md) | Offline-first operations, LAN/P2P architecture, chunked file transfer protocol (Rules 47–53) |
| 09 | [**09-media-privacy-cctv.md**](docs/agents/09-media-privacy-cctv.md) | Camera/mic/location/screen sharing privacy & CCTV segmented recording (Rules 54–65) |
| 10 | [**10-device-trust-lifecycle.md**](docs/agents/10-device-trust-lifecycle.md) | Device trust lifecycle: PENDING, TRUSTED, REVOKED, BLOCKED (Rules 66–68) |
| 11 | [**11-permissions-rbac.md**](docs/agents/11-permissions-rbac.md) | Deny-by-default permission resolver, roles (Owner, Admin, Manager, Cashier, Salesman) (Rules 69–78) |
| 12 | [**12-audit-and-secrets.md**](docs/agents/12-audit-and-secrets.md) | Structured audit logging & absolute prohibition on logging secrets (Rules 79–80) |
| 13 | [**13-database-and-migrations.md**](docs/agents/13-database-and-migrations.md) | Repositories, atomic DB transactions, schema migrations, MASTER_SCHEMA (Rules 81–85) |
| 14 | [**14-backup-and-restore.md**](docs/agents/14-backup-and-restore.md) | .zynb backup archive, safe restore protocol, projection rebuilds (Rules 86–91) |
| 15 | [**15-reports-and-printing.md**](docs/agents/15-reports-and-printing.md) | Authoritative reports, streaming exports, thermal ESC/POS printing, barcode standards (Rules 92–96) |
| 16 | [**16-settings-and-storage.md**](docs/agents/16-settings-and-storage.md) | Settings hierarchy & FileStorageService filesystem abstraction (Rules 97–98) |
| 17 | [**17-performance-and-memory.md**](docs/agents/17-performance-and-memory.md) | Pagination, bounded buffers, memory safety, isolate workers (Rules 99–105) |
| 18 | [**18-error-handling-deep-links.md**](docs/agents/18-error-handling-deep-links.md) | Typed domain errors, deep links security, responsive UI, platform adapters (Rules 106–119) |
| 19 | [**19-testing-and-golden-tests.md**](docs/agents/19-testing-and-golden-tests.md) | Full testing categories & Master Golden Tests (POS, Multi-Device, Backup, Security, File, CCTV) (Rules 120–135) |
| 20 | [**20-code-quality-and-reconciliation.md**](docs/agents/20-code-quality-and-reconciliation.md) | Code quality standards, ledger reconciliation, git etiquette, deployment (Rules 136–160) |
| 21 | [**21-production-contract-and-gates.md**](docs/agents/21-production-contract-and-gates.md) | Review checklists, stop conditions, quality gates, absolute prohibitions, final contract (Rules 161–200) |

---

## 4. MASTER IMPLEMENTATION PHASES (`docs/phases/`)

Implementation proceeds 1-by-1 through the small modular files in [`docs/phases/`](docs/phases/):

* [**PHASE-00: Repository Audit**](docs/phases/PHASE-00-repository-audit/) — Comprehensive inspection, architecture mapping (Zero code changes)
* [**PHASE-01: Foundation (Architecture Base)**](docs/phases/PHASE-01-foundation/) — **Permanent Architecture Base** (Packages, DI, routing, theme, logging, platform adapters, shared UI)
* [**PHASE-02: Database Foundation**](docs/phases/PHASE-02-database/) — Local SQLite/Drift DB, core schemas, migrations, repositories, transactions
* [**PHASE-03: Identity & Devices**](docs/phases/PHASE-03-identity-devices/) — Users, roles, permission resolver, device trust lifecycle, pairing protocol
* [**PHASE-04: Storage & File Foundation**](docs/phases/PHASE-04-storage-file/) — FileStorageService, directory taxonomy, chunked streaming, deduplication
* [**PHASE-05: Event & Sync Foundation**](docs/phases/PHASE-05-sync-events/) — Event-driven sync, durable outbox, cursors, conflict preservation (NO LWW)
* [**PHASE-06: P2P & WebRTC Foundation**](docs/phases/PHASE-06-p2p-webrtc/) — LAN mDNS discovery, Cloudflare Workers signaling, WebRTC DataChannels, STUN/TURN
* [**PHASE-07: Communication & Collaboration**](docs/phases/PHASE-07-communication/) — E2E chat, resumable file transfer (Golden Test 104), calls, screen sharing
* [**PHASE-08: Universal POS Foundation**](docs/phases/PHASE-08-pos-core/) — **ONE POS Engine**, immutable inventory movements, multi-wallet ledger, Golden Test 100
* [**PHASE-09: Advanced POS & Supply Chain**](docs/phases/PHASE-09-pos-advanced/) — Discounts, taxes, barcode/QR engine, ESC/POS & PDF printing, procurement, stock counts
* [**PHASE-10: Financial Reports & Analytics**](docs/phases/PHASE-10-reports/) — Authoritative reporting engine, P&L, register shift closeouts, streaming exports
* [**PHASE-11: CCTV Monitoring & Recording**](docs/phases/PHASE-11-cctv/) — USB/IP/RTSP cameras, segmented recording (1-5m), timeline playback, Golden Test 105
* [**PHASE-12: Backup & Disaster Recovery**](docs/phases/PHASE-12-backup-restore/) — Verifiable `.zynb` archives, mandatory pre-restore snapshot, projection rebuilds, Golden Test 102
* [**PHASE-13: System Hardening & Audit**](docs/phases/PHASE-13-hardening/) — Security audit, RBAC penetration, memory leak profiling, zero secrets, Golden Test 103
* [**PHASE-14: Cross-Platform Verification**](docs/phases/PHASE-14-cross-platform/) — Android, iOS, Windows, and Web builds; responsive layout verification
* [**PHASE-15: Production Validation & Sign-Off**](docs/phases/PHASE-15-production-validation/) — Master Golden Test battery (100–105), 24h soak tests, final production sign-off