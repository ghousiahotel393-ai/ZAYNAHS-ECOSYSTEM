/// Repository for durable peer-to-peer sync outbox and cursor tracking.
/// Enforces Rule 37-46: Durable persistence before ACK, vector cursors, idempotent events.
library sync_repository;

import 'package:core/core.dart';
import '../app_database.dart';

class SyncEventEntity {
  final String id;
  final String eventType;
  final String entityTable;
  final String entityId;
  final String payloadJson;
  final String deviceId;
  final String status; // PENDING, SENT, ACKNOWLEDGED, FAILED
  final int retryCount;
  final DateTime createdAt;

  const SyncEventEntity({
    required this.id,
    required this.eventType,
    required this.entityTable,
    required this.entityId,
    required this.payloadJson,
    required this.deviceId,
    required this.status,
    this.retryCount = 0,
    required this.createdAt,
  });
}

class SyncCursorEntity {
  final String peerDeviceId;
  final String? lastReceivedEventId;
  final String? lastAckedEventId;
  final DateTime lastSyncTimestamp;

  const SyncCursorEntity({
    required this.peerDeviceId,
    this.lastReceivedEventId,
    this.lastAckedEventId,
    required this.lastSyncTimestamp,
  });
}

class SyncRepository {
  final AppDatabase db;

  SyncRepository(this.db);

  /// Enqueues a new sync event into durable outbox.
  void enqueueEvent({
    required String eventType,
    required String entityTable,
    required String entityId,
    required String payloadJson,
    required String deviceId,
  }) {
    final eventId = EventId.generate().value;
    final now = DateTime.now().toUtc();

    db.connection.execute(
      '''
      INSERT INTO sync_outbox (
        id, event_type, entity_table, entity_id, payload_json,
        device_id, status, retry_count, created_at
      ) VALUES (?, ?, ?, ?, ?, ?, 'PENDING', 0, ?)
      ''',
      [eventId, eventType, entityTable, entityId, payloadJson, deviceId, now.toIso8601String()],
    );
  }

  /// Retrieves pending outbox events ordered by creation timestamp.
  List<SyncEventEntity> getPendingEvents({int limit = 50}) {
    final rs = db.connection.select(
      '''
      SELECT * FROM sync_outbox
      WHERE status = 'PENDING'
      ORDER BY created_at ASC
      LIMIT ?
      ''',
      [limit],
    );

    return rs.map((row) => SyncEventEntity(
      id: row['id'] as String,
      eventType: row['event_type'] as String,
      entityTable: row['entity_table'] as String,
      entityId: row['entity_id'] as String,
      payloadJson: row['payload_json'] as String,
      deviceId: row['device_id'] as String,
      status: row['status'] as String,
      retryCount: row['retry_count'] as int,
      createdAt: DateTime.parse(row['created_at'] as String),
    )).toList();
  }

  /// Marks an event as acknowledged by a remote peer.
  void markEventAcknowledged(String eventId) {
    db.connection.execute(
      "UPDATE sync_outbox SET status = 'ACKNOWLEDGED' WHERE id = ?",
      [eventId],
    );
  }

  /// Updates or inserts peer vector cursor.
  void updateCursor({
    required String peerDeviceId,
    String? lastReceivedEventId,
    String? lastAckedEventId,
  }) {
    final now = DateTime.now().toUtc().toIso8601String();

    db.connection.execute(
      '''
      INSERT INTO sync_cursors (peer_device_id, last_received_event_id, last_acked_event_id, last_sync_timestamp)
      VALUES (?, ?, ?, ?)
      ON CONFLICT(peer_device_id) DO UPDATE SET
        last_received_event_id = COALESCE(excluded.last_received_event_id, sync_cursors.last_received_event_id),
        last_acked_event_id = COALESCE(excluded.last_acked_event_id, sync_cursors.last_acked_event_id),
        last_sync_timestamp = excluded.last_sync_timestamp
      ''',
      [peerDeviceId, lastReceivedEventId, lastAckedEventId, now],
    );
  }

  /// Gets cursor for a specific peer.
  SyncCursorEntity? getCursor(String peerDeviceId) {
    final rs = db.connection.select(
      'SELECT * FROM sync_cursors WHERE peer_device_id = ?',
      [peerDeviceId],
    );
    if (rs.isEmpty) return null;
    final row = rs.first;
    return SyncCursorEntity(
      peerDeviceId: row['peer_device_id'] as String,
      lastReceivedEventId: row['last_received_event_id'] as String?,
      lastAckedEventId: row['last_acked_event_id'] as String?,
      lastSyncTimestamp: DateTime.parse(row['last_sync_timestamp'] as String),
    );
  }
}
