# ZAYNAHS ECOSYSTEM — MASTER DATABASE SCHEMA
# Canonical Schema Definition & Data Dictionary (Version 3.0)

> **Architectural Law & Invariants**  
> 1. **ONE Ecosystem — ZERO Branches**: strictly NO `branch_id`, `branches`, or `branch_manager`.  
> 2. **Immutable Ledgers**: `inventory_movements` and `wallet_transactions` are append-only. Balances are derived.  
> 3. **ACID Checkout**: Sales, line items, stock movements, wallet transactions, audit logs, and sync events are atomic.  
> 4. **SQLite Configuration**: Foreign keys enabled (`PRAGMA foreign_keys = ON;`), Write-Ahead Logging (`PRAGMA journal_mode = WAL;`).

---

## 1. ECOSYSTEM & IDENTITY

### 1.1 `ecosystems`
Single ecosystem root record.
```sql
CREATE TABLE ecosystems (
    id TEXT PRIMARY KEY,                       -- e.g. 'eco_...'
    name TEXT NOT NULL,                        -- Ecosystem display name
    created_at TEXT NOT NULL,                  -- ISO8601 UTC timestamp
    updated_at TEXT NOT NULL,
    settings_json TEXT NOT NULL DEFAULT '{}'   -- Global config and preferences
);
```

### 1.2 `devices`
Trusted peer devices in the decentralized mesh.
```sql
CREATE TABLE devices (
    id TEXT PRIMARY KEY,                       -- e.g. 'dev_...'
    name TEXT NOT NULL,                        -- 'Counter POS 1', 'Owner Laptop', etc.
    trust_status TEXT NOT NULL CHECK(trust_status IN ('PENDING', 'TRUSTED', 'REVOKED', 'BLOCKED')),
    public_key TEXT NOT NULL,                  -- Ed25519 public key
    paired_at TEXT,                            -- ISO8601 UTC timestamp when approved
    last_seen_at TEXT NOT NULL,
    device_type TEXT NOT NULL DEFAULT 'terminal', -- 'desktop', 'tablet', 'phone', 'terminal'
    ip_address TEXT
);
CREATE INDEX idx_devices_trust_status ON devices(trust_status);
```

### 1.3 `users`
System operators and employees.
```sql
CREATE TABLE users (
    id TEXT PRIMARY KEY,                       -- e.g. 'usr_...'
    name TEXT NOT NULL,
    email TEXT UNIQUE NOT NULL,
    role TEXT NOT NULL CHECK(role IN ('Owner', 'Admin', 'Manager', 'Cashier', 'Salesman')),
    password_hash TEXT NOT NULL,               -- Argon2id or PBKDF2 hash
    pin_hash TEXT NOT NULL,                    -- Fast PIN hash for register unlocking
    is_active INTEGER NOT NULL DEFAULT 1 CHECK(is_active IN (0, 1)),
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
);
CREATE INDEX idx_users_role ON users(role);
CREATE INDEX idx_users_is_active ON users(is_active);
```

---

## 2. INVENTORY & PRODUCT CATALOG

### 2.1 `inventory_items`
Master catalog items and pricing definitions.
```sql
CREATE TABLE inventory_items (
    id TEXT PRIMARY KEY,                       -- e.g. 'itm_...'
    sku TEXT UNIQUE NOT NULL,                  -- Stock Keeping Unit
    barcode TEXT,                              -- EAN-13, UPC, Code128, etc.
    name TEXT NOT NULL,
    category TEXT NOT NULL DEFAULT 'General',
    unit TEXT NOT NULL DEFAULT 'pcs',          -- 'pcs', 'kg', 'meter', etc.
    cost_price_minor INTEGER NOT NULL DEFAULT 0 CHECK(cost_price_minor >= 0),
    selling_price_minor INTEGER NOT NULL DEFAULT 0 CHECK(selling_price_minor >= 0),
    min_stock_alert INTEGER NOT NULL DEFAULT 5 CHECK(min_stock_alert >= 0),
    is_active INTEGER NOT NULL DEFAULT 1 CHECK(is_active IN (0, 1)),
    attributes_json TEXT NOT NULL DEFAULT '{}', -- Domain template attributes (clothing, electronics, etc.)
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
);
CREATE INDEX idx_inventory_items_barcode ON inventory_items(barcode);
CREATE INDEX idx_inventory_items_category ON inventory_items(category);
```

