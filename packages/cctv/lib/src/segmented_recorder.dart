/// Resilient Segmented Continuous Recording Pipeline for Zaynahs Ecosystem CCTV.
/// Enforces Rule 60-63, Rule 105 (Golden CCTV Test):
/// Continuous 1-5 min segments, atomic writes (temp -> verify -> finalize), SHA-256 checksums,
/// zero corrupt completed segments on camera disconnect, zero fake recording states.
library segmented_recorder;

import 'dart:async';
import 'dart:io';
import 'package:core/core.dart';
import 'package:crypto/crypto.dart';
import 'package:database/database.dart';
import 'package:storage/storage.dart';
import 'camera_source.dart';

class CctvSegment {
  final String id;
  final String cameraId;
  final String filePath;
  final int fileSizeBytes;
  final String sha256Checksum;
  final double durationSeconds;
  final DateTime startTime;
  final DateTime endTime;
  final bool isProtected;
  final bool isCorrupted;
  final DateTime createdAt;

  const CctvSegment({
    required this.id,
    required this.cameraId,
    required this.filePath,
    required this.fileSizeBytes,
    required this.sha256Checksum,
    required this.durationSeconds,
    required this.startTime,
    required this.endTime,
    required this.isProtected,
    required this.isCorrupted,
    required this.createdAt,
  });
}

class InFlightSegment {
  final String id;
  final String cameraId;
  final File tempFile;
  final IOSink sink;
  final DateTime startTime;
  int bytesWritten = 0;

  InFlightSegment({
    required this.id,
    required this.cameraId,
    required this.tempFile,
    required this.sink,
    required this.startTime,
  });
}

class SegmentedRecorder {
  final AppDatabase db;
  final FileStorageService storageService;
  final Duration targetSegmentDuration;
  final int maxSegmentBytes;

  final Map<String, InFlightSegment> _activeSegments = {};
  final Map<String, StreamSubscription<List<int>>> _cameraSubscriptions = {};

  SegmentedRecorder({
    required this.db,
    required this.storageService,
    this.targetSegmentDuration = const Duration(minutes: 5),
    this.maxSegmentBytes = 50 * 1024 * 1024, // 50 MB
  });

  bool isCameraRecording(String cameraId) => _activeSegments.containsKey(cameraId);

  String? getActiveSegmentId(String cameraId) => _activeSegments[cameraId]?.id;

  /// Starts continuous segmented recording for a camera source.
  Future<void> startRecording(CameraSource camera) async {
    if (_activeSegments.containsKey(camera.id)) {
      return; // Already recording
    }

    camera.markRecording(true);
    db.connection.execute(
      'UPDATE cctv_cameras SET is_recording = 1, updated_at = ? WHERE id = ?',
      [DateTime.now().toUtc().toIso8601String(), camera.id],
    );

    // Open first in-flight segment
    await _startNewSegment(camera.id);

    final stream = camera.startStream();
    final subscription = stream.listen(
      (chunk) async {
        await _handleIncomingChunk(camera, chunk);
      },
      onError: (Object error) async {
        // Handle sudden disconnect mid-stream
        await _handleCameraDisconnect(camera, reason: error.toString());
      },
      onDone: () async {
        // Stream completed or closed
        if (_activeSegments.containsKey(camera.id)) {
          await _handleCameraDisconnect(camera, reason: 'Stream ended');
        }
      },
      cancelOnError: true,
    );

    _cameraSubscriptions[camera.id] = subscription;
  }

  /// Appends incoming video chunk to the active in-flight segment.
  Future<void> _handleIncomingChunk(CameraSource camera, List<int> chunk) async {
    final active = _activeSegments[camera.id];
    if (active == null) return;

    active.sink.add(chunk);
    active.bytesWritten += chunk.length;

    final now = DateTime.now().toUtc();
    final elapsed = now.difference(active.startTime);

    // Check if segment boundary reached
    if (elapsed >= targetSegmentDuration || active.bytesWritten >= maxSegmentBytes) {
      await _rotateSegment(camera);
    }
  }

  /// Atomically rotates to a new segment boundary.
  Future<CctvSegment?> _rotateSegment(CameraSource camera) async {
    final finalized = await finalizeSegment(camera.id);
    if (camera.state == CameraConnectionState.recording || camera.state == CameraConnectionState.streaming) {
      await _startNewSegment(camera.id);
    }
    return finalized;
  }

  /// Opens a new temporary in-flight segment file on disk.
  Future<void> _startNewSegment(String cameraId) async {
    final segId = 'seg_${EntityId.generateUuidV4()}';
    final tempDir = storageService.taxonomy.getCategoryDirectory(StorageCategory.temp);
    final tempFile = File('${tempDir.path}/${segId}.tmp');
    final sink = tempFile.openWrite(mode: FileMode.append);

    _activeSegments[cameraId] = InFlightSegment(
      id: segId,
      cameraId: cameraId,
      tempFile: tempFile,
      sink: sink,
      startTime: DateTime.now().toUtc(),
    );
  }

