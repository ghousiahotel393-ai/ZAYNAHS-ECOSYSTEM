import 'dart:convert';
import 'dart:io';
import 'package:auth/auth.dart';
import 'package:core/core.dart';
import 'package:database/database.dart';
import 'package:network/network.dart';

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
  print('\n=== Running P2P & WebRTC Foundation Tests ===');

  // 1. PeerDescriptor Serialization
  test('PeerDescriptor serializes to and from JSON preserving all metadata', () {
    final now = DateTime.now().toUtc();
    final descriptor = PeerDescriptor(
      deviceId: 'dev_terminal_01',
      deviceName: 'Counter Register 1',
      deviceType: 'pos_register',
      publicKeyFingerprint: 'sha256_fp_abc123',
      addresses: ['192.168.1.50', '10.0.0.5'],
      port: 45454,
      discoveredAt: now,
    );

    final jsonStr = descriptor.toJson();
    final restored = PeerDescriptor.fromJson(jsonStr);

    expect(restored.deviceId, 'dev_terminal_01');
    expect(restored.deviceName, 'Counter Register 1');
    expect(restored.deviceType, 'pos_register');
    expect(restored.publicKeyFingerprint, 'sha256_fp_abc123');
    expect(restored.addresses.length, 2);
    expect(restored.addresses[0], '192.168.1.50');
    expect(restored.port, 45454);
  });

  // 2. LAN Discovery & Trusted Device Security Gate
  test('LanDiscoveryService discovers trusted peers and strictly filters untrusted beacons', () {
    final db = AppDatabase.openInMemory();
    db.initialize();
    final repo = DeviceRepository(db);
    final trustManager = DeviceTrustManager(repo);

    repo.registerPendingDevice(DeviceEntity(
      id: 'dev_trusted',
      name: 'Trusted Peer',
      trustStatus: 'PENDING',
      publicKey: 'pk_trusted',
      lastSeenAt: DateTime.now().toUtc(),
      ipAddress: '192.168.1.100',
    ));
    repo.setTrustStatus('dev_trusted', 'TRUSTED');

    repo.registerPendingDevice(DeviceEntity(
      id: 'dev_pending',
      name: 'Pending Peer',
      trustStatus: 'PENDING',
      publicKey: 'pk_pending',
      lastSeenAt: DateTime.now().toUtc(),
      ipAddress: '192.168.1.101',
    ));

    final localDescriptor = PeerDescriptor(
      deviceId: 'dev_local',
      deviceName: 'Local Node',
      deviceType: 'terminal',
      publicKeyFingerprint: 'fp_local',
      addresses: ['192.168.1.10'],
      port: 45454,
      discoveredAt: DateTime.now().toUtc(),
    );

    final discoveryService = LanDiscoveryService(
      localDescriptor: localDescriptor,
      trustManager: trustManager,
    );

    // Test 1: Ingest trusted peer beacon -> Accepted
    final trustedBeacon = PeerDescriptor(
      deviceId: 'dev_trusted',
      deviceName: 'Trusted Peer',
      deviceType: 'pos_register',
      publicKeyFingerprint: 'fp_trusted',
      addresses: ['192.168.1.100'],
      port: 45454,
      discoveredAt: DateTime.now().toUtc(),
    ).toJson();

    final accepted = discoveryService.handleIncomingBeacon(trustedBeacon);
    assertTrue(accepted, 'Trusted peer beacon must be accepted');
    expect(discoveryService.knownPeers.containsKey('dev_trusted'), true);

    // Test 2: Ingest untrusted / pending peer beacon -> Rejected (Security Gate)
    final untrustedBeacon = PeerDescriptor(
      deviceId: 'dev_pending',
      deviceName: 'Pending Peer',
      deviceType: 'terminal',
      publicKeyFingerprint: 'fp_pending',
      addresses: ['192.168.1.101'],
      port: 45454,
      discoveredAt: DateTime.now().toUtc(),
    ).toJson();

    final rejectedPending = discoveryService.handleIncomingBeacon(untrustedBeacon);
    assertTrue(!rejectedPending, 'Untrusted peer beacon must be strictly rejected');
    expect(discoveryService.knownPeers.containsKey('dev_pending'), false);

    // Test 3: Self-announcement beacon -> Ignored
    final selfBeacon = localDescriptor.toJson();
    final selfIgnored = discoveryService.handleIncomingBeacon(selfBeacon);
    assertTrue(!selfIgnored, 'Self announcement must be ignored');

    discoveryService.dispose();
  });

  // 3. Signaling Client & Strict Prohibition Gate (Rule 49)
  test('SignalingClient routes coordination messages and blocks payloads > 64KB (Rule 49)', () {
    final client = SignalingClient(localDeviceId: 'dev_local');

    // Valid SDP Offer message (< 64KB)
    final validPayload = client.createMessagePayload(
      type: SignalingType.offer,
      recipientDeviceId: 'dev_remote',
      data: {
        'sdp': 'v=0\r\no=- 12345 2 IN IP4 127.0.0.1\r\ns=-\r\nt=0 0\r\n',
        'type': 'offer',
      },
    );

    assertTrue(validPayload.isNotEmpty);
    final parsed = SignalingMessage.fromJson(validPayload);
    expect(parsed.type, SignalingType.offer);
    expect(parsed.senderDeviceId, 'dev_local');
    expect(parsed.recipientDeviceId, 'dev_remote');

    // RULE 49 PROHIBITION TEST: Attempt to send 70KB large binary payload over signaling
    final largeString = 'A' * (70 * 1024); // 70 KB
    bool caught = false;
    try {
      client.createMessagePayload(
        type: SignalingType.offer,
        recipientDeviceId: 'dev_remote',
        data: {'large_file': largeString},
      );
    } on SignalingPayloadTooLargeException catch (e) {
      caught = true;
      assertTrue(e.sizeBytes > 64 * 1024);
      assertTrue(e.maxAllowedBytes == 64 * 1024);
    }

    assertTrue(caught, 'Rule 49: Sending payloads > 64KB over signaling must throw SignalingPayloadTooLargeException');

    client.dispose();
  });

  // 4. DataChannel Multiplexer 4-Channel Routing
  await testAsync('DataChannelMultiplexer routes messages across 4 dedicated channels', () async {
    final multiplexer = DataChannelMultiplexer();

    P2PMessage? receivedSync;
    P2PMessage? receivedFile;
    P2PMessage? receivedChat;
    P2PMessage? receivedControl;

    final subSync = multiplexer.onSyncMessage.listen((msg) => receivedSync = msg);
    final subFile = multiplexer.onFileMessage.listen((msg) => receivedFile = msg);
    final subChat = multiplexer.onChatMessage.listen((msg) => receivedChat = msg);
    final subControl = multiplexer.onControlMessage.listen((msg) => receivedControl = msg);

    // Route message on sync channel
    multiplexer.routeIncoming(
      channel: P2PChannelType.sync,
      senderDeviceId: 'dev_remote',
      payload: utf8.encode('{"event":"SYNC_RECORD"}'),
    );

    // Route message on file channel
    multiplexer.routeIncoming(
      channel: P2PChannelType.file,
      senderDeviceId: 'dev_remote',
      payload: [0, 1, 2, 3, 4],
    );

    // Route message on chat channel
    multiplexer.routeIncoming(
      channel: P2PChannelType.chat,
      senderDeviceId: 'dev_remote',
      payload: utf8.encode('Hello peer'),
    );

    // Route message on control channel
    multiplexer.routeIncoming(
      channel: P2PChannelType.control,
      senderDeviceId: 'dev_remote',
      payload: utf8.encode('PING'),
    );

    await Future.delayed(const Duration(milliseconds: 10));

    assertTrue(receivedSync != null);
    expect(receivedSync!.channel, P2PChannelType.sync);
    expect(utf8.decode(receivedSync!.payload), '{"event":"SYNC_RECORD"}');

    assertTrue(receivedFile != null);
    expect(receivedFile!.channel, P2PChannelType.file);
    expect(receivedFile!.payload.length, 5);

    assertTrue(receivedChat != null);
    expect(receivedChat!.channel, P2PChannelType.chat);
    expect(utf8.decode(receivedChat!.payload), 'Hello peer');

    assertTrue(receivedControl != null);
    expect(receivedControl!.channel, P2PChannelType.control);
    expect(utf8.decode(receivedControl!.payload), 'PING');

    await subSync.cancel();
    await subFile.cancel();
    await subChat.cancel();
    await subControl.cancel();
    multiplexer.dispose();
  });

  // 5. PeerConnectionManager & ICE Restart Lifecycle
  test('PeerConnectionManager manages connection state and ICE restart on network drop', () {
    final manager = PeerConnectionManager(localDeviceId: 'dev_local');

    final session = manager.getOrCreateSession('dev_peer_01');
    expect(session.state, PeerConnectionState.newConn);
    expect(session.iceRestartCount, 0);

    // Transition to connecting then connected
    manager.updateState('dev_peer_01', PeerConnectionState.connecting);
    expect(session.state, PeerConnectionState.connecting);

    manager.updateState('dev_peer_01', PeerConnectionState.connected);
    expect(session.state, PeerConnectionState.connected);

    // Network transition occurs: trigger ICE restart
    final restarted = manager.triggerIceRestart('dev_peer_01');
    assertTrue(restarted);
    expect(session.iceRestartCount, 1);
    expect(session.state, PeerConnectionState.connecting);

    // Close session
    manager.closeSession('dev_peer_01');
    expect(manager.activeSessions.containsKey('dev_peer_01'), false);

    manager.dispose();
  });

  // ignore: avoid_print
  print('\nP2P tests summary: $passed passed, $failed failed.');
  if (failed > 0) {
    exit(1);
  }
}
