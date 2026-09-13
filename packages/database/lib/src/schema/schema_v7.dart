/// Schema Version 7 DDL for Zaynahs Ecosystem SQLite Database.
/// Implements Phase 11: CCTV Monitoring & Segmented Recording.
/// Adds cctv_cameras, cctv_segments, and cctv_events tables and indexes.
/// Enforces Rules 54-65, Rule 105 (Golden CCTV Test).
library schema_v7;

class SchemaV7 {
  static const int version = 7;

  static const List<String> ddlStatements = [
    // 1. CCTV Cameras Registry
    '''
    CREATE TABLE IF NOT EXISTS cctv_cameras (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      source_type TEXT NOT NULL,
      source_url TEXT NOT NULL,
      resolution TEXT NOT NULL,
      fps INTEGER NOT NULL,
      is_recording INTEGER NOT NULL DEFAULT 0,
      device_id TEXT NOT NULL REFERENCES devices(id),
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    );
    ''',
    'CREATE INDEX IF NOT EXISTS idx_cctv_cameras_device_id ON cctv_cameras(device_id);',

    // 2. CCTV Segments (Continuous 1-5 min video files)
    '''
    CREATE TABLE IF NOT EXISTS cctv_segments (
      id TEXT PRIMARY KEY,
      camera_id TEXT NOT NULL REFERENCES cctv_cameras(id) ON DELETE CASCADE,
      file_path TEXT NOT NULL,
      file_size_bytes INTEGER NOT NULL,
      sha256_checksum TEXT NOT NULL,
      duration_seconds REAL NOT NULL,
      start_time TEXT NOT NULL,
      end_time TEXT NOT NULL,
      is_protected INTEGER NOT NULL DEFAULT 0,
      is_corrupted INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL
    );
    ''',
    'CREATE INDEX IF NOT EXISTS idx_cctv_segments_camera_id ON cctv_segments(camera_id);',
    'CREATE INDEX IF NOT EXISTS idx_cctv_segments_start_time ON cctv_segments(start_time);',
    'CREATE INDEX IF NOT EXISTS idx_cctv_segments_end_time ON cctv_segments(end_time);',
    'CREATE INDEX IF NOT EXISTS idx_cctv_segments_is_protected ON cctv_segments(is_protected);',

    // 3. CCTV Events (Motion, Person, Vehicle, Disconnect, Reconnect)
    '''
    CREATE TABLE IF NOT EXISTS cctv_events (
      id TEXT PRIMARY KEY,
      camera_id TEXT NOT NULL REFERENCES cctv_cameras(id) ON DELETE CASCADE,
      segment_id TEXT REFERENCES cctv_segments(id) ON DELETE SET NULL,
      event_type TEXT NOT NULL,
      timestamp TEXT NOT NULL,
      confidence REAL NOT NULL,
      metadata_json TEXT NOT NULL,
      created_at TEXT NOT NULL
    );
    ''',
    'CREATE INDEX IF NOT EXISTS idx_cctv_events_camera_id ON cctv_events(camera_id);',
    'CREATE INDEX IF NOT EXISTS idx_cctv_events_timestamp ON cctv_events(timestamp);',
    'CREATE INDEX IF NOT EXISTS idx_cctv_events_event_type ON cctv_events(event_type);',
  ];
}
