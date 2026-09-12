/// Out-of-band Peer Device Pairing Protocol.
/// Enforces Rule 66-68: 6-digit challenge code & QR code exchange with 5-minute timeout.
library pairing_service;

import 'dart:convert';
import 'package:database/database.dart';
import 'crypto_utils.dart';

class PairingSession {
  final String sessionId;
  final String deviceId;
  final String deviceName;
  final String publicKey;
  final String pairingCode; // 6-digit numeric challenge
  final DateTime createdAt;
  final DateTime expiresAt;
  final String? ipAddress;

  const PairingSession({
    required this.sessionId,
    required this.deviceId,
    required this.deviceName,
    required this.publicKey,
    required this.pairingCode,
    required this.createdAt,
    required this.expiresAt,
    this.ipAddress,
  });

  bool get isExpired => DateTime.now().toUtc().isAfter(expiresAt);

  /// Generates the payload string to encode into a QR code for mobile scanning.
  String toQrPayload() {
    return jsonEncode({
      'v': 1,
      'sid': sessionId,
      'did': deviceId,
      'dn': deviceName,
      'pk': publicKey,
      'code': pairingCode,
      'exp': expiresAt.toIso8601String(),
      if (ipAddress != null) 'ip': ipAddress,
    });
  }

  /// Parses a scanned QR payload string back into a PairingSession.
  static PairingSession fromQrPayload(String qrString) {
    final map = jsonDecode(qrString) as Map<String, dynamic>;
    return PairingSession(
      sessionId: map['sid'] as String,
      deviceId: map['did'] as String,
      deviceName: map['dn'] as String,
      publicKey: map['pk'] as String,
      pairingCode: map['code'] as String,
      createdAt: DateTime.now().toUtc(),
      expiresAt: DateTime.parse(map['exp'] as String),
      ipAddress: map['ip'] as String?,
    );
  }
}

class PairingService {
  final DeviceRepository deviceRepo;
  final Map<String, PairingSession> _activeSessions = {};

  PairingService(this.deviceRepo);

  /// Initiates a pairing session for a new device requesting admission into ecosystem.
  PairingSession createPairingSession({
    required String deviceId,
    required String deviceName,
    required String publicKey,
    String? ipAddress,
    Duration validDuration = const Duration(minutes: 5),
  }) {
    final now = DateTime.now().toUtc();
    final code = CryptoUtils.generatePairingCode();
    final sessionId = 'pair_${CryptoUtils.generateSalt(8)}';

    final session = PairingSession(
      sessionId: sessionId,
      deviceId: deviceId,
      deviceName: deviceName,
      publicKey: publicKey,
      pairingCode: code,
      createdAt: now,
      expiresAt: now.add(validDuration),
      ipAddress: ipAddress,
    );

    _activeSessions[sessionId] = session;

    // Register as PENDING in device database if not already present
    if (deviceRepo.getDeviceById(deviceId) == null) {
      deviceRepo.registerPendingDevice(DeviceEntity(
        id: deviceId,
        name: deviceName,
        trustStatus: 'PENDING',
        publicKey: publicKey,
        lastSeenAt: now,
        ipAddress: ipAddress,
      ));
    }

    return session;
  }

  /// Approves a pairing session by verifying the 6-digit challenge code.
  /// If valid, the device transitions to TRUSTED.
  bool approvePairing({
    required String sessionId,
    required String enteredPairingCode,
    required String approverUserId,
  }) {
    final session = _activeSessions[sessionId];
    if (session == null) {
      return false; // Unknown session
    }

    if (session.isExpired) {
      _activeSessions.remove(sessionId);
      return false; // Expired
    }

    // Verify 6-digit code in constant time
    if (!CryptoUtils.constantTimeEquals(session.pairingCode, enteredPairingCode.trim())) {
      return false; // Code mismatch
    }

    // Approve device to TRUSTED
    deviceRepo.setTrustStatus(session.deviceId, 'TRUSTED');
    _activeSessions.remove(sessionId);
    return true;
  }
}