### 2.2 `inventory_movements` (IMMUTABLE LEDGER)
Append-only stock ledger. Stock balances are strictly derived from the sum of movements.
```sql
CREATE TABLE inventory_movements (
    id TEXT PRIMARY KEY,                       -- e.g. 'mov_...'
    item_id TEXT NOT NULL REFERENCES inventory_items(id),
    type TEXT NOT NULL CHECK(type IN ('PURCHASE', 'SALE', 'RETURN', 'ADJUSTMENT', 'COUNT')),
    quantity INTEGER NOT NULL CHECK(quantity != 0), -- Positive for stock IN, negative for stock OUT
    cost_price_minor INTEGER NOT NULL DEFAULT 0,
    previous_balance INTEGER NOT NULL,
    new_balance INTEGER NOT NULL,
    reference_id TEXT NOT NULL,                -- sale_id, purchase_id, count_id
    actor_id TEXT NOT NULL REFERENCES users(id),
    device_id TEXT NOT NULL REFERENCES devices(id),
    notes TEXT,
    created_at TEXT NOT NULL                   -- ISO8601 UTC
);
CREATE INDEX idx_inv_movements_item_id ON inventory_movements(item_id);
CREATE INDEX idx_inv_movements_reference_id ON inventory_movements(reference_id);
CREATE INDEX idx_inv_movements_created_at ON inventory_movements(created_at);
```

---

## 3. MULTI-WALLET FINANCIAL LEDGER

### 3.1 `wallets`
Physical and digital monetary accounts (Cash Drawer, Bank Accounts, Online Wallets).
```sql
CREATE TABLE wallets (
    id TEXT PRIMARY KEY,                       -- e.g. 'wal_...'
    name TEXT NOT NULL,                        -- 'Cash Drawer 1', 'Meezan Bank', 'EasyPaisa'
    type TEXT NOT NULL CHECK(type IN ('CASH', 'BANK', 'ONLINE')),
    currency TEXT NOT NULL DEFAULT 'PKR',
    balance_minor INTEGER NOT NULL DEFAULT 0,  -- Cached projection of transactions sum
    is_active INTEGER NOT NULL DEFAULT 1 CHECK(is_active IN (0, 1)),
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
);
CREATE INDEX idx_wallets_type ON wallets(type);
```

### 3.2 `wallet_transactions` (IMMUTABLE FINANCIAL LEDGER)
Append-only money ledger. Wallet balances are strictly verified against transaction totals.
```sql
CREATE TABLE wallet_transactions (
    id TEXT PRIMARY KEY,                       -- e.g. 'wtx_...'
    wallet_id TEXT NOT NULL REFERENCES wallets(id),
    type TEXT NOT NULL CHECK(type IN ('DEPOSIT', 'WITHDRAWAL', 'TRANSFER_IN', 'TRANSFER_OUT', 'SALE_PAYMENT', 'REFUND', 'EXPENSE')),
    amount_minor INTEGER NOT NULL CHECK(amount_minor > 0),
    previous_balance INTEGER NOT NULL,
    new_balance INTEGER NOT NULL,
    reference_id TEXT NOT NULL,                -- sale_id, transfer_id, expense_id
    actor_id TEXT NOT NULL REFERENCES users(id),
    device_id TEXT NOT NULL REFERENCES devices(id),
    notes TEXT,
    created_at TEXT NOT NULL                   -- ISO8601 UTC
);
CREATE INDEX idx_wallet_tx_wallet_id ON wallet_transactions(wallet_id);
CREATE INDEX idx_wallet_tx_reference_id ON wallet_transactions(reference_id);
CREATE INDEX idx_wallet_tx_created_at ON wallet_transactions(created_at);
```

