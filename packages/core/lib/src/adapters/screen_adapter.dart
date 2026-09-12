/// Platform Screen Sharing & Capture Abstraction Interface and Test Mock.
/// Complies with Rule 54 (Strict Media Privacy & Screen Share Indicators).
library screen_adapter;

import 'dart:async';

class ScreenSourceInfo {
  final String id;
  final String title;
  final bool isWindow; // true if specific window, false if whole screen

  const ScreenSourceInfo({
    required this.id,
    required this.title,
    this.isWindow = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'isWindow': isWindow,
      };
}

abstract class ScreenAdapter {
  /// Lists shareable desktop screens and application windows.
  Future<List<ScreenSourceInfo>> getScreenSources();

  /// Starts capturing screen frames with required visible indicator.
  Future<Stream<List<int>>> startCapture(String sourceId);

  /// Stops screen capturing.
  Future<void> stopCapture();

  /// Returns true if screen is currently actively being captured or shared.
  bool get isCapturing;
}

/// Headless Mock Screen Adapter for Testing.
class MockScreenAdapter implements ScreenAdapter {
  bool _isCapturing = false;

  final List<ScreenSourceInfo> _sources = [
    const ScreenSourceInfo(id: 'display_1', title: 'Main Display', isWindow: false),
    const ScreenSourceInfo(id: 'win_1', title: 'Zaynahs POS', isWindow: true),
  ];

  @override
  bool get isCapturing => _isCapturing;

  @override
  Future<List<ScreenSourceInfo>> getScreenSources() async =>
      List.unmodifiable(_sources);

  @override
  Future<Stream<List<int>>> startCapture(String sourceId) async {
    _isCapturing = true;
    return Stream.periodic(
      const Duration(milliseconds: 100),
      (count) => List<int>.filled(4096, count % 256),
    );
  }

  @override
  Future<void> stopCapture() async {
    _isCapturing = false;
  }
}
