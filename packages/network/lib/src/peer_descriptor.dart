/// Peer Device Descriptor for P2P Discovery and Networking.
/// Enforces Rule 3-5: Trusted peer devices in ONE unified ecosystem.
library peer_descriptor;

import 'dart:convert';

class PeerDescriptor {
  final String deviceId;
  final String deviceName;
  final String deviceType;
  final String publicKeyFingerprint;
  final List<String> addresses;
  final int port;
  final DateTime discoveredAt;

  const PeerDescriptor({
    required this.deviceId,
    required this.deviceName,
    required this.deviceType,
    required this.publicKeyFingerprint,
    required this.addresses,
    required this.port,
    required this.discoveredAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'device_id': deviceId,
      'device_name': deviceName,
      'device_type': deviceType,
      'public_key_fingerprint': publicKeyFingerprint,
      'addresses': addresses,
      'port': port,
      'discovered_at': discoveredAt.toUtc().toIso8601String(),
    };
  }

  factory PeerDescriptor.fromMap(Map<String, dynamic> map) {
    return PeerDescriptor(
      deviceId: map['device_id'] as String,
      deviceName: map['device_name'] as String,
      deviceType: map['device_type'] as String? ?? 'terminal',
      publicKeyFingerprint: map['public_key_fingerprint'] as String,
      addresses: List<String>.from(map['addresses'] as List? ?? []),
      port: (map['port'] as num?)?.toInt() ?? 45454,
      discoveredAt: map['discovered_at'] != null
          ? DateTime.parse(map['discovered_at'] as String)
          : DateTime.now().toUtc(),
    );
  }

  String toJson() => jsonEncode(toMap());

  factory PeerDescriptor.fromJson(String jsonStr) =>
      PeerDescriptor.fromMap(jsonDecode(jsonStr) as Map<String, dynamic>);
}