---

## 4. CUSTOMERS & CREDIT (DUE)

### 4.1 `customers`
Customer profiles and store credit / khata accounts.
```sql
CREATE TABLE customers (
    id TEXT PRIMARY KEY,                       -- e.g. 'cus_...'
    name TEXT NOT NULL,
    phone TEXT,
    email TEXT,
    balance_minor INTEGER NOT NULL DEFAULT 0,  -- Positive = customer owes business (due/receivable)
    credit_limit_minor INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
);
CREATE INDEX idx_customers_phone ON customers(phone);
```

---

## 5. UNIVERSAL POS SALES

### 5.1 `sales`
Completed checkout invoices.
```sql
CREATE TABLE sales (
    id TEXT PRIMARY KEY,                       -- e.g. 'sale_...'
    invoice_number TEXT UNIQUE NOT NULL,       -- Sequential receipt code (e.g. 'INV-20260912-001')
    subtotal_minor INTEGER NOT NULL CHECK(subtotal_minor >= 0),
    discount_minor INTEGER NOT NULL DEFAULT 0 CHECK(discount_minor >= 0),
    tax_minor INTEGER NOT NULL DEFAULT 0 CHECK(tax_minor >= 0),
    grand_total_minor INTEGER NOT NULL CHECK(grand_total_minor >= 0),
    paid_amount_minor INTEGER NOT NULL DEFAULT 0 CHECK(paid_amount_minor >= 0),
    due_amount_minor INTEGER NOT NULL DEFAULT 0 CHECK(due_amount_minor >= 0),
    payment_status TEXT NOT NULL CHECK(payment_status IN ('PAID', 'PARTIAL', 'UNPAID')),
    customer_id TEXT REFERENCES customers(id),
    actor_id TEXT NOT NULL REFERENCES users(id),
    device_id TEXT NOT NULL REFERENCES devices(id),
    created_at TEXT NOT NULL                   -- ISO8601 UTC
);
CREATE INDEX idx_sales_invoice_number ON sales(invoice_number);
CREATE INDEX idx_sales_customer_id ON sales(customer_id);
CREATE INDEX idx_sales_created_at ON sales(created_at);
```

### 5.2 `sale_items`
Line items for each sale with historical cost price snapshot.
```sql
CREATE TABLE sale_items (
    id TEXT PRIMARY KEY,                       -- e.g. 'sli_...'
    sale_id TEXT NOT NULL REFERENCES sales(id) ON DELETE CASCADE,
    item_id TEXT NOT NULL REFERENCES inventory_items(id),
    item_name_snapshot TEXT NOT NULL,
    quantity INTEGER NOT NULL CHECK(quantity > 0),
    unit_price_minor INTEGER NOT NULL CHECK(unit_price_minor >= 0),
    cost_price_snapshot_minor INTEGER NOT NULL CHECK(cost_price_snapshot_minor >= 0),
    total_price_minor INTEGER NOT NULL CHECK(total_price_minor >= 0),
    attributes_json TEXT NOT NULL DEFAULT '{}' -- Snapshotted item variant/custom attributes
);
CREATE INDEX idx_sale_items_sale_id ON sale_items(sale_id);
CREATE INDEX idx_sale_items_item_id ON sale_items(item_id);
```

### 5.3 `sale_payments`
Multi-wallet split payment allocations for completed sales.
```sql
CREATE TABLE sale_payments (
    id TEXT PRIMARY KEY,                       -- e.g. 'spm_...'
    sale_id TEXT NOT NULL REFERENCES sales(id) ON DELETE CASCADE,
    wallet_id TEXT NOT NULL REFERENCES wallets(id),
    amount_minor INTEGER NOT NULL CHECK(amount_minor > 0),
    created_at TEXT NOT NULL                   -- ISO8601 UTC
);
CREATE INDEX idx_sale_payments_sale_id ON sale_payments(sale_id);
CREATE INDEX idx_sale_payments_wallet_id ON sale_payments(wallet_id);
```

