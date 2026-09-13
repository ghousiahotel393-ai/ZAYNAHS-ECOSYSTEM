/// Cloudflare Workers P2P Rendezvous & Signaling Client.
/// Enforces Rule 48-49, Section 02: Coordination only (SDP offers, answers, ICE candidates).
/// STRICT PROHIBITION: Rejects any attempt to transmit large media, files, or binary sync data.
library signaling_client;

import 'dart:async';
import 'dart:convert';

enum SignalingType {
  offer,
  answer,
  candidate,
  ping,
  bye;

  static SignalingType fromString(String val) {
    return SignalingType.values.firstWhere(
      (e) => e.name.toLowerCase() == val.toLowerCase(),
      orElse: () => SignalingType.ping,
    );
  }
}

class SignalingMessage {
  final SignalingType type;
  final String senderDeviceId;
  final String recipientDeviceId;
  final Map<String, dynamic> data;
  final DateTime timestamp;

  const SignalingMessage({
    required this.type,
    required this.senderDeviceId,
    required this.recipientDeviceId,
    required this.data,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'type': type.name,
      'sender_device_id': senderDeviceId,
      'recipient_device_id': recipientDeviceId,
      'data': data,
      'timestamp': timestamp.toUtc().toIso8601String(),
    };
  }

  factory SignalingMessage.fromMap(Map<String, dynamic> map) {
    return SignalingMessage(
      type: SignalingType.fromString(map['type'] as String),
      senderDeviceId: map['sender_device_id'] as String,
      recipientDeviceId: map['recipient_device_id'] as String,
      data: Map<String, dynamic>.from(map['data'] as Map? ?? {}),
      timestamp: map['timestamp'] != null
          ? DateTime.parse(map['timestamp'] as String)
          : DateTime.now().toUtc(),
    );
  }

  String toJson() => jsonEncode(toMap());

  factory SignalingMessage.fromJson(String jsonStr) =>
      SignalingMessage.fromMap(jsonDecode(jsonStr) as Map<String, dynamic>);
}

class SignalingPayloadTooLargeException implements Exception {
  final int sizeBytes;
  final int maxAllowedBytes;

  const SignalingPayloadTooLargeException(this.sizeBytes, this.maxAllowedBytes);

  @override
  String toString() =>
      'SignalingPayloadTooLargeException: Payload of $sizeBytes bytes exceeds maximum permitted coordination size of $maxAllowedBytes bytes. Large media, files, and binary sync data must use WebRTC DataChannels (Rule 49).';
}

class SignalingClient {
  static const int maxSignalingPayloadBytes = 64 * 1024; // 64 KB strict ceiling

  final String localDeviceId;
  final StreamController<SignalingMessage> _inboundController =
      StreamController<SignalingMessage>.broadcast();

  SignalingClient({required this.localDeviceId});

  Stream<SignalingMessage> get onMessage => _inboundController.stream;

  /// Validates and packs a signaling coordination message.
  /// Strictly enforces Rule 49 by blocking payloads exceeding 64KB.
  String createMessagePayload({
    required SignalingType type,
    required String recipientDeviceId,
    required Map<String, dynamic> data,
  }) {
    final message = SignalingMessage(
      type: type,
      senderDeviceId: localDeviceId,
      recipientDeviceId: recipientDeviceId,
      data: data,
      timestamp: DateTime.now().toUtc(),
    );

    final serialized = message.toJson();
    final byteLength = utf8.encode(serialized).length;

    if (byteLength > maxSignalingPayloadBytes) {
      throw SignalingPayloadTooLargeException(byteLength, maxSignalingPayloadBytes);
    }

    return serialized;
  }

  /// Dispatches an incoming signaling message string to listeners.
  void dispatchIncoming(String payloadString) {
    final byteLength = utf8.encode(payloadString).length;
    if (byteLength > maxSignalingPayloadBytes) {
      throw SignalingPayloadTooLargeException(byteLength, maxSignalingPayloadBytes);
    }

    final msg = SignalingMessage.fromJson(payloadString);
    if (msg.recipientDeviceId == localDeviceId) {
      _inboundController.add(msg);
    }
  }

  void dispose() {
    _inboundController.close();
  }
}
