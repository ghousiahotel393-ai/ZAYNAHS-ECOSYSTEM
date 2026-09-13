/// Per-Device Sync Cursors and ACK Checkpoints.
/// Enforces Sacred Sync Laws (Rule 40-42, Section 03):
/// 1. ACK only AFTER event is durably applied.
/// 2. NEVER advance sync cursor before durable application.
/// 3. Duplicate events are recognized and acknowledged idempotently.
library sync_cursor_manager;

import 'package:database/database.dart';

class SyncCursor {
  final String peerDeviceId;
  final String? lastReceivedEventId;
  final String? lastAckedEventId;
  final String lastSyncTimestamp;

  const SyncCursor({
    required this.peerDeviceId,
    this.lastReceivedEventId,
    this.lastAckedEventId,
    required this.lastSyncTimestamp,
  });
}

class SyncCursorManager {
  final AppDatabase db;

  SyncCursorManager(this.db);

  /// Retrieves sync checkpoint cursor for a given peer device.
  SyncCursor? getCursor(String peerDeviceId) {
    final rows = db.connection.select(
      'SELECT * FROM sync_cursors WHERE peer_device_id = ?;',
      [peerDeviceId],
    );
    if (rows.isEmpty) return null;

    final row = rows.first;
    return SyncCursor(
      peerDeviceId: row['peer_device_id'] as String,
      lastReceivedEventId: row['last_received_event_id'] as String?,
      lastAckedEventId: row['last_acked_event_id'] as String?,
      lastSyncTimestamp: row['last_sync_timestamp'] as String,
    );
  }

  /// Checks if an event ID has already been applied or recorded locally.
  /// Guarantees idempotency (Sacred Sync Law #3).
  bool isEventProcessed(String eventId) {
    final rs = db.connection.select(
      'SELECT id FROM sync_outbox WHERE id = ? LIMIT 1;',
      [eventId],
    );
    return rs.isNotEmpty;
  }

  /// Advances sync cursor only AFTER durable write has occurred (Sacred Sync Law #1 & #2).
  void advanceCursor({
    required String peerDeviceId,
    required String eventId,
    required bool isAcked,
    DateTime? timestamp,
  }) {
    final ts = (timestamp ?? DateTime.now().toUtc()).toIso8601String();
    final existing = getCursor(peerDeviceId);

    if (existing == null) {
      db.connection.execute(
        '''
        INSERT INTO sync_cursors (
          peer_device_id, last_received_event_id, last_acked_event_id, last_sync_timestamp
        ) VALUES (?, ?, ?, ?);
        ''',
        [
          peerDeviceId,
          eventId,
          isAcked ? eventId : null,
          ts,
        ],
      );
    } else {
      if (isAcked) {
        db.connection.execute(
          '''
          UPDATE sync_cursors
          SET last_received_event_id = ?,
              last_acked_event_id = ?,
              last_sync_timestamp = ?
          WHERE peer_device_id = ?;
          ''',
          [eventId, eventId, ts, peerDeviceId],
        );
      } else {
        db.connection.execute(
          '''
          UPDATE sync_cursors
          SET last_received_event_id = ?,
              last_sync_timestamp = ?
          WHERE peer_device_id = ?;
          ''',
          [eventId, ts, peerDeviceId],
        );
      }
    }
  }
}