### 5.4 `returns`
Authoritative sales return master records.
```sql
CREATE TABLE returns (
    id TEXT PRIMARY KEY,                       -- e.g. 'ret_...'
    return_number TEXT UNIQUE NOT NULL,        -- e.g. 'RET-20260912-001'
    sale_id TEXT NOT NULL REFERENCES sales(id),
    total_refund_minor INTEGER NOT NULL CHECK(total_refund_minor >= 0),
    reason TEXT,
    actor_id TEXT NOT NULL REFERENCES users(id),
    device_id TEXT NOT NULL REFERENCES devices(id),
    created_at TEXT NOT NULL                   -- ISO8601 UTC
);
CREATE INDEX idx_returns_sale_id ON returns(sale_id);
CREATE INDEX idx_returns_return_number ON returns(return_number);
```

### 5.5 `return_items`
Individual line items returned with restored stock and refund allocation.
```sql
CREATE TABLE return_items (
    id TEXT PRIMARY KEY,                       -- e.g. 'rti_...'
    return_id TEXT NOT NULL REFERENCES returns(id) ON DELETE CASCADE,
    item_id TEXT NOT NULL REFERENCES inventory_items(id),
    quantity INTEGER NOT NULL CHECK(quantity > 0),
    refund_amount_minor INTEGER NOT NULL CHECK(refund_amount_minor >= 0)
);
CREATE INDEX idx_return_items_return_id ON return_items(return_id);
CREATE INDEX idx_return_items_item_id ON return_items(item_id);
```

### 5.6 `return_payments`
Refund allocations disbursed across wallets (Cash, Bank, Online).
```sql
CREATE TABLE return_payments (
    id TEXT PRIMARY KEY,                       -- e.g. 'rpm_...'
    return_id TEXT NOT NULL REFERENCES returns(id) ON DELETE CASCADE,
    wallet_id TEXT NOT NULL REFERENCES wallets(id),
    amount_minor INTEGER NOT NULL CHECK(amount_minor > 0),
    created_at TEXT NOT NULL                   -- ISO8601 UTC
);
CREATE INDEX idx_return_payments_return_id ON return_payments(return_id);
CREATE INDEX idx_return_payments_wallet_id ON return_payments(wallet_id);
```

---

## 6. DURABLE SYNC ENGINE

### 6.1 `sync_outbox`
Local durable event queue for event-driven peer synchronization.
```sql
CREATE TABLE sync_outbox (
    id TEXT PRIMARY KEY,                       -- e.g. 'evt_...'
    event_type TEXT NOT NULL,                  -- 'INSERT', 'UPDATE', 'DELETE'
    entity_table TEXT NOT NULL,                -- 'sales', 'inventory_movements', etc.
    entity_id TEXT NOT NULL,
    payload_json TEXT NOT NULL,
    device_id TEXT NOT NULL REFERENCES devices(id),
    status TEXT NOT NULL DEFAULT 'PENDING' CHECK(status IN ('PENDING', 'SENT', 'ACKNOWLEDGED', 'FAILED')),
    retry_count INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL,
    user_id TEXT REFERENCES users(id),
    logical_version INTEGER NOT NULL DEFAULT 1,
    hash TEXT,                                 -- SHA-256 integrity hash
    signature TEXT                             -- Ed25519 device signature
);
CREATE INDEX idx_sync_outbox_status ON sync_outbox(status);
CREATE INDEX idx_sync_outbox_created_at ON sync_outbox(created_at);
CREATE INDEX idx_sync_outbox_device_status ON sync_outbox(device_id, status);
```

### 6.2 `sync_cursors`
Vector clock and peer acknowledge checkpoints.
```sql
CREATE TABLE sync_cursors (
    peer_device_id TEXT PRIMARY KEY REFERENCES devices(id),
    last_received_event_id TEXT,
    last_acked_event_id TEXT,
    last_sync_timestamp TEXT NOT NULL
);
```

