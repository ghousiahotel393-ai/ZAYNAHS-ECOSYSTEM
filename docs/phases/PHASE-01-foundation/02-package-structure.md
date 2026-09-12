# PHASE 01 — MONOREPO PACKAGE STRUCTURE

## PACKAGE INVENTORY
```
apps/
  ecosystem_app/       # Main entry point, platform targets (Android, iOS, Windows, Web)
packages/
  core/                # Shared domain primitives, result types, domain errors
  crypto/              # Hash utilities, cryptographic signing, encryption
  database/            # SQLite / Drift engine, repositories, transaction manager
  device/              # Device identity, hardware capabilities, peer models
  discovery/           # LAN mDNS discovery and peer broadcasting
  pairing/             # Cryptographic pairing handshake protocols
  p2p/                 # WebRTC peer connections and DataChannels
  signaling/           # Cloudflare Workers rendezvous client
  sync/                # Sync engine, event log, cursors, conflict handlers
  communication/       # E2E encrypted chat, calls, attachments
  sharing/             # Resumable chunked file transfers, clipboard, links
  location/            # GPS coordinate streaming and ephemeral location
  cctv/                # Camera drivers, segmented recording, timeline playback
  pos/                 # Universal POS engine, product catalog, cart, checkout
  inventory/           # Immutable inventory movement ledger and projections
  customers/           # Customer profiles, credit ledger, dues
  suppliers/           # Supplier management, purchase orders, payables
  payments/            # Multi-wallet engine (Cash, Bank, Online), split payments
  users_access/        # Users, roles, permission resolver, session state
  backup/              # .zynb backup engine, checksums, safe restore
  permissions/         # Deny-by-default RBAC permission checker
  reports/             # Authoritative financial reporting engine, exports
  printing/            # Universal printing pipeline (ESC/POS, PDF, Windows, Web)
  barcode/             # Barcode/QR generator, camera and HID hardware scanner
  storage/             # Unified FileStorageService, safe sandboxed paths
  ui/                  # Shared responsive UI component library
services/
  signaling_worker/    # Cloudflare Worker / Durable Object signaling server
  camera_host/         # Dedicated background camera host daemon
```
