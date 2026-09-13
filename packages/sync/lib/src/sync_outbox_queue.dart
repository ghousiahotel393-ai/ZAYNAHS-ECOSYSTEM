/// Durable SQLite Outbox Queue for Peer Synchronization.
/// Enforces Rule 39, Section 02: Events are durably stored locally before network transmission.
library sync_outbox_queue;

import 'dart:convert';
import 'package:database/database.dart';
import 'sync_event.dart';

class SyncOutboxQueue {
  final AppDatabase db;

  SyncOutboxQueue(this.db);

  /// Enqueues a SyncEvent durably into the SQLite sync_outbox table.
  /// Can be called inside an ongoing transaction or standalone.
  void enqueue(SyncEvent event) {
    db.connection.execute(
      '''
      INSERT INTO sync_outbox (
        id, event_type, entity_table, entity_id, payload_json,
        device_id, status, retry_count, created_at, user_id,
        logical_version, hash, signature
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
      ''',
      [
        event.eventId,
        event.eventType,
        event.aggregateType,
        event.aggregateId,
        jsonEncode(event.payload),
        event.deviceId,
        event.state.dbStatus,
        0,
        event.createdAt,
        event.userId,
        event.logicalVersion,
        event.hash,
        event.signature,
      ],
    );
  }

  /// Fetches pending/queued events in chronological FIFO order.
  List<SyncEvent> fetchPending({String? targetDeviceId, int limit = 50}) {
    final sql = targetDeviceId != null
        ? '''
          SELECT * FROM sync_outbox
          WHERE status IN ('PENDING', 'QUEUED') AND device_id = ?
          ORDER BY created_at ASC, logical_version ASC
          LIMIT ?;
          '''
        : '''
          SELECT * FROM sync_outbox
          WHERE status IN ('PENDING', 'QUEUED')
          ORDER BY created_at ASC, logical_version ASC
          LIMIT ?;
          ''';

    final params = targetDeviceId != null ? [targetDeviceId, limit] : [limit];
    final rows = db.connection.select(sql, params);

    return rows.map((row) {
      return SyncEvent(
        eventId: row['id'] as String,
        eventType: row['event_type'] as String,
        aggregateType: row['entity_table'] as String,
        aggregateId: row['entity_id'] as String,
        payload: jsonDecode(row['payload_json'] as String) as Map<String, dynamic>,
        deviceId: row['device_id'] as String,
        userId: row['user_id'] as String?,
        logicalVersion: (row['logical_version'] as int?) ?? 1,
        createdAt: row['created_at'] as String,
        hash: row['hash'] as String? ?? '',
        signature: row['signature'] as String?,
        state: SyncState.fromDbStatus(row['status'] as String),
      );
    }).toList();
  }

  /// Marks event as actively being transmitted.
  void markSending(String eventId) {
    db.connection.execute(
      "UPDATE sync_outbox SET status = 'SENT' WHERE id = ?;",
      [eventId],
    );
  }

  /// Marks event as successfully acknowledged by remote peer.
  void markAcknowledged(String eventId) {
    db.connection.execute(
      "UPDATE sync_outbox SET status = 'ACKNOWLEDGED' WHERE id = ?;",
      [eventId],
    );
  }

  /// Marks event as failed and increments retry count.
  void markFailed(String eventId, {String? reason}) {
    db.connection.execute(
      '''
      UPDATE sync_outbox
      SET status = 'FAILED', retry_count = retry_count + 1
      WHERE id = ?;
      ''',
      [eventId],
    );
  }

  /// Returns count of pending events awaiting peer sync.
  int getPendingCount({String? deviceId}) {
    final sql = deviceId != null
        ? "SELECT COUNT(*) as cnt FROM sync_outbox WHERE status IN ('PENDING', 'QUEUED') AND device_id = ?;"
        : "SELECT COUNT(*) as cnt FROM sync_outbox WHERE status IN ('PENDING', 'QUEUED');";
    final params = deviceId != null ? [deviceId] : const [];
    final rs = db.connection.select(sql, params);
    return rs.first['cnt'] as int? ?? 0;
  }
}
