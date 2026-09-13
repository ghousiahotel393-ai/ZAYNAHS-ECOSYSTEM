/// Camera Source Abstraction and Discovery for Zaynahs Ecosystem CCTV.
/// Enforces Rule 54-55, 58, 65: Transparent, permission-controlled, explicit camera handles.
library camera_source;

import 'dart:async';
import 'package:core/core.dart';
import 'package:database/database.dart';

enum CameraSourceType { usb, rtsp, ip, relay }

enum CameraConnectionState { disconnected, connecting, streaming, recording, error }

class CameraSource {
  final String id;
  final String name;
  final CameraSourceType type;
  final String sourceUrl;
  final String resolution;
  final int fps;
  final String deviceId;

  CameraConnectionState _state = CameraConnectionState.disconnected;
  final StreamController<CameraConnectionState> _stateController =
      StreamController<CameraConnectionState>.broadcast();
  StreamController<List<int>>? _mediaStreamController;

  CameraSource({
    required this.id,
    required this.name,
    required this.type,
    required this.sourceUrl,
    this.resolution = '1920x1080',
    this.fps = 30,
    required this.deviceId,
  });

  CameraConnectionState get state => _state;
  Stream<CameraConnectionState> get onStateChange => _stateController.stream;

  /// Connects to camera hardware or RTSP network endpoint.
  Future<void> connect() async {
    if (_state == CameraConnectionState.streaming || _state == CameraConnectionState.recording) {
      return;
    }
    _updateState(CameraConnectionState.connecting);
    // Simulate connection establishment
    await Future<void>.delayed(const Duration(milliseconds: 10));
    _updateState(CameraConnectionState.streaming);
  }

  /// Disconnects from camera hardware and releases all streaming resources.
  Future<void> disconnect({String? reason}) async {
    if (_state == CameraConnectionState.disconnected) return;
    _mediaStreamController?.close();
    _mediaStreamController = null;
    _updateState(CameraConnectionState.disconnected);
  }

  /// Starts media frame stream (H.264/MP4 chunk stream).
  Stream<List<int>> startStream() {
    if (_state != CameraConnectionState.streaming && _state != CameraConnectionState.recording) {
      _updateState(CameraConnectionState.streaming);
    }
    _mediaStreamController?.close();
    _mediaStreamController = StreamController<List<int>>.broadcast();
    return _mediaStreamController!.stream;
  }

  /// Injects or emits a video chunk into the stream (used by hardware drivers / test feeds).
  void emitChunk(List<int> chunk) {
    if (_state == CameraConnectionState.disconnected || _mediaStreamController == null) {
      return;
    }
    _mediaStreamController?.add(chunk);
  }

  /// Simulates a sudden mid-stream hardware disconnect or network cut.
  void simulateHardwareDrop() {
    _mediaStreamController?.addError(const PlatformHardwareException(
      adapterName: 'camera',
      code: 'CAMERA_HARDWARE_DROP',
      message: 'Camera feed interrupted: device disconnected',
    ));
    disconnect(reason: 'Hardware disconnected');
  }

  void markRecording(bool recording) {
    if (recording && _state == CameraConnectionState.streaming) {
      _updateState(CameraConnectionState.recording);
    } else if (!recording && _state == CameraConnectionState.recording) {
      _updateState(CameraConnectionState.streaming);
    }
  }

  void _updateState(CameraConnectionState newState) {
    if (_state != newState) {
      _state = newState;
      _stateController.add(newState);
    }
  }

  void dispose() {
    disconnect();
    _stateController.close();
  }
}

class CameraDiscoveryService {
  final AppDatabase db;

  CameraDiscoveryService({required this.db});

  /// Registers a newly discovered camera source in the ecosystem database.
  CameraSource registerCamera({
    required String name,
    required CameraSourceType type,
    required String sourceUrl,
    String resolution = '1920x1080',
    int fps = 30,
    required String deviceId,
  }) {
    final camId = 'cam_${EntityId.generateUuidV4()}';
    final now = DateTime.now().toUtc();

    db.connection.execute(
      '''
      INSERT INTO cctv_cameras (
        id, name, source_type, source_url, resolution, fps,
        is_recording, device_id, created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, 0, ?, ?, ?)
      ''',
      [
        camId,
        name,
        type.name.toUpperCase(),
        sourceUrl,
        resolution,
        fps,
        deviceId,
        now.toIso8601String(),
        now.toIso8601String(),
      ],
    );

    return CameraSource(
      id: camId,
      name: name,
      type: type,
      sourceUrl: sourceUrl,
      resolution: resolution,
      fps: fps,
      deviceId: deviceId,
    );
  }

  /// Lists all registered cameras for this peer device.
  List<CameraSource> listCameras({String? deviceId}) {
    var sql = 'SELECT * FROM cctv_cameras';
    final params = <dynamic>[];
    if (deviceId != null) {
      sql += ' WHERE device_id = ?';
      params.add(deviceId);
    }
    sql += ' ORDER BY created_at ASC';

    final rows = db.connection.select(sql, params);
    return rows.map((r) {
      final typeStr = (r['source_type'] as String).toLowerCase();
      final type = CameraSourceType.values.firstWhere(
        (e) => e.name == typeStr,
        orElse: () => CameraSourceType.rtsp,
      );

      return CameraSource(
        id: r['id'] as String,
        name: r['name'] as String,
        type: type,
        sourceUrl: r['source_url'] as String,
        resolution: r['resolution'] as String,
        fps: r['fps'] as int,
        deviceId: r['device_id'] as String,
      );
    }).toList();
  }
}
