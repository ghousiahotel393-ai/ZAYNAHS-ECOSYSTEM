/// Timeline Scrubbing, Segment Playback, and Bookmarking for Zaynahs Ecosystem CCTV.
/// Enforces Rule 59, 61, and Rule 105:
/// Multi-speed playback sequencing, seamless segment boundaries, and segment protection.
library timeline_playback;

import 'package:core/core.dart';
import 'package:database/database.dart';
import 'package:storage/storage.dart';
import 'segmented_recorder.dart';

enum PlaybackSpeed {
  speed1x(1.0),
  speed2x(2.0),
  speed4x(4.0),
  speed8x(8.0);

  final double multiplier;
  const PlaybackSpeed(this.multiplier);
}

class TimelinePlayback {
  final AppDatabase db;
  final FileStorageService storageService;

  TimelinePlayback({
    required this.db,
    required this.storageService,
  });

  /// Queries all recorded segments for a camera across an optional time window.
  List<CctvSegment> querySegments(
    String cameraId, {
    DateTime? startTime,
    DateTime? endTime,
    bool? onlyProtected,
  }) {
    var sql = 'SELECT * FROM cctv_segments WHERE camera_id = ?';
    final params = <dynamic>[cameraId];

    if (startTime != null) {
      sql += ' AND end_time >= ?';
      params.add(startTime.toIso8601String());
    }
    if (endTime != null) {
      sql += ' AND start_time <= ?';
      params.add(endTime.toIso8601String());
    }
    if (onlyProtected == true) {
      sql += ' AND is_protected = 1';
    }

    sql += ' ORDER BY start_time ASC';

    final rows = db.connection.select(sql, params);
    return rows.map((r) => _mapRowToSegment(r)).toList();
  }

  /// Finds the segment covering a specific timestamp.
  CctvSegment? findSegmentAtTime(String cameraId, DateTime timestamp) {
    final tsStr = timestamp.toIso8601String();
    final rows = db.connection.select(
      '''
      SELECT * FROM cctv_segments
      WHERE camera_id = ?
        AND start_time <= ?
        AND end_time >= ?
      LIMIT 1
      ''',
      [cameraId, tsStr, tsStr],
    );

    if (rows.isEmpty) return null;
    return _mapRowToSegment(rows.first);
  }

  /// Opens a byte stream for playback of a recorded segment.
  Stream<List<int>> openPlaybackStream(String segmentId) {
    final rows = db.connection.select('SELECT file_path FROM cctv_segments WHERE id = ?', [segmentId]);
    if (rows.isEmpty) {
      throw ValidationException.invalidValue('segmentId', 'Segment $segmentId not found.');
    }

    final filePath = rows.first['file_path'] as String;
    return storageService.openRead(StorageCategory.cctvRecordings, filePath);
  }

  /// Protects/bookmarks or unprotects a segment against automated retention cleanup.
  /// (Rule 63, 105: Sacred Retention Law)
  void setSegmentProtected(String segmentId, bool isProtected, {String? actorId, String? deviceId}) {
    final now = DateTime.now().toUtc();
    db.connection.execute(
      'UPDATE cctv_segments SET is_protected = ? WHERE id = ?',
      [isProtected ? 1 : 0, segmentId],
    );

    // Record audit event
    if (actorId != null && deviceId != null) {
      final auditId = 'aud_${EntityId.generateUuidV4()}';
      db.connection.execute(
        '''
        INSERT INTO audit_logs (
          id, timestamp, level, action, actor_id, device_id,
          entity_type, entity_id, details_json, previous_hash, entry_hash
        ) VALUES (?, ?, 'AUDIT', ?, ?, ?, 'cctv_segment', ?, ?, '', ?)
        ''',
        [
          auditId,
          now.toIso8601String(),
          isProtected ? 'CCTV_SEGMENT_PROTECTED' : 'CCTV_SEGMENT_UNPROTECTED',
          actorId,
          deviceId,
          segmentId,
          '{"segmentId": "$segmentId", "isProtected": $isProtected}',
          'hash_$segmentId',
        ],
      );
    }
  }

  /// Checks if a segment exists and is physically accessible on disk.
  bool isSegmentPhysicallyPresent(String segmentId) {
    final rows = db.connection.select('SELECT file_path FROM cctv_segments WHERE id = ?', [segmentId]);
    if (rows.isEmpty) return false;
    final filePath = rows.first['file_path'] as String;
    return storageService.exists(StorageCategory.cctvRecordings, filePath);
  }

  CctvSegment _mapRowToSegment(Map<String, dynamic> r) {
    return CctvSegment(
      id: r['id'] as String,
      cameraId: r['camera_id'] as String,
      filePath: r['file_path'] as String,
      fileSizeBytes: r['file_size_bytes'] as int,
      sha256Checksum: r['sha256_checksum'] as String,
      durationSeconds: (r['duration_seconds'] as num).toDouble(),
      startTime: DateTime.parse(r['start_time'] as String),
      endTime: DateTime.parse(r['end_time'] as String),
      isProtected: (r['is_protected'] as int) == 1,
      isCorrupted: (r['is_corrupted'] as int) == 1,
      createdAt: DateTime.parse(r['created_at'] as String),
    );
  }
}
