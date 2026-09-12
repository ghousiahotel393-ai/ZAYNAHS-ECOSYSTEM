/// Schema Version 1 DDL for Zaynahs Ecosystem SQLite Database.
/// Exactly implements MASTER_SCHEMA.md.
library schema_v1;

class SchemaV1 {
  static const int version = 1;

  static const List<String> ddlStatements = [
    // 1. Ecosystems
    '''
    CREATE TABLE IF NOT EXISTS ecosystems (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      settings_json TEXT NOT NULL DEFAULT '{}'
    );
    ''',

    // 2. Devices (Trusted Peers)
    '''
    CREATE TABLE IF NOT EXISTS devices (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      trust_status TEXT NOT NULL CHECK(trust_status IN ('PENDING', 'TRUSTED', 'REVOKED', 'BLOCKED')),
      public_key TEXT NOT NULL,
      paired_at TEXT,
      last_seen_at TEXT NOT NULL,
      device_type TEXT NOT NULL DEFAULT 'terminal',
      ip_address TEXT
    );
    ''',
    'CREATE INDEX IF NOT EXISTS idx_devices_trust_status ON devices(trust_status);',

    // 3. Users
    '''
    CREATE TABLE IF NOT EXISTS users (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      email TEXT UNIQUE NOT NULL,
      role TEXT NOT NULL CHECK(role IN ('Owner', 'Admin', 'Manager', 'Cashier', 'Salesman')),
      password_hash TEXT NOT NULL,
      pin_hash TEXT NOT NULL,
      is_active INTEGER NOT NULL DEFAULT 1 CHECK(is_active IN (0, 1)),
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    );
    ''',
    'CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);',
    'CREATE INDEX IF NOT EXISTS idx_users_is_active ON users(is_active);',

    // 4. Inventory Items
    '''
    CREATE TABLE IF NOT EXISTS inventory_items (
      id TEXT PRIMARY KEY,
      sku TEXT UNIQUE NOT NULL,
      barcode TEXT,
      name TEXT NOT NULL,
      category TEXT NOT NULL DEFAULT 'General',
      unit TEXT NOT NULL DEFAULT 'pcs',
      cost_price_minor INTEGER NOT NULL DEFAULT 0 CHECK(cost_price_minor >= 0),
      selling_price_minor INTEGER NOT NULL DEFAULT 0 CHECK(selling_price_minor >= 0),
      min_stock_alert INTEGER NOT NULL DEFAULT 5 CHECK(min_stock_alert >= 0),
      is_active INTEGER NOT NULL DEFAULT 1 CHECK(is_active IN (0, 1)),
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    );
    ''',
    'CREATE INDEX IF NOT EXISTS idx_inventory_items_barcode ON inventory_items(barcode);',
    'CREATE INDEX IF NOT EXISTS idx_inventory_items_category ON inventory_items(category);',

    // 5. Inventory Movements (Immutable Ledger)
    '''
    CREATE TABLE IF NOT EXISTS inventory_movements (
      id TEXT PRIMARY KEY,
      item_id TEXT NOT NULL REFERENCES inventory_items(id),
      type TEXT NOT NULL CHECK(type IN ('PURCHASE', 'SALE', 'RETURN', 'ADJUSTMENT', 'COUNT')),
      quantity INTEGER NOT NULL CHECK(quantity != 0),
      cost_price_minor INTEGER NOT NULL DEFAULT 0,
      previous_balance INTEGER NOT NULL,
      new_balance INTEGER NOT NULL,
      reference_id TEXT NOT NULL,
      actor_id TEXT NOT NULL REFERENCES users(id),
      device_id TEXT NOT NULL REFERENCES devices(id),
      notes TEXT,
      created_at TEXT NOT NULL
    );
    ''',
    'CREATE INDEX IF NOT EXISTS idx_inv_movements_item_id ON inventory_movements(item_id);',
    'CREATE INDEX IF NOT EXISTS idx_inv_movements_reference_id ON inventory_movements(reference_id);',
    'CREATE INDEX IF NOT EXISTS idx_inv_movements_created_at ON inventory_movements(created_at);',

    // 6. Wallets
    '''
    CREATE TABLE IF NOT EXISTS wallets (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      type TEXT NOT NULL CHECK(type IN ('CASH', 'BANK', 'ONLINE')),
      currency TEXT NOT NULL DEFAULT 'PKR',
      balance_minor INTEGER NOT NULL DEFAULT 0,
      is_active INTEGER NOT NULL DEFAULT 1 CHECK(is_active IN (0, 1)),
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    );
    ''',
    'CREATE INDEX IF NOT EXISTS idx_wallets_type ON wallets(type);',

    // 7. Wallet Transactions (Immutable Financial Ledger)
    '''
    CREATE TABLE IF NOT EXISTS wallet_transactions (
      id TEXT PRIMARY KEY,
      wallet_id TEXT NOT NULL REFERENCES wallets(id),
      type TEXT NOT NULL CHECK(type IN ('DEPOSIT', 'WITHDRAWAL', 'TRANSFER_IN', 'TRANSFER_OUT', 'SALE_PAYMENT', 'REFUND', 'EXPENSE')),
      amount_minor INTEGER NOT NULL CHECK(amount_minor > 0),
      previous_balance INTEGER NOT NULL,
      new_balance INTEGER NOT NULL,
      reference_id TEXT NOT NULL,
      actor_id TEXT NOT NULL REFERENCES users(id),
      device_id TEXT NOT NULL REFERENCES devices(id),
      notes TEXT,
      created_at TEXT NOT NULL
    );
    ''',
    'CREATE INDEX IF NOT EXISTS idx_wallet_tx_wallet_id ON wallet_transactions(wallet_id);',
    'CREATE INDEX IF NOT EXISTS idx_wallet_tx_reference_id ON wallet_transactions(reference_id);',
    'CREATE INDEX IF NOT EXISTS idx_wallet_tx_created_at ON wallet_transactions(created_at);',

    // 8. Customers
    '''
    CREATE TABLE IF NOT EXISTS customers (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      phone TEXT,
      email TEXT,
      balance_minor INTEGER NOT NULL DEFAULT 0,
      credit_limit_minor INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    );
    ''',
    'CREATE INDEX IF NOT EXISTS idx_customers_phone ON customers(phone);',

    // 9. Sales
    '''
    CREATE TABLE IF NOT EXISTS sales (
      id TEXT PRIMARY KEY,
      invoice_number TEXT UNIQUE NOT NULL,
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
      created_at TEXT NOT NULL
    );
    ''',
    'CREATE INDEX IF NOT EXISTS idx_sales_invoice_number ON sales(invoice_number);',
    'CREATE INDEX IF NOT EXISTS idx_sales_customer_id ON sales(customer_id);',
    'CREATE INDEX IF NOT EXISTS idx_sales_created_at ON sales(created_at);',

    // 10. Sale Items
    '''
    CREATE TABLE IF NOT EXISTS sale_items (
      id TEXT PRIMARY KEY,
      sale_id TEXT NOT NULL REFERENCES sales(id) ON DELETE CASCADE,
      item_id TEXT NOT NULL REFERENCES inventory_items(id),
      item_name_snapshot TEXT NOT NULL,
      quantity INTEGER NOT NULL CHECK(quantity > 0),
      unit_price_minor INTEGER NOT NULL CHECK(unit_price_minor >= 0),
      cost_price_snapshot_minor INTEGER NOT NULL CHECK(cost_price_snapshot_minor >= 0),
      total_price_minor INTEGER NOT NULL CHECK(total_price_minor >= 0)
    );
    ''',
    'CREATE INDEX IF NOT EXISTS idx_sale_items_sale_id ON sale_items(sale_id);',
    'CREATE INDEX IF NOT EXISTS idx_sale_items_item_id ON sale_items(item_id);',

    // 11. Sync Outbox & Cursors
    '''
    CREATE TABLE IF NOT EXISTS sync_outbox (
      id TEXT PRIMARY KEY,
      event_type TEXT NOT NULL,
      entity_table TEXT NOT NULL,
      entity_id TEXT NOT NULL,
      payload_json TEXT NOT NULL,
      device_id TEXT NOT NULL REFERENCES devices(id),
      status TEXT NOT NULL DEFAULT 'PENDING' CHECK(status IN ('PENDING', 'SENT', 'ACKNOWLEDGED', 'FAILED')),
      retry_count INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL
    );
    ''',
    'CREATE INDEX IF NOT EXISTS idx_sync_outbox_status ON sync_outbox(status);',
    'CREATE INDEX IF NOT EXISTS idx_sync_outbox_created_at ON sync_outbox(created_at);',
    '''
    CREATE TABLE IF NOT EXISTS sync_cursors (
      peer_device_id TEXT PRIMARY KEY REFERENCES devices(id),
      last_received_event_id TEXT,
      last_acked_event_id TEXT,
      last_sync_timestamp TEXT NOT NULL
    );
    ''',

    // 12. Audit Logs
    '''
    CREATE TABLE IF NOT EXISTS audit_logs (
      id TEXT PRIMARY KEY,
      timestamp TEXT NOT NULL,
      level TEXT NOT NULL,
      action TEXT NOT NULL,
      actor_id TEXT NOT NULL,
      device_id TEXT NOT NULL,
      entity_type TEXT,
      entity_id TEXT,
      details_json TEXT NOT NULL,
      previous_hash TEXT,
      entry_hash TEXT NOT NULL
    );
    ''',
    'CREATE INDEX IF NOT EXISTS idx_audit_logs_timestamp ON audit_logs(timestamp);',
    'CREATE INDEX IF NOT EXISTS idx_audit_logs_action ON audit_logs(action);',
    'CREATE INDEX IF NOT EXISTS idx_audit_logs_actor_id ON audit_logs(actor_id);',
  ];
}
