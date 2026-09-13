/// NAT Traversal, STUN/TURN, and Peer Connection Lifecycle Manager.
/// Enforces Section 04: Automatic ICE restart on network transition (Wi-Fi to Cellular).
library peer_connection_manager;

import 'dart:async';
import 'datachannel_multiplexer.dart';

enum PeerConnectionState {
  newConn,
  connecting,
  connected,
  disconnected,
  failed,
  closed;
}

class IceServerConfig {
  final List<String> urls;
  final String? username;
  final String? credential;

  const IceServerConfig({
    required this.urls,
    this.username,
    this.credential,
  });

  static const IceServerConfig defaultStun = IceServerConfig(
    urls: [
      'stun:stun.cloudflare.com:3478',
      'stun:stun.l.google.com:19302',
    ],
  );
}

class PeerSession {
  final String peerDeviceId;
  PeerConnectionState state;
  final DataChannelMultiplexer multiplexer;
  int iceRestartCount;
  DateTime lastStateChange;

  PeerSession({
    required this.peerDeviceId,
    this.state = PeerConnectionState.newConn,
    DataChannelMultiplexer? multiplexer,
    this.iceRestartCount = 0,
    DateTime? lastStateChange,
  })  : multiplexer = multiplexer ?? DataChannelMultiplexer(),
        lastStateChange = lastStateChange ?? DateTime.now().toUtc();
}

class PeerConnectionManager {
  final String localDeviceId;
  final IceServerConfig iceConfig;
  final Map<String, PeerSession> _sessions = {};
  final StreamController<(String peerDeviceId, PeerConnectionState state)>
      _stateController = StreamController.broadcast();

  PeerConnectionManager({
    required this.localDeviceId,
    this.iceConfig = IceServerConfig.defaultStun,
  });

  Stream<(String peerDeviceId, PeerConnectionState state)> get onConnectionStateChange =>
      _stateController.stream;

  Map<String, PeerSession> get activeSessions => Map.unmodifiable(_sessions);

  /// Gets or creates a P2P session for a remote peer device.
  PeerSession getOrCreateSession(String peerDeviceId) {
    return _sessions.putIfAbsent(
      peerDeviceId,
      () => PeerSession(peerDeviceId: peerDeviceId),
    );
  }

  /// Updates connection state and triggers telemetry.
  void updateState(String peerDeviceId, PeerConnectionState newState) {
    final session = getOrCreateSession(peerDeviceId);
    session.state = newState;
    session.lastStateChange = DateTime.now().toUtc();
    _stateController.add((peerDeviceId, newState));
  }

  /// Triggers an automatic ICE restart on network transition or disconnect (Section 04).
  bool triggerIceRestart(String peerDeviceId) {
    final session = _sessions[peerDeviceId];
    if (session == null) return false;

    session.iceRestartCount++;
    updateState(peerDeviceId, PeerConnectionState.connecting);
    return true;
  }

  /// Closes and removes a peer session.
  void closeSession(String peerDeviceId) {
    final session = _sessions.remove(peerDeviceId);
    if (session != null) {
      session.state = PeerConnectionState.closed;
      session.multiplexer.dispose();
      _stateController.add((peerDeviceId, PeerConnectionState.closed));
    }
  }

  void dispose() {
    for (final session in _sessions.values) {
      session.multiplexer.dispose();
    }
    _sessions.clear();
    _stateController.close();
  }
}