### 6.3 `sync_conflicts`
Transparent conflict preservation log (Strict NO Last-Write-Wins rule). Exposes conflicting concurrent modifications for domain resolution without data loss.
```sql
CREATE TABLE sync_conflicts (
    id TEXT PRIMARY KEY,                       -- e.g. 'cnf_...'
    entity_table TEXT NOT NULL,
    entity_id TEXT NOT NULL,
    local_event_id TEXT REFERENCES sync_outbox(id),
    remote_event_id TEXT NOT NULL,
    conflict_type TEXT NOT NULL,
    conflict_data_json TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'UNRESOLVED' CHECK(status IN ('UNRESOLVED', 'RESOLVED', 'IGNORED')),
    created_at TEXT NOT NULL
);
CREATE INDEX idx_sync_conflicts_status ON sync_conflicts(status);
CREATE INDEX idx_sync_conflicts_entity ON sync_conflicts(entity_table, entity_id);
```

---

## 7. AUDIT LOGGING & COMPLIANCE

### 7.1 `audit_logs`
Cryptographically chained, immutable audit events.
```sql
CREATE TABLE audit_logs (
    id TEXT PRIMARY KEY,                       -- e.g. 'aud_...'
    timestamp TEXT NOT NULL,                   -- ISO8601 UTC
    level TEXT NOT NULL,                       -- 'INFO', 'WARN', 'AUDIT', 'SECURITY'
    action TEXT NOT NULL,                      -- 'SALE_CREATED', 'DEVICE_TRUSTED', 'WALLET_TRANSFER'
    actor_id TEXT NOT NULL,
    device_id TEXT NOT NULL,
    entity_type TEXT,                          -- 'sale', 'wallet', 'device'
    entity_id TEXT,
    details_json TEXT NOT NULL,
    previous_hash TEXT,                        -- Chained hash of previous log entry
    entry_hash TEXT NOT NULL                   -- SHA-256 (id + timestamp + action + actor + details + prevHash)
);
CREATE INDEX idx_audit_logs_timestamp ON audit_logs(timestamp);
CREATE INDEX idx_audit_logs_action ON audit_logs(action);
CREATE INDEX idx_audit_logs_actor_id ON audit_logs(actor_id);
```

---

## 8. STORAGE & CONTENT DEDUPLICATION

### 8.1 `storage_files`
Content-addressable storage catalog for deduplicated files, product images, and media attachments.
```sql
CREATE TABLE storage_files (
    id TEXT PRIMARY KEY,                       -- e.g. 'fil_...'
    category TEXT NOT NULL,                    -- 'media_products', 'cctv_recordings', etc.
    file_name TEXT NOT NULL,                   -- Original filename
    file_path TEXT NOT NULL,                   -- Relative path on local disk
    sha256_hash TEXT NOT NULL,                 -- Hex-encoded SHA-256 digest
    file_size_bytes INTEGER NOT NULL,          -- Size in bytes
    mime_type TEXT NOT NULL DEFAULT 'application/octet-stream',
    reference_count INTEGER NOT NULL DEFAULT 1,-- Incremented when shared; decremented on delete
    created_at TEXT NOT NULL                   -- ISO8601 UTC
);
CREATE INDEX idx_storage_files_sha256 ON storage_files(sha256_hash);
CREATE INDEX idx_storage_files_category ON storage_files(category);
```

---

## 9. MASTER SCHEMA VERSION TRACKING
- Current Schema Version: `4` (`PRAGMA user_version = 4;`).
- Migrations History:
  - `v1`: Core ecosystem, devices, users, inventory, wallets, customers, sales, sync, audit.
  - `v2`: Storage content deduplication catalog (`storage_files`).
  - `v3`: Event sync metadata columns on `sync_outbox`, `sync_conflicts` table, and dispatch indexes.
  - `v4`: Domain template attributes (`attributes_json`), split payment allocations (`sale_payments`), and returns engine (`returns`, `return_items`, `return_payments`).