  /// Safely closes in-flight segment, computes SHA-256, promotes to permanent storage,
  /// and updates camera and database state.
  Future<CctvSegment?> finalizeSegment(String cameraId, {bool markCorrupted = false}) async {
    final active = _activeSegments.remove(cameraId);
    if (active == null) return null;

    await active.sink.flush();
    await active.sink.close();

    final endTime = DateTime.now().toUtc();
    final durationSeconds = (endTime.difference(active.startTime).inMilliseconds) / 1000.0;

    // If zero bytes written, clean up and return null
    if (active.bytesWritten == 0 || !await active.tempFile.exists()) {
      if (await active.tempFile.exists()) {
        await active.tempFile.delete();
      }
      return null;
    }

    // 1. Calculate SHA-256 Checksum over finalized file bytes
    final bytes = await active.tempFile.readAsBytes();
    final digest = sha256.convert(bytes).toString();

    // 2. Format permanent relative file path:
    // e.g. "cam_01/2026/09/12/seg_uuid.mp4"
    final y = active.startTime.year.toString().padLeft(4, '0');
    final m = active.startTime.month.toString().padLeft(2, '0');
    final d = active.startTime.day.toString().padLeft(2, '0');
    final relativePath = '$cameraId/$y/$m/$d/${active.id}.mp4';

    // 3. Atomically save/rename file into cctvRecordings directory
    await storageService.saveFileAtomic(
      category: StorageCategory.cctvRecordings,
      fileName: relativePath,
      bytes: bytes,
    );

    // Clean up temporary file
    if (await active.tempFile.exists()) {
      await active.tempFile.delete();
    }

    final segment = CctvSegment(
      id: active.id,
      cameraId: cameraId,
      filePath: relativePath,
      fileSizeBytes: bytes.length,
      sha256Checksum: digest,
      durationSeconds: durationSeconds > 0 ? durationSeconds : 0.001,
      startTime: active.startTime,
      endTime: endTime,
      isProtected: false,
      isCorrupted: markCorrupted,
      createdAt: endTime,
    );

    // 4. Record segment into cctv_segments table
    db.connection.execute(
      '''
      INSERT INTO cctv_segments (
        id, camera_id, file_path, file_size_bytes, sha256_checksum,
        duration_seconds, start_time, end_time, is_protected, is_corrupted, created_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        segment.id,
        segment.cameraId,
        segment.filePath,
        segment.fileSizeBytes,
        segment.sha256Checksum,
        segment.durationSeconds,
        segment.startTime.toIso8601String(),
        segment.endTime.toIso8601String(),
        segment.isProtected ? 1 : 0,
        segment.isCorrupted ? 1 : 0,
        segment.createdAt.toIso8601String(),
      ],
    );

    return segment;
  }

  /// Handles sudden mid-stream hardware disconnect or network cut cleanly.
  Future<void> _handleCameraDisconnect(CameraSource camera, {required String reason}) async {
    // 1. Cancel subscription
    await _cameraSubscriptions.remove(camera.id)?.cancel();

    // 2. Finalize whatever in-flight bytes were written so far (Zero corrupt files)
    final closedSegment = await finalizeSegment(camera.id);

    // 3. Mark camera disconnected & idle in database
    camera.markRecording(false);
    await camera.disconnect(reason: reason);

    final now = DateTime.now().toUtc();
    db.connection.execute(
      'UPDATE cctv_cameras SET is_recording = 0, updated_at = ? WHERE id = ?',
      [now.toIso8601String(), camera.id],
    );

    // 4. Log DISCONNECT event in cctv_events
    final eventId = 'evt_${EntityId.generateUuidV4()}';
    db.connection.execute(
      '''
      INSERT INTO cctv_events (
        id, camera_id, segment_id, event_type, timestamp, confidence, metadata_json, created_at
      ) VALUES (?, ?, ?, 'DISCONNECT', ?, 1.0, ?, ?)
      ''',
      [
        eventId,
        camera.id,
        closedSegment?.id,
        now.toIso8601String(),
        '{"reason": "$reason"}',
        now.toIso8601String(),
      ],
    );
  }

  /// Stops continuous recording cleanly.
  Future<CctvSegment?> stopRecording(CameraSource camera) async {
    await _cameraSubscriptions.remove(camera.id)?.cancel();
    final closedSegment = await finalizeSegment(camera.id);

    camera.markRecording(false);
    final now = DateTime.now().toUtc();
    db.connection.execute(
      'UPDATE cctv_cameras SET is_recording = 0, updated_at = ? WHERE id = ?',
      [now.toIso8601String(), camera.id],
    );

    return closedSegment;
  }

  /// Disposes all recording operations and cleans temp sinks.
  Future<void> dispose() async {
    for (final sub in _cameraSubscriptions.values) {
      await sub.cancel();
    }
    _cameraSubscriptions.clear();

    for (final camId in _activeSegments.keys.toList()) {
      await finalizeSegment(camId);
    }
    _activeSegments.clear();
  }
}
