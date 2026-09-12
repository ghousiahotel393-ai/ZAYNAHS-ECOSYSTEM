/// Schema Version 2: Introduces storage_files table for SHA-256 content deduplication.
/// Follows strict MASTER_SCHEMA migration protocol.
library schema_v2;

class SchemaV2 {
  static const int version = 2;

  static const List<String> migrationStatements = [
    '''
    CREATE TABLE IF NOT EXISTS storage_files (
      id TEXT PRIMARY KEY,
      category TEXT NOT NULL,
      file_name TEXT NOT NULL,
      file_path TEXT NOT NULL,
      sha256_hash TEXT NOT NULL,
      file_size_bytes INTEGER NOT NULL,
      mime_type TEXT NOT NULL DEFAULT 'application/octet-stream',
      reference_count INTEGER NOT NULL DEFAULT 1,
      created_at TEXT NOT NULL
    );
    ''',
    'CREATE INDEX IF NOT EXISTS idx_storage_files_sha256 ON storage_files(sha256_hash);',
    'CREATE INDEX IF NOT EXISTS idx_storage_files_category ON storage_files(category);',
  ];
}
