/// Schema Version 8 DDL for Zaynahs Ecosystem SQLite Database.
/// Implements Phase 12: Backup & Disaster Recovery.
/// Adds backup_records table for cataloging local and cloud archive snapshots.
/// Enforces Rules 86-91, Rule 102 (Golden Backup Test).
library schema_v8;

class SchemaV8 {
  static const int version = 8;

  static const List<String> ddlStatements = [
    // 1. Backup Records Catalog Table
    '''
    CREATE TABLE IF NOT EXISTS backup_records (
      id TEXT PRIMARY KEY,
      backup_type TEXT NOT NULL CHECK(backup_type IN ('DAILY', 'MANUAL', 'PRE_RESTORE')),
      file_path TEXT NOT NULL,
      file_size_bytes INTEGER NOT NULL,
      sha256_checksum TEXT NOT NULL,
      manifest_json TEXT NOT NULL,
      status TEXT NOT NULL CHECK(status IN ('COMPLETED', 'CORRUPTED', 'RESTORED')),
      actor_id TEXT NOT NULL REFERENCES users(id),
      device_id TEXT NOT NULL REFERENCES devices(id),
      created_at TEXT NOT NULL
    );
    ''',
    'CREATE INDEX IF NOT EXISTS idx_backup_records_type ON backup_records(backup_type);',
    'CREATE INDEX IF NOT EXISTS idx_backup_records_status ON backup_records(status);',
    'CREATE INDEX IF NOT EXISTS idx_backup_records_created_at ON backup_records(created_at);',
  ];
}
