/// Strongly typed SyncEvent domain model.
/// Enforces Rule 37-39, Section 01: Canonical hashing, cryptographic verification, and state tracking.
library sync_event;

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:core/core.dart';

enum SyncState {
  localOnly,
  queued,
  sending,
  sent,
  received,
  applied,
  conflict,
  failed,
  ack;

  String get dbStatus {
    switch (this) {
      case SyncState.localOnly:
      case SyncState.queued:
        return 'PENDING';
      case SyncState.sending:
      case SyncState.sent:
        return 'SENT';
      case SyncState.received:
      case SyncState.applied:
      case SyncState.ack:
        return 'ACKNOWLEDGED';
      case SyncState.conflict:
      case SyncState.failed:
        return 'FAILED';
    }
  }

  static SyncState fromDbStatus(String status) {
    switch (status) {
      case 'PENDING':
        return SyncState.queued;
      case 'SENT':
        return SyncState.sent;
      case 'ACKNOWLEDGED':
        return SyncState.ack;
      case 'FAILED':
      default:
        return SyncState.failed;
    }
  }
}

class SyncEvent {
  final String eventId;
  final String eventType;
  final String aggregateId;
  final String aggregateType;
  final String deviceId;
  final String? userId;
  final String createdAt;
  final int logicalVersion;
  final Map<String, dynamic> payload;
  final String hash;
  final String? signature;
  final int schemaVersion;
  final SyncState state;

  const SyncEvent({
    required this.eventId,
    required this.eventType,
    required this.aggregateId,
    required this.aggregateType,
    required this.deviceId,
    this.userId,
    required this.createdAt,
    required this.logicalVersion,
    required this.payload,
    required this.hash,
    this.signature,
    this.schemaVersion = 1,
    this.state = SyncState.queued,
  });

  /// Computes deterministic SHA-256 hash over canonical event fields.
  static String computeHash({
    required String eventId,
    required String eventType,
    required String aggregateId,
    required String aggregateType,
    required String deviceId,
    required String createdAt,
    required int logicalVersion,
    required Map<String, dynamic> payload,
  }) {
    final canonicalJson = jsonEncode(payload);
    final raw = '$eventId:$eventType:$aggregateId:$aggregateType:$deviceId:$createdAt:$logicalVersion:$canonicalJson';
    return sha256.convert(utf8.encode(raw)).toString();
  }

  /// Factory that automatically generates UUID, timestamp, and cryptographic hash.
  factory SyncEvent.create({
    String? eventId,
    required String eventType,
    required String aggregateId,
    required String aggregateType,
    required String deviceId,
    String? userId,
    String? createdAt,
    int logicalVersion = 1,
    required Map<String, dynamic> payload,
    String? signature,
    int schemaVersion = 1,
    SyncState state = SyncState.queued,
  }) {
    final id = eventId ?? 'evt_${EntityId.generateUuidV4()}';
    final timestamp = createdAt ?? DateTime.now().toUtc().toIso8601String();
    final calculatedHash = computeHash(
      eventId: id,
      eventType: eventType,
      aggregateId: aggregateId,
      aggregateType: aggregateType,
      deviceId: deviceId,
      createdAt: timestamp,
      logicalVersion: logicalVersion,
      payload: payload,
    );

    return SyncEvent(
      eventId: id,
      eventType: eventType,
      aggregateId: aggregateId,
      aggregateType: aggregateType,
      deviceId: deviceId,
      userId: userId,
      createdAt: timestamp,
      logicalVersion: logicalVersion,
      payload: payload,
      hash: calculatedHash,
      signature: signature,
      schemaVersion: schemaVersion,
      state: state,
    );
  }

  /// Verifies payload integrity against the embedded SHA-256 hash.
  bool verifyIntegrity() {
    final expectedHash = computeHash(
      eventId: eventId,
      eventType: eventType,
      aggregateId: aggregateId,
      aggregateType: aggregateType,
      deviceId: deviceId,
      createdAt: createdAt,
      logicalVersion: logicalVersion,
      payload: payload,
    );
    return expectedHash == hash;
  }

  SyncEvent copyWith({
    String? eventId,
    String? eventType,
    String? aggregateId,
    String? aggregateType,
    String? deviceId,
    String? userId,
    String? createdAt,
    int? logicalVersion,
    Map<String, dynamic>? payload,
    String? hash,
    String? signature,
    int? schemaVersion,
    SyncState? state,
  }) {
    return SyncEvent(
      eventId: eventId ?? this.eventId,
      eventType: eventType ?? this.eventType,
      aggregateId: aggregateId ?? this.aggregateId,
      aggregateType: aggregateType ?? this.aggregateType,
      deviceId: deviceId ?? this.deviceId,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
      logicalVersion: logicalVersion ?? this.logicalVersion,
      payload: payload ?? this.payload,
      hash: hash ?? this.hash,
      signature: signature ?? this.signature,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      state: state ?? this.state,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'event_id': eventId,
      'event_type': eventType,
      'aggregate_id': aggregateId,
      'aggregate_type': aggregateType,
      'device_id': deviceId,
      'user_id': userId,
      'created_at': createdAt,
      'logical_version': logicalVersion,
      'payload': payload,
      'hash': hash,
      'signature': signature,
      'schema_version': schemaVersion,
      'state': state.name,
    };
  }

  factory SyncEvent.fromMap(Map<String, dynamic> map) {
    return SyncEvent(
      eventId: map['event_id'] as String,
      eventType: map['event_type'] as String,
      aggregateId: map['aggregate_id'] as String,
      aggregateType: map['aggregate_type'] as String,
      deviceId: map['device_id'] as String,
      userId: map['user_id'] as String?,
      createdAt: map['created_at'] as String,
      logicalVersion: (map['logical_version'] as num?)?.toInt() ?? 1,
      payload: map['payload'] is String
          ? jsonDecode(map['payload'] as String) as Map<String, dynamic>
          : Map<String, dynamic>.from(map['payload'] as Map),
      hash: map['hash'] as String? ?? '',
      signature: map['signature'] as String?,
      schemaVersion: (map['schema_version'] as num?)?.toInt() ?? 1,
      state: SyncState.values.firstWhere(
        (s) => s.name == map['state'],
        orElse: () => SyncState.queued,
      ),
    );
  }

  String toJson() => jsonEncode(toMap());

  factory SyncEvent.fromJson(String source) =>
      SyncEvent.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
