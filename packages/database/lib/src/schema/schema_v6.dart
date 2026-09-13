/// Schema Version 6 DDL for Zaynahs Ecosystem SQLite Database.
/// Implements Phase 10: Financial Reports & Analytics.
/// Adds register_shifts table for cashier shift management and day-end Z-reports.
library schema_v6;

class SchemaV6 {
  static const int version = 6;

  static const List<String> ddlStatements = [
    // 1. Cash Register Shifts Table (Z-Reports / Day-End Closeout)
    '''
    CREATE TABLE IF NOT EXISTS register_shifts (
      id TEXT PRIMARY KEY,
      shift_number TEXT UNIQUE NOT NULL,
      cashier_id TEXT NOT NULL REFERENCES users(id),
      device_id TEXT NOT NULL REFERENCES devices(id),
      opening_float_minor INTEGER NOT NULL CHECK(opening_float_minor >= 0),
      expected_cash_minor INTEGER NOT NULL DEFAULT 0,
      counted_cash_minor INTEGER,
      cash_variance_minor INTEGER NOT NULL DEFAULT 0,
      total_sales_minor INTEGER NOT NULL DEFAULT 0,
      status TEXT NOT NULL CHECK(status IN ('OPEN', 'CLOSED')),
      opened_at TEXT NOT NULL,
      closed_at TEXT,
      notes TEXT
    );
    ''',
    'CREATE INDEX IF NOT EXISTS idx_register_shifts_shift_number ON register_shifts(shift_number);',
    'CREATE INDEX IF NOT EXISTS idx_register_shifts_cashier_id ON register_shifts(cashier_id);',
    'CREATE INDEX IF NOT EXISTS idx_register_shifts_status ON register_shifts(status);',
  ];
}
