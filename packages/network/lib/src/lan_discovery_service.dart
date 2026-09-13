/// LAN Zero-Cloud Peer Discovery & Beacon Broadcasting.
/// Enforces Rule 47-48, Section 01: LAN mDNS/UDP discovery with strict trusted device filtering.
library lan_discovery_service;

import 'dart:async';
import 'package:auth/auth.dart';
import 'peer_descriptor.dart';

class LanDiscoveryService {
  final PeerDescriptor localDescriptor;
  final DeviceTrustManager trustManager;
  final StreamController<PeerDescriptor> _discoveredController =
      StreamController<PeerDescriptor>.broadcast();

  final Map<String, PeerDescriptor> _knownPeers = {};

  LanDiscoveryService({
    required this.localDescriptor,
    required this.trustManager,
  });

  Stream<PeerDescriptor> get onPeerDiscovered => _discoveredController.stream;

  Map<String, PeerDescriptor> get knownPeers => Map.unmodifiable(_knownPeers);

  /// Serializes local node advertisement beacon for UDP broadcast or mDNS TXT records.
  String createAnnouncementBeacon() {
    return localDescriptor.toJson();
  }

  /// Ingests an incoming peer announcement beacon.
  /// Strictly drops self-announcements and non-trusted devices (Rule 47, Section 01).
  bool handleIncomingBeacon(String beaconJson) {
    try {
      final peer = PeerDescriptor.fromJson(beaconJson);

      // 1. Ignore self-announcements
      if (peer.deviceId == localDescriptor.deviceId) {
        return false;
      }

      // 2. Strict Security Filter: Only allow devices in TRUSTED state
      if (!trustManager.isDeviceAuthorized(peer.deviceId)) {
        return false;
      }

      // 3. Register trusted peer
      _knownPeers[peer.deviceId] = peer;
      _discoveredController.add(peer);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Removes a peer (e.g. on disconnect or revocation).
  void removePeer(String deviceId) {
    _knownPeers.remove(deviceId);
  }

  void dispose() {
    _discoveredController.close();
  }
}
