/// Schema Version 5 DDL for Zaynahs Ecosystem SQLite Database.
/// Implements Phase 09: Advanced POS & Supply Chain.
/// Adds suppliers, purchase orders, purchase order items, and physical stock count audit tables.
library schema_v5;

class SchemaV5 {
  static const int version = 5;

  static const List<String> ddlStatements = [
    // 1. Suppliers Table
    '''
    CREATE TABLE IF NOT EXISTS suppliers (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      phone TEXT,
      email TEXT,
      company TEXT,
      balance_minor INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    );
    ''',
    'CREATE INDEX IF NOT EXISTS idx_suppliers_name ON suppliers(name);',

    // 2. Purchase Orders Table
    '''
    CREATE TABLE IF NOT EXISTS purchase_orders (
      id TEXT PRIMARY KEY,
      po_number TEXT UNIQUE NOT NULL,
      supplier_id TEXT NOT NULL REFERENCES suppliers(id),
      total_minor INTEGER NOT NULL CHECK(total_minor >= 0),
      paid_minor INTEGER NOT NULL DEFAULT 0 CHECK(paid_minor >= 0),
      status TEXT NOT NULL CHECK(status IN ('DRAFT', 'ORDERED', 'RECEIVED', 'CANCELLED')),
      actor_id TEXT NOT NULL REFERENCES users(id),
      device_id TEXT NOT NULL REFERENCES devices(id),
      created_at TEXT NOT NULL
    );
    ''',
    'CREATE INDEX IF NOT EXISTS idx_purchase_orders_po_number ON purchase_orders(po_number);',
    'CREATE INDEX IF NOT EXISTS idx_purchase_orders_supplier_id ON purchase_orders(supplier_id);',

    // 3. Purchase Order Items Table
    '''
    CREATE TABLE IF NOT EXISTS purchase_order_items (
      id TEXT PRIMARY KEY,
      po_id TEXT NOT NULL REFERENCES purchase_orders(id) ON DELETE CASCADE,
      item_id TEXT NOT NULL REFERENCES inventory_items(id),
      quantity INTEGER NOT NULL CHECK(quantity > 0),
      unit_cost_minor INTEGER NOT NULL CHECK(unit_cost_minor >= 0)
    );
    ''',
    'CREATE INDEX IF NOT EXISTS idx_po_items_po_id ON purchase_order_items(po_id);',
    'CREATE INDEX IF NOT EXISTS idx_po_items_item_id ON purchase_order_items(item_id);',

    // 4. Physical Stock Counts Table (Rule 51 Audits)
    '''
    CREATE TABLE IF NOT EXISTS stock_counts (
      id TEXT PRIMARY KEY,
      count_number TEXT UNIQUE NOT NULL,
      status TEXT NOT NULL CHECK(status IN ('IN_PROGRESS', 'COMPLETED', 'CANCELLED')),
      notes TEXT,
      actor_id TEXT NOT NULL REFERENCES users(id),
      device_id TEXT NOT NULL REFERENCES devices(id),
      created_at TEXT NOT NULL,
      completed_at TEXT
    );
    ''',
    'CREATE INDEX IF NOT EXISTS idx_stock_counts_count_number ON stock_counts(count_number);',
    'CREATE INDEX IF NOT EXISTS idx_stock_counts_status ON stock_counts(status);',

    // 5. Stock Count Items Table
    '''
    CREATE TABLE IF NOT EXISTS stock_count_items (
      id TEXT PRIMARY KEY,
      count_id TEXT NOT NULL REFERENCES stock_counts(id) ON DELETE CASCADE,
      item_id TEXT NOT NULL REFERENCES inventory_items(id),
      expected_quantity INTEGER NOT NULL,
      counted_quantity INTEGER NOT NULL,
      variance INTEGER NOT NULL
    );
    ''',
    'CREATE INDEX IF NOT EXISTS idx_stock_count_items_count_id ON stock_count_items(count_id);',
    'CREATE INDEX IF NOT EXISTS idx_stock_count_items_item_id ON stock_count_items(item_id);',
  ];
}
