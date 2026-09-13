/// Automated Safe Retention Cleaner for Zaynahs Ecosystem CCTV.
/// Enforces Rule 63, Rule 105:
/// SACRED RETENTION LAW: Retention cleanup must NEVER delete:
///   1. Protected/bookmarked recordings (is_protected = 1)
///   2. Active in-flight segments
///   3. Required audit evidence clips
library retention_cleaner;

import 'package:core/core.dart';
import 'package:database/database.dart';
import 'package:storage/storage.dart';
import 'segmented_recorder.dart';

class RetentionPurgeResult {
  final int purgedCount;
  final int freedBytes;
  final List<String> purgedSegmentIds;

  const RetentionPurgeResult({
    required this.purgedCount,
    required this.freedBytes,
    required this.purgedSegmentIds,
  });
}

class RetentionCleaner {
  final AppDatabase db;
  final FileStorageService storageService;
  final SegmentedRecorder? recorder;

  RetentionCleaner({
    required this.db,
    required this.storageService,
    this.recorder,
  });

  /// Executes safe retention cleanup under storage pressure or age expiration.
  /// Strictly guarantees that protected segments, active recording segments,
  /// and preserved clips are NEVER deleted.
  Future<RetentionPurgeResult> executeRetentionCleanup({
    Duration? olderThan,
    int? bytesToFree,
    Set<String> preservedSegmentIds = const {},
    String actorId = 'system',
    String deviceId = 'local_device',
  }) async {
    // 1. Determine cutoff timestamp if olderThan is provided
    final now = DateTime.now().toUtc();
    final cutoff = olderThan != null ? now.subtract(olderThan) : null;

    // 2. Query purge candidate segments (Oldest first, Strictly UNPROTECTED)
    var sql = 'SELECT * FROM cctv_segments WHERE is_protected = 0';
    final params = <dynamic>[];

    if (cutoff != null) {
      sql += ' AND end_time <= ?';
      params.add(cutoff.toIso8601String());
    }

    sql += ' ORDER BY start_time ASC';

    final rows = db.connection.select(sql, params);

    int purgedCount = 0;
    int freedBytes = 0;
    final List<String> purgedIds = [];

    for (final row in rows) {
      final segId = row['id'] as String;
      final filePath = row['file_path'] as String;
      final fileSizeBytes = row['file_size_bytes'] as int;
      final isProtected = (row['is_protected'] as int) == 1;

      // ABSOLUTE SAFETY GUARD 1: Sacred Law - Never delete protected recordings
      if (isProtected) {
        continue;
      }

      // ABSOLUTE SAFETY GUARD 2: Sacred Law - Never delete active in-flight recording segments
      if (recorder != null) {
        final camId = row['camera_id'] as String;
        final activeSegId = recorder!.getActiveSegmentId(camId);
        if (activeSegId == segId) {
          continue;
        }
      }

      // ABSOLUTE SAFETY GUARD 3: Never delete explicitly preserved or audit evidence segments
      if (preservedSegmentIds.contains(segId)) {
        continue;
      }

      // Safe to purge:
      // 1. Delete physical file from disk
      await storageService.delete(StorageCategory.cctvRecordings, filePath);

      // 2. Delete segment record from database
      db.connection.execute('DELETE FROM cctv_segments WHERE id = ?', [segId]);

      purgedCount++;
      freedBytes += fileSizeBytes;
      purgedIds.add(segId);

      // If we met target bytes to free, stop
      if (bytesToFree != null && freedBytes >= bytesToFree) {
        break;
      }
    }

    // 3. Log Audit Event if segments were purged
    if (purgedCount > 0) {
      final auditId = 'aud_${EntityId.generateUuidV4()}';
      db.connection.execute(
        '''
        INSERT INTO audit_logs (
          id, timestamp, level, action, actor_id, device_id,
          entity_type, entity_id, details_json, previous_hash, entry_hash
        ) VALUES (?, ?, 'AUDIT', 'CCTV_RETENTION_PURGE', ?, ?, 'cctv_retention', ?, ?, '', ?)
        ''',
        [
          auditId,
          now.toIso8601String(),
          actorId,
          deviceId,
          'purge_${now.millisecondsSinceEpoch}',
          '{"purgedCount": $purgedCount, "freedBytes": $freedBytes}',
          'hash_$auditId',
        ],
      );
    }

    return RetentionPurgeResult(
      purgedCount: purgedCount,
      freedBytes: freedBytes,
      purgedSegmentIds: purgedIds,
    );
  }
}
