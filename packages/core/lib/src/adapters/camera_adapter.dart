/// Platform Camera Abstraction Interface and Test Mock.
/// Complies with Rule 54-65 (Media Privacy and Segmented CCTV Recording).
library camera_adapter;

import 'dart:async';

enum CameraType { builtin, usb, rtsp, ip }
enum CameraStatus { idle, previewing, recording, error, disconnected }

class CameraDeviceInfo {
  final String id;
  final String name;
  final CameraType type;
  final int maxWidth;
  final int maxHeight;
  final int maxFps;
  final String? rtspUrl;

  const CameraDeviceInfo({
    required this.id,
    required this.name,
    required this.type,
    this.maxWidth = 1920,
    this.maxHeight = 1080,
    this.maxFps = 30,
    this.rtspUrl,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.name,
        'maxWidth': maxWidth,
        'maxHeight': maxHeight,
        'maxFps': maxFps,
        if (rtspUrl != null) 'rtspUrl': rtspUrl,
      };
}

abstract class CameraAdapter {
  /// Lists all available cameras (built-in, USB webcams, configured RTSP feeds).
  Future<List<CameraDeviceInfo>> getAvailableCameras();

  /// Requests hardware camera permission from the operating system.
  Future<bool> requestPermission();

  /// Checks if hardware camera permission is currently granted.
  Future<bool> hasPermission();

  /// Initializes a camera device.
  Future<void> initialize(String cameraId);

  /// Starts preview stream.
  Future<Stream<List<int>>> startPreview(String cameraId);

  /// Captures a single image frame (e.g. for barcode scanning or snapshot).
  Future<List<int>> captureFrame(String cameraId);

  /// Starts segmented video recording into target chunk path.
  Future<void> startRecording(String cameraId, String destinationPath);

  /// Stops ongoing recording.
  Future<void> stopRecording(String cameraId);

  /// Releases resources.
  Future<void> dispose(String cameraId);
}

/// Headless Mock Camera Adapter for Unit and Integration Testing.
class MockCameraAdapter implements CameraAdapter {
  bool _permissionGranted = true;
  final List<CameraDeviceInfo> _cameras = [
    const CameraDeviceInfo(
      id: 'cam_mock_01',
      name: 'Builtin Front Camera',
      type: CameraType.builtin,
      maxWidth: 1280,
      maxHeight: 720,
      maxFps: 30,
    ),
    const CameraDeviceInfo(
      id: 'cam_mock_02',
      name: 'POS Overhead USB Camera',
      type: CameraType.usb,
      maxWidth: 1920,
      maxHeight: 1080,
      maxFps: 30,
    ),
  ];

  final Map<String, CameraStatus> _status = {};

  void setPermission(bool granted) => _permissionGranted = granted;

  @override
  Future<List<CameraDeviceInfo>> getAvailableCameras() async =>
      List.unmodifiable(_cameras);

  @override
  Future<bool> requestPermission() async => _permissionGranted;

  @override
  Future<bool> hasPermission() async => _permissionGranted;

  @override
  Future<void> initialize(String cameraId) async {
    _status[cameraId] = CameraStatus.idle;
  }

  @override
  Future<Stream<List<int>>> startPreview(String cameraId) async {
    _status[cameraId] = CameraStatus.previewing;
    return Stream.periodic(
      const Duration(milliseconds: 100),
      (count) => List<int>.filled(1024, count % 256),
    );
  }

  @override
  Future<List<int>> captureFrame(String cameraId) async {
    return List<int>.generate(2048, (i) => i % 256);
  }

  @override
  Future<void> startRecording(String cameraId, String destinationPath) async {
    _status[cameraId] = CameraStatus.recording;
  }

  @override
  Future<void> stopRecording(String cameraId) async {
    _status[cameraId] = CameraStatus.idle;
  }

  @override
  Future<void> dispose(String cameraId) async {
    _status.remove(cameraId);
  }
}
