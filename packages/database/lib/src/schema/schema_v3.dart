/// Schema Version 3 DDL for Zaynahs Ecosystem SQLite Database.
/// Implements Phase 05: sync_conflicts table, event hashing/signature columns on sync_outbox,
/// and performance indexes for sync dispatch.
library schema_v3;

class SchemaV3 {
  static const int version = 3;

  static const List<String> ddlStatements = [
    // 1. Add cryptographic integrity and vector tracking columns to sync_outbox
    'ALTER TABLE sync_outbox ADD COLUMN user_id TEXT;',
    'ALTER TABLE sync_outbox ADD COLUMN logical_version INTEGER NOT NULL DEFAULT 1;',
    'ALTER TABLE sync_outbox ADD COLUMN hash TEXT;',
    'ALTER TABLE sync_outbox ADD COLUMN signature TEXT;',

    // 2. Composite index for rapid pending outbox dispatch per peer device
    'CREATE INDEX IF NOT EXISTS idx_sync_outbox_device_status ON sync_outbox(device_id, status);',

    // 3. Sync Conflicts Table (Transparent Conflict Preservation - NO LWW)
    '''
    CREATE TABLE IF NOT EXISTS sync_conflicts (
      id TEXT PRIMARY KEY,
      entity_table TEXT NOT NULL,
      entity_id TEXT NOT NULL,
      local_event_id TEXT REFERENCES sync_outbox(id),
      remote_event_id TEXT NOT NULL,
      conflict_type TEXT NOT NULL,
      conflict_data_json TEXT NOT NULL,
      status TEXT NOT NULL DEFAULT 'UNRESOLVED' CHECK(status IN ('UNRESOLVED', 'RESOLVED', 'IGNORED')),
      created_at TEXT NOT NULL
    );
    ''',
    'CREATE INDEX IF NOT EXISTS idx_sync_conflicts_status ON sync_conflicts(status);',
    'CREATE INDEX IF NOT EXISTS idx_sync_conflicts_entity ON sync_conflicts(entity_table, entity_id);',
  ];
}
