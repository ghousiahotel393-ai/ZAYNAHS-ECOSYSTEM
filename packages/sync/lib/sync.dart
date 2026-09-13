/// Zaynahs Ecosystem — Event & Sync Foundation Library
/// Exporting SyncEvent model, durable SQLite outbox queue, per-device cursors,
/// conflict preservation, and the central SyncEngine.
library sync;

export 'src/sync_event.dart';
export 'src/sync_outbox_queue.dart';
export 'src/sync_cursor_manager.dart';
export 'src/sync_conflict_resolver.dart';
export 'src/sync_engine.dart';
