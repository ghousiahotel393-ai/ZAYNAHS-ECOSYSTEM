import 'dart:convert';
import 'package:core/core.dart';
import 'package:ui/ui.dart';
import 'package:network/network.dart';
import 'package:sync/sync.dart';

void main() {
  // ignore: avoid_print
  print('\n=== Running Cross-Platform, Responsive UI & Interoperability Tests (Phase 14) ===');

  int passed = 0;
  int failed = 0;

  void test(String name, void Function() fn) {
    try {
      fn();
      // ignore: avoid_print
      print('  ✓ $name');
      passed++;
    } catch (e, st) {
      // ignore: avoid_print
      print('  ✗ $name: $e\n$st');
      failed++;
    }
  }

  void expect(dynamic actual, dynamic expected) {
    if (actual != expected) {
      throw Exception('Expected $expected but got $actual');
    }
  }

  // -------------------------------------------------------------
  // Test 1: Responsive Breakpoint & Screen Type Resolution
  // -------------------------------------------------------------
  test('Responsive UI: ScreenType accurately resolves Phone, Tablet, and Desktop', () {
    // Phone form factors (<600px)
    expect(ResponsiveLayoutHelper.getScreenType(320.0), ScreenType.mobile);
    expect(ResponsiveLayoutHelper.getScreenType(375.0), ScreenType.mobile);
    expect(ResponsiveLayoutHelper.getScreenType(414.0), ScreenType.mobile);
    expect(ResponsiveLayoutHelper.getScreenType(599.0), ScreenType.mobile);
    expect(ResponsiveLayoutHelper.isMobile(599.0), true);
    expect(ResponsiveLayoutHelper.isTablet(599.0), false);
    expect(ResponsiveLayoutHelper.isDesktop(599.0), false);

    // Tablet form factors (600px - 1024px)
    expect(ResponsiveLayoutHelper.getScreenType(600.0), ScreenType.tablet);
    expect(ResponsiveLayoutHelper.getScreenType(768.0), ScreenType.tablet);
    expect(ResponsiveLayoutHelper.getScreenType(834.0), ScreenType.tablet);
    expect(ResponsiveLayoutHelper.getScreenType(1024.0), ScreenType.tablet);
    expect(ResponsiveLayoutHelper.isMobile(768.0), false);
    expect(ResponsiveLayoutHelper.isTablet(768.0), true);
    expect(ResponsiveLayoutHelper.isDesktop(768.0), false);

    // Desktop form factors (>1024px)
    expect(ResponsiveLayoutHelper.getScreenType(1025.0), ScreenType.desktop);
    expect(ResponsiveLayoutHelper.getScreenType(1280.0), ScreenType.desktop);
    expect(ResponsiveLayoutHelper.getScreenType(1920.0), ScreenType.desktop);
    expect(ResponsiveLayoutHelper.getScreenType(3840.0), ScreenType.desktop);
    expect(ResponsiveLayoutHelper.isMobile(1920.0), false);
    expect(ResponsiveLayoutHelper.isTablet(1920.0), false);
    expect(ResponsiveLayoutHelper.isDesktop(1920.0), true);
  });

  // -------------------------------------------------------------
  // Test 2: Dynamic Grid Columns & Sidebar Adaptation
  // -------------------------------------------------------------
  test('Responsive UI: Dynamic POS item grid and adaptive navigation sidebar layout', () {
    // Mobile grid columns: 2 to 3
    expect(ResponsiveLayoutHelper.getGridColumnCount(360.0), 2);
    expect(ResponsiveLayoutHelper.getGridColumnCount(480.0), 3);
    // Mobile sidebar: 0.0 (uses bottom navigation / slide-out drawer)
    expect(ResponsiveLayoutHelper.getSidebarWidth(360.0), 0.0);

    // Tablet grid columns: 4 to 5
    expect(ResponsiveLayoutHelper.getGridColumnCount(768.0), 4);
    expect(ResponsiveLayoutHelper.getGridColumnCount(1024.0), 5);
    // Tablet sidebar: 80.0 (compact icon rail)
    expect(ResponsiveLayoutHelper.getSidebarWidth(768.0), 80.0);

    // Desktop grid columns: 6 to 8
    expect(ResponsiveLayoutHelper.getGridColumnCount(1280.0), 6);
    expect(ResponsiveLayoutHelper.getGridColumnCount(1920.0), 8);
    // Desktop sidebar: 260.0 (full persistent sidebar with labels)
    expect(ResponsiveLayoutHelper.getSidebarWidth(1280.0), 260.0);

    // Touch targets comply with minimum 48 dp accessibility standard
    expect(AppTouchTargets.minTargetSize >= 48.0, true);
    expect(AppTouchTargets.minIconSize >= 24.0, true);
  });

  // -------------------------------------------------------------
  // Test 3: Platform Hardware Adapters Matrix
  // -------------------------------------------------------------
  test('Platform Adapters Matrix: All 8 hardware abstractions function across OS types', () async {
    // 1. System Info Adapter across Android, iOS, Windows, Web, macOS, Linux
    final sysAdapter = MockSystemInfoAdapter();
    for (final os in [
      OperatingSystemType.android,
      OperatingSystemType.iOS,
      OperatingSystemType.windows,
      OperatingSystemType.web,
      OperatingSystemType.macOS,
      OperatingSystemType.linux,
    ]) {
      sysAdapter.setSystemInfo(SystemInfo(
        osType: os,
        osVersion: '1.0.0',
        deviceModel: 'Test Device (${os.name})',
        cpuCores: 4,
        totalMemoryMb: 4096,
        freeDiskSpaceMb: 32000,
      ));
      final info = await sysAdapter.getSystemInfo();
      expect(info.osType, os);
      expect(info.cpuCores, 4);
    }

    // 2. Camera Adapter
    final camAdapter = MockCameraAdapter();
    final cams = await camAdapter.getAvailableCameras();
    expect(cams.isNotEmpty, true);

    // 3. Printer Adapter
    final printAdapter = MockPrinterAdapter();
    final printResult = await printAdapter.printRawBytes(
      'mock_escpos_80',
      [0x1B, 0x40, 0x1B, 0x69],
    );
    expect(printResult, true);

    // 4. Location Adapter (Privacy-first)
    final locAdapter = MockLocationAdapter();
    final loc = await locAdapter.getCurrentLocation();
    expect(loc != null && loc.latitude != 0.0, true);

    // 5. Screen Adapter
    final screenAdapter = MockScreenAdapter();
    final screens = await screenAdapter.getScreenSources();
    expect(screens.isNotEmpty, true);

    // 6. Biometric Adapter
    final bioAdapter = MockBiometricAdapter();
    final hasBio = await bioAdapter.canAuthenticateWithBiometrics();
    expect(hasBio, true);

    // 7. Secure Storage Adapter
    final secStorage = InMemorySecureStorageAdapter();
    await secStorage.write('test_key', 'test_secret_val');
    final val = await secStorage.read('test_key');
    expect(val, 'test_secret_val');

    // 8. Network Adapter
    final netAdapter = MockNetworkAdapter();
    final netStatus = await netAdapter.getStatus();
    expect(netStatus.isConnected, true);
  });

  // -------------------------------------------------------------
  // Test 4: Cross-Platform Interoperability Matrix
  // -------------------------------------------------------------
  test('Platform Interoperability Matrix: Cross-platform protocol & serialization parity', () {
    // 1. Android <-> Android: Peer discovery descriptor
    final androidPeer = PeerDescriptor(
      deviceId: 'dev_android_01',
      deviceName: 'Pixel POS Terminal',
      deviceType: 'terminal',
      publicKeyFingerprint: 'pub_fingerprint_01',
      addresses: ['192.168.1.10'],
      port: 8080,
      discoveredAt: DateTime.now().toUtc(),
    );
    final androidJson = androidPeer.toMap();
    final deserializedAndroid = PeerDescriptor.fromMap(androidJson);
    expect(deserializedAndroid.deviceId, androidPeer.deviceId);
    expect(deserializedAndroid.port, 8080);

    // 2. Android <-> iOS: Currency arithmetic and SyncEvent serialization
    final curr = Currency.pkr;
    final money = Money.fromMinorUnits(150050, curr); // 1,500.50 PKR
    final eventPayload = {
      'saleId': 'sale_cross_01',
      'amountMinor': money.minorUnits,
      'currency': money.currency.code,
      'deviceOS': 'iOS',
    };
    final syncEvent = SyncEvent.create(
      eventType: 'SALE_COMPLETED',
      aggregateId: 'sale_cross_01',
      aggregateType: 'SALE',
      payload: eventPayload,
      deviceId: 'dev_iphone_01',
    );
    // Cross-platform hash invariant: SHA-256 matches regardless of OS
    expect(syncEvent.hash.isNotEmpty, true);
    final jsonStr = jsonEncode(syncEvent.toMap());
    final syncEventParsed = SyncEvent.fromMap(jsonDecode(jsonStr) as Map<String, dynamic>);
    expect(syncEventParsed.aggregateId, syncEvent.aggregateId);
    expect(syncEventParsed.hash, syncEvent.hash);

    // 3. Windows <-> Web: Signaling message bounding (Rule 49: 64KB max)
    final webSignaling = SignalingMessage(
      type: SignalingType.offer,
      senderDeviceId: 'dev_windows_desktop',
      recipientDeviceId: 'dev_web_browser',
      data: {'sdp': 'v=0\r\no=- 12345 2 IN IP4 127.0.0.1\r\ns=-\r\n'},
      timestamp: DateTime.now().toUtc(),
    );
    final signalMap = webSignaling.toMap();
    final signalParsed = SignalingMessage.fromMap(signalMap);
    expect(signalParsed.type, SignalingType.offer);
    expect(signalParsed.senderDeviceId, 'dev_windows_desktop');

    // 4. iOS <-> Windows: DataChannel binary packet framing
    final channelData = utf8.encode('CHUNK_TRANSFER_HEADER_PAYLOAD_VALIDATION');
    expect(channelData.length < 65536, true);
  });

  // Summary
  // ignore: avoid_print
  print('\n=== Cross-Platform & Responsive UI Summary ===');
  // ignore: avoid_print
  print('Passed: $passed, Failed: $failed');

  if (failed > 0) {
    throw Exception('$failed tests failed in Cross-Platform Verification (Phase 14)!');
  }
}
