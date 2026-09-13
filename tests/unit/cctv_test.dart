import 'dart:io';
import 'package:cctv/cctv.dart';
import 'package:core/core.dart';
import 'package:crypto/crypto.dart';
import 'package:database/database.dart';
import 'package:storage/storage.dart';

Future<void> main() async {
  int passed = 0;
  int failed = 0;

  void test(String name, void Function() body) {
    try {
      body();
      passed++;
      // ignore: avoid_print
      print('  ✓ $name');
    } catch (e, st) {
      failed++;
      // ignore: avoid_print
      print('  ✗ $name: $e\n$st');
    }
  }

  Future<void> testAsync(String name, Future<void> Function() body) async {
    try {
      await body();
      passed++;
      // ignore: avoid_print
      print('  ✓ $name');
    } catch (e, st) {
      failed++;
      // ignore: avoid_print
      print('  ✗ $name: $e\n$st');
    }
  }

  void expect(dynamic actual, dynamic expected) {
    if (actual is List && expected is List) {
      if (actual.length != expected.length) {
        throw AssertionError('Expected length: ${expected.length}, Actual length: ${actual.length}');
      }
      for (int i = 0; i < actual.length; i++) {
        if (actual[i] != expected[i]) {
          throw AssertionError('Mismatch at index $i: Expected ${expected[i]}, Actual ${actual[i]}');
        }
      }
      return;
    }
    if (actual != expected) {
      throw AssertionError('Expected: $expected, Actual: $actual');
    }
  }

  void assertTrue(bool condition, [String? message]) {
    if (!condition) {
      throw AssertionError(message ?? 'Expected condition to be true');
    }
  }

  // ignore: avoid_print
  print('\n=== Running CCTV Monitoring, Recording & Golden Test 105 Tests ===');

  AppDatabase createDb() {
    final db = AppDatabase.openInMemory();
    db.initialize();
    return db;
  }

  Directory createTempStorageDir() {
    return Directory.systemTemp.createTempSync('zaynahs_cctv_test_');
  }

  void seedEcosystem(AppDatabase db, {String actorId = 'usr_owner_01', String deviceId = 'dev_counter_01'}) {
    db.connection.execute(
      "INSERT INTO ecosystems (id, name, created_at, updated_at) VALUES ('eco_flagship', 'Zaynahs Flagship', '2026-09-12T00:00:00Z', '2026-09-12T00:00:00Z');",
    );
    db.connection.execute(
      "INSERT INTO devices (id, name, trust_status, public_key, last_seen_at) VALUES (?, 'POS Terminal 1', 'TRUSTED', 'pk_terminal', '2026-09-12T00:00:00Z');",
      [deviceId],
    );
    db.connection.execute(
      "INSERT INTO users (id, name, email, role, password_hash, pin_hash, created_at, updated_at) VALUES (?, 'Store Admin', 'admin@zaynahs.local', 'Admin', 'pwd_hash', 'pin_hash', '2026-09-12T00:00:00Z', '2026-09-12T00:00:00Z');",
      [actorId],
    );
  }

  // -------------------------------------------------------------
  // 1. Camera Discovery & Preview Tests
  // -------------------------------------------------------------
  await testAsync('Camera discovery registers RTSP, USB, and IP sources with state transitions', () async {
    final db = createDb();
    seedEcosystem(db);
    final discovery = CameraDiscoveryService(db: db);

    // Register USB Camera
    final usbCam = discovery.registerCamera(
      name: 'Counter USB Cam',
      type: CameraSourceType.usb,
      sourceUrl: '/dev/video0',
      deviceId: 'dev_counter_01',
    );

    // Register RTSP Camera
    final rtspCam = discovery.registerCamera(
      name: 'Outdoor RTSP Cam',
      type: CameraSourceType.rtsp,
      sourceUrl: 'rtsp://192.168.1.50:554/live',
      deviceId: 'dev_counter_01',
    );

    expect(usbCam.type, CameraSourceType.usb);
    expect(rtspCam.type, CameraSourceType.rtsp);

    // Verify DB listings
    final cameras = discovery.listCameras(deviceId: 'dev_counter_01');
    expect(cameras.length, 2);

    // Test connection states and preview stream
    expect(usbCam.state, CameraConnectionState.disconnected);
    await usbCam.connect();
    expect(usbCam.state, CameraConnectionState.streaming);

    final stream = usbCam.startStream();
    final receivedChunks = <List<int>>[];
    final sub = stream.listen(receivedChunks.add);

    final dummyFrame = List.generate(100, (i) => i % 256);
    usbCam.emitChunk(dummyFrame);
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(receivedChunks.length, 1);
    expect(receivedChunks.first.length, 100);

    await sub.cancel();
    await usbCam.disconnect();
    expect(usbCam.state, CameraConnectionState.disconnected);
    db.close();
  });

  // -------------------------------------------------------------
  // 2. Segmented Continuous Recording Pipeline Tests
  // -------------------------------------------------------------
  await testAsync('SegmentedRecorder writes atomic segments, computes SHA-256, and rotates on boundaries', () async {
    final db = createDb();
    seedEcosystem(db);
    final tempDir = createTempStorageDir();
    final storageService = FileStorageService(tempDir.path);
    final discovery = CameraDiscoveryService(db: db);

    final camera = discovery.registerCamera(
      name: 'Storage Zone Cam',
      type: CameraSourceType.usb,
      sourceUrl: '/dev/video1',
      deviceId: 'dev_counter_01',
    );

    // Configure recorder with small byte threshold (200 bytes) for boundary rotation
    final recorder = SegmentedRecorder(
      db: db,
      storageService: storageService,
      targetSegmentDuration: const Duration(minutes: 5),
      maxSegmentBytes: 200,
    );

    await camera.connect();
    await recorder.startRecording(camera);
    assertTrue(recorder.isCameraRecording(camera.id));

    // Emit 150 bytes (within segment 1)
    final chunk1 = List.generate(150, (i) => 0xAA);
    camera.emitChunk(chunk1);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    // Emit 100 bytes (exceeds 200 bytes -> triggers boundary rotation)
    final chunk2 = List.generate(100, (i) => 0xBB);
    camera.emitChunk(chunk2);
    // Allow segment 1 to flush, promote, and rotate to segment 2
    await Future<void>.delayed(const Duration(milliseconds: 50));

    // Emit 80 bytes into segment 2
    final chunk3 = List.generate(80, (i) => 0xCC);
    camera.emitChunk(chunk3);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    // Finalize recording (finalizes segment 2)
    final seg2 = await recorder.stopRecording(camera);
    assertTrue(seg2 != null);
    expect(seg2!.fileSizeBytes, 80);

    // Verify two segments exist in DB
    final rows = db.connection.select('SELECT * FROM cctv_segments WHERE camera_id = ? ORDER BY start_time ASC', [camera.id]);
    expect(rows.length, 2);

    // Verify segment 1 properties
    final row1 = rows.first;
    expect(row1['file_size_bytes'], 250); // 150 + 100 before boundary was processed
    final filePath1 = row1['file_path'] as String;
    assertTrue(storageService.exists(StorageCategory.cctvRecordings, filePath1));

    // Verify SHA-256 of physical file matches DB checksum
    final fileBytes1 = await storageService.readBytes(StorageCategory.cctvRecordings, filePath1);
    final calculatedSha256 = sha256.convert(fileBytes1).toString();
    expect(row1['sha256_checksum'], calculatedSha256);

    await recorder.dispose();
    camera.dispose();
    db.close();
    tempDir.deleteSync(recursive: true);
  });

  // -------------------------------------------------------------
  // 3. Timeline Playback & Bookmarking Tests
  // -------------------------------------------------------------
  await testAsync('TimelinePlayback allows segment range queries, playback streaming, and protection toggle', () async {
    final db = createDb();
    seedEcosystem(db);
    final tempDir = createTempStorageDir();
    final storageService = FileStorageService(tempDir.path);
    final discovery = CameraDiscoveryService(db: db);
    final playback = TimelinePlayback(db: db, storageService: storageService);

    final camera = discovery.registerCamera(
      name: 'Entrance Cam',
      type: CameraSourceType.ip,
      sourceUrl: 'http://192.168.1.60:8080/video',
      deviceId: 'dev_counter_01',
    );

    // Create a recording segment manually
    final recorder = SegmentedRecorder(db: db, storageService: storageService);
    await camera.connect();
    await recorder.startRecording(camera);

    final mediaData = List.generate(500, (i) => i % 128);
    camera.emitChunk(mediaData);
    await Future<void>.delayed(const Duration(milliseconds: 10));

    final segment = await recorder.stopRecording(camera);
    assertTrue(segment != null);

    // 1. Query segments
    final segments = playback.querySegments(camera.id);
    expect(segments.length, 1);
    expect(segments.first.id, segment!.id);

    // 2. Playback stream
    final playbackBytes = await playback.openPlaybackStream(segment.id).expand((chunk) => chunk).toList();
    expect(playbackBytes.length, 500);
    expect(playbackBytes, mediaData);

    // 3. Segment protection / bookmarking
    expect(playback.querySegments(camera.id, onlyProtected: true).length, 0);

    playback.setSegmentProtected(segment.id, true, actorId: 'usr_owner_01', deviceId: 'dev_counter_01');
    final protectedSegments = playback.querySegments(camera.id, onlyProtected: true);
    expect(protectedSegments.length, 1);
    expect(protectedSegments.first.id, segment.id);
    assertTrue(protectedSegments.first.isProtected);

    // Verify audit log
    final auditRows = db.connection.select("SELECT * FROM audit_logs WHERE action = 'CCTV_SEGMENT_PROTECTED'");
    expect(auditRows.length, 1);
    expect(auditRows.first['entity_id'], segment.id);

    await recorder.dispose();
    camera.dispose();
    db.close();
    tempDir.deleteSync(recursive: true);
  });

  // -------------------------------------------------------------
  // 4. MASTER GOLDEN TEST #105 (Rule 105)
  // -------------------------------------------------------------
  await testAsync('Golden Test 105: Resilient CCTV recording, disconnect handling, reconnect resume, and retention purge safety', () async {
    // =========================================================================
    // GOLDEN TEST 105 SCENARIO SPECIFICATION (Rule 105):
    // 1. Discover camera
    // 2. Preview live stream
    // 3. Start continuous recording (creates segment 1)
    // 4. Emit media frames
    // 5. Hardware disconnects mid-stream (cable unplugged / power cut)
    // 6. In-flight segment 1 finalizes cleanly without corruption (zero corrupt files)
    // 7. Reconnect camera
    // 8. Resume recording creating valid segment 2
    // 9. Timeline playback across segments
    // 10. Protect segment 1 (is_protected = true)
    // 11. Trigger retention cleanup under disk pressure:
    //     - Unprotected segment 2 is purged to free disk space
    //     - Protected segment 1 strictly survives retention purge intact
    // EXPECTED:
    //     - No corrupt completed segments
    //     - No fake recording state
    //     - Sacred retention law strictly preserved
    // =========================================================================

    final db = createDb();
    seedEcosystem(db);
    final tempDir = createTempStorageDir();
    final storageService = FileStorageService(tempDir.path);
    final discovery = CameraDiscoveryService(db: db);
    final playback = TimelinePlayback(db: db, storageService: storageService);

    // 1. DISCOVER CAMERA
    final camera = discovery.registerCamera(
      name: 'Golden Test Front Camera',
      type: CameraSourceType.usb,
      sourceUrl: '/dev/video_golden',
      deviceId: 'dev_counter_01',
    );
    expect(camera.name, 'Golden Test Front Camera');

    // 2. PREVIEW LIVE STREAM
    await camera.connect();
    expect(camera.state, CameraConnectionState.streaming);

    // 3. START CONTINUOUS RECORDING (Segment 1)
    final recorder = SegmentedRecorder(
      db: db,
      storageService: storageService,
      targetSegmentDuration: const Duration(minutes: 5),
      maxSegmentBytes: 10 * 1024 * 1024,
    );

    await recorder.startRecording(camera);
    expect(camera.state, CameraConnectionState.recording);
    assertTrue(recorder.isCameraRecording(camera.id));

    // 4. EMIT MEDIA FRAMES
    final frameData1 = List.generate(400, (i) => 0x11);
    camera.emitChunk(frameData1);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    // 5. HARDWARE DISCONNECTS MID-STREAM
    // Simulate sudden unplugging while recording is active
    camera.simulateHardwareDrop();
    await Future<void>.delayed(const Duration(milliseconds: 30));

    // 6. VERIFY IN-FLIGHT SEGMENT 1 FINALIZED CLEANLY (ZERO CORRUPTION)
    expect(camera.state, CameraConnectionState.disconnected);
    expect(recorder.isCameraRecording(camera.id), false);

    // Verify DB camera state is not stuck in fake recording
    final camRow = db.connection.select('SELECT is_recording FROM cctv_cameras WHERE id = ?', [camera.id]);
    expect(camRow.first['is_recording'], 0);

    // Verify disconnect event was logged
    final evtRows = db.connection.select("SELECT * FROM cctv_events WHERE camera_id = ? AND event_type = 'DISCONNECT'", [camera.id]);
    expect(evtRows.length, 1);

    // Verify segment 1 was finalized and is physically valid on disk
    final segRows1 = db.connection.select('SELECT * FROM cctv_segments WHERE camera_id = ?', [camera.id]);
    expect(segRows1.length, 1);
    final seg1Id = segRows1.first['id'] as String;
    final seg1Path = segRows1.first['file_path'] as String;
    expect(segRows1.first['is_corrupted'], 0);
    expect(segRows1.first['file_size_bytes'], 400);

    assertTrue(playback.isSegmentPhysicallyPresent(seg1Id));
    final seg1BytesOnDisk = await storageService.readBytes(StorageCategory.cctvRecordings, seg1Path);
    expect(seg1BytesOnDisk.length, 400);
    expect(seg1BytesOnDisk, frameData1);
    expect(sha256.convert(seg1BytesOnDisk).toString(), segRows1.first['sha256_checksum']);

    // 7. RECONNECT CAMERA
    await camera.connect();
    expect(camera.state, CameraConnectionState.streaming);

    // 8. RESUME RECORDING CREATING VALID SEGMENT 2
    await recorder.startRecording(camera);
    expect(camera.state, CameraConnectionState.recording);

    final frameData2 = List.generate(600, (i) => 0x22);
    camera.emitChunk(frameData2);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final seg2 = await recorder.stopRecording(camera);
    assertTrue(seg2 != null);
    expect(seg2!.fileSizeBytes, 600);

    // 9. TIMELINE PLAYBACK ACROSS BOTH SEGMENTS
    final allSegments = playback.querySegments(camera.id);
    expect(allSegments.length, 2);
    expect(allSegments[0].id, seg1Id);
    expect(allSegments[1].id, seg2.id);

    // 10. PROTECT SEGMENT 1 (is_protected = true)
    playback.setSegmentProtected(seg1Id, true, actorId: 'usr_owner_01', deviceId: 'dev_counter_01');
    assertTrue(playback.querySegments(camera.id, onlyProtected: true).isNotEmpty);

    // 11. TRIGGER RETENTION CLEANUP UNDER DISK PRESSURE
    final retentionCleaner = RetentionCleaner(
      db: db,
      storageService: storageService,
      recorder: recorder,
    );

    // Request retention purge to free 500 bytes of space
    final purgeResult = await retentionCleaner.executeRetentionCleanup(
      bytesToFree: 500,
      actorId: 'usr_owner_01',
      deviceId: 'dev_counter_01',
    );

    // VERIFICATION OF SACRED RETENTION LAW (Rule 63 & 105):
    // 1. Unprotected segment 2 was purged (freed 600 bytes)
    expect(purgeResult.purgedCount, 1);
    expect(purgeResult.purgedSegmentIds, [seg2.id]);
    expect(purgeResult.freedBytes, 600);
    expect(playback.isSegmentPhysicallyPresent(seg2.id), false);
    final remainingSeg2Db = db.connection.select('SELECT * FROM cctv_segments WHERE id = ?', [seg2.id]);
    expect(remainingSeg2Db.isEmpty, true);

    // 2. Protected segment 1 STRICTLY SURVIVED intact
    expect(playback.isSegmentPhysicallyPresent(seg1Id), true);
    final remainingSeg1Db = db.connection.select('SELECT * FROM cctv_segments WHERE id = ?', [seg1Id]);
    expect(remainingSeg1Db.length, 1);
    expect(remainingSeg1Db.first['is_protected'], 1);

    final seg1SurvivingBytes = await storageService.readBytes(StorageCategory.cctvRecordings, seg1Path);
    expect(seg1SurvivingBytes, frameData1);
    expect(sha256.convert(seg1SurvivingBytes).toString(), remainingSeg1Db.first['sha256_checksum']);

    // 3. Verify audit log was recorded for retention purge
    final purgeAudit = db.connection.select("SELECT * FROM audit_logs WHERE action = 'CCTV_RETENTION_PURGE'");
    expect(purgeAudit.length, 1);

    await recorder.dispose();
    camera.dispose();
    db.close();
    tempDir.deleteSync(recursive: true);
  });

  // Summary
  // ignore: avoid_print
  print('\n=== CCTV Monitoring & Recording Tests Summary ===');
  // ignore: avoid_print
  print('Passed: $passed, Failed: $failed');
  if (failed > 0) {
    throw Exception('$failed tests failed in CCTV Monitoring & Recording (Phase 11)!');
  }
}
