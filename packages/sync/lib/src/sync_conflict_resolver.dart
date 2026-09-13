/// Conflict Preservation & Resolution Engine.
/// Enforces Rule 43-46, Section 04: Strict NO LAST-WRITE-WINS (LWW).
/// Ledger entries merge append-only. Entity conflicts are recorded in sync_conflicts.
library sync_conflict_resolver;

import 'dart:convert';
import 'package:core/core.dart';
import 'package:database/database.dart';

class SyncConflict {
  final String id;
  final String entityTable;
  final String entityId;
  final String? localEventId;
  final String remoteEventId;
  final String conflictType;
  final Map<String, dynamic> conflictData;
  final String status;
  final String createdAt;

  const SyncConflict({
    required this.id,
    required this.entityTable,
    required this.entityId,
    this.localEventId,
    required this.remoteEventId,
    required this.conflictType,
    required this.conflictData,
    this.status = 'UNRESOLVED',
    required this.createdAt,
  });
}

class SyncConflictResolver {
  final AppDatabase db;

  SyncConflictResolver(this.db);

  /// Records an entity collision in sync_conflicts without silently discarding either state.
  void recordConflict({
    required String entityTable,
    required String entityId,
    String? localEventId,
    required String remoteEventId,
    required String conflictType,
    required Map<String, dynamic> conflictData,
  }) {
    final conflictId = 'cnf_${EntityId.generateUuidV4()}';
    final now = DateTime.now().toUtc().toIso8601String();

    db.connection.execute(
      '''
      INSERT INTO sync_conflicts (
        id, entity_table, entity_id, local_event_id, remote_event_id,
        conflict_type, conflict_data_json, status, created_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, 'UNRESOLVED', ?);
      ''',
      [
        conflictId,
        entityTable,
        entityId,
        localEventId,
        remoteEventId,
        conflictType,
        jsonEncode(conflictData),
        now,
      ],
    );
  }

  /// Lists all unresolved conflicts requiring domain/operator review.
  List<SyncConflict> getUnresolvedConflicts() {
    final rows = db.connection.select(
      "SELECT * FROM sync_conflicts WHERE status = 'UNRESOLVED' ORDER BY created_at ASC;",
    );

    return rows.map((row) {
      return SyncConflict(
        id: row['id'] as String,
        entityTable: row['entity_table'] as String,
        entityId: row['entity_id'] as String,
        localEventId: row['local_event_id'] as String?,
        remoteEventId: row['remote_event_id'] as String,
        conflictType: row['conflict_type'] as String,
        conflictData: jsonDecode(row['conflict_data_json'] as String) as Map<String, dynamic>,
        status: row['status'] as String,
        createdAt: row['created_at'] as String,
      );
    }).toList();
  }

  /// Resolves conflict with explicit operator resolution.
  void resolveConflict(String conflictId, {String newStatus = 'RESOLVED'}) {
    db.connection.execute(
      'UPDATE sync_conflicts SET status = ? WHERE id = ?;',
      [newStatus, conflictId],
    );
  }
}
