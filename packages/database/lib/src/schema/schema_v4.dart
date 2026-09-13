/// Schema Version 4 DDL for Zaynahs Ecosystem SQLite Database.
/// Implements Phase 08: Universal POS Foundation.
/// Adds attributes_json to catalog/sales items, sale_payments for split tenders,
/// and returns / return_items / return_payments for authoritative refund tracking.
library schema_v4;

class SchemaV4 {
  static const int version = 4;

  static const List<String> ddlStatements = [
    // 1. Add attributes_json to inventory_items for business domain templates
    "ALTER TABLE inventory_items ADD COLUMN attributes_json TEXT NOT NULL DEFAULT '{}';",

    // 2. Add attributes_json to sale_items for historical line item customization snapshots
    "ALTER TABLE sale_items ADD COLUMN attributes_json TEXT NOT NULL DEFAULT '{}';",

    // 3. Split Payment Allocations Table
    '''
    CREATE TABLE IF NOT EXISTS sale_payments (
      id TEXT PRIMARY KEY,
      sale_id TEXT NOT NULL REFERENCES sales(id) ON DELETE CASCADE,
      wallet_id TEXT NOT NULL REFERENCES wallets(id),
      amount_minor INTEGER NOT NULL CHECK(amount_minor > 0),
      created_at TEXT NOT NULL
    );
    ''',
    'CREATE INDEX IF NOT EXISTS idx_sale_payments_sale_id ON sale_payments(sale_id);',
    'CREATE INDEX IF NOT EXISTS idx_sale_payments_wallet_id ON sale_payments(wallet_id);',

    // 4. Returns Master Table
    '''
    CREATE TABLE IF NOT EXISTS returns (
      id TEXT PRIMARY KEY,
      return_number TEXT UNIQUE NOT NULL,
      sale_id TEXT NOT NULL REFERENCES sales(id),
      total_refund_minor INTEGER NOT NULL CHECK(total_refund_minor >= 0),
      reason TEXT,
      actor_id TEXT NOT NULL REFERENCES users(id),
      device_id TEXT NOT NULL REFERENCES devices(id),
      created_at TEXT NOT NULL
    );
    ''',
    'CREATE INDEX IF NOT EXISTS idx_returns_sale_id ON returns(sale_id);',
    'CREATE INDEX IF NOT EXISTS idx_returns_return_number ON returns(return_number);',

    // 5. Return Items Line Items Table
    '''
    CREATE TABLE IF NOT EXISTS return_items (
      id TEXT PRIMARY KEY,
      return_id TEXT NOT NULL REFERENCES returns(id) ON DELETE CASCADE,
      item_id TEXT NOT NULL REFERENCES inventory_items(id),
      quantity INTEGER NOT NULL CHECK(quantity > 0),
      refund_amount_minor INTEGER NOT NULL CHECK(refund_amount_minor >= 0)
    );
    ''',
    'CREATE INDEX IF NOT EXISTS idx_return_items_return_id ON return_items(return_id);',
    'CREATE INDEX IF NOT EXISTS idx_return_items_item_id ON return_items(item_id);',

    // 6. Return Refund Payment Allocations Table
    '''
    CREATE TABLE IF NOT EXISTS return_payments (
      id TEXT PRIMARY KEY,
      return_id TEXT NOT NULL REFERENCES returns(id) ON DELETE CASCADE,
      wallet_id TEXT NOT NULL REFERENCES wallets(id),
      amount_minor INTEGER NOT NULL CHECK(amount_minor > 0),
      created_at TEXT NOT NULL
    );
    ''',
    'CREATE INDEX IF NOT EXISTS idx_return_payments_return_id ON return_payments(return_id);',
    'CREATE INDEX IF NOT EXISTS idx_return_payments_wallet_id ON return_payments(wallet_id);',
  ];
}
