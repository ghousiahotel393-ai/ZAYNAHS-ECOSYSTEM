/// Repository for trusted peer devices and trust state lifecycle.
/// Enforces Rule 66-68: PENDING, TRUSTED, REVOKED, BLOCKED transitions.
library device_repository;

import '../app_database.dart';

class DeviceEntity {
  final String id;
  final String name;
  final String trustStatus; // PENDING, TRUSTED, REVOKED, BLOCKED
  final String publicKey;
  final DateTime? pairedAt;
  final DateTime lastSeenAt;
  final String deviceType;
  final String? ipAddress;

  const DeviceEntity({
    required this.id,
    required this.name,
    required this.trustStatus,
    required this.publicKey,
    this.pairedAt,
    required this.lastSeenAt,
    this.deviceType = 'terminal',
    this.ipAddress,
  });

  bool get isTrusted => trustStatus == 'TRUSTED';
  bool get isPending => trustStatus == 'PENDING';
  bool get isRevoked => trustStatus == 'REVOKED';
  bool get isBlocked => trustStatus == 'BLOCKED';
}

class DeviceRepository {
  final AppDatabase db;

  DeviceRepository(this.db);

  /// Registers a newly discovered or pairing device with PENDING status.
  void registerPendingDevice(DeviceEntity device) {
    db.connection.execute(
      '''
      INSERT INTO devices (
        id, name, trust_status, public_key, paired_at,
        last_seen_at, device_type, ip_address
      ) VALUES (?, ?, 'PENDING', ?, NULL, ?, ?, ?)
      ''',
      [
        device.id,
        device.name,
        device.publicKey,
        device.lastSeenAt.toIso8601String(),
        device.deviceType,
        device.ipAddress,
      ],
    );
  }

  /// Transitions a device to TRUSTED status upon manager/admin pairing approval.
  void setTrustStatus(String deviceId, String newStatus) {
    final allowed = ['PENDING', 'TRUSTED', 'REVOKED', 'BLOCKED'];
    if (!allowed.contains(newStatus)) {
      throw ArgumentError('Invalid trust status: $newStatus');
    }

    final now = DateTime.now().toUtc().toIso8601String();
    final isTrusted = newStatus == 'TRUSTED';

    db.connection.execute(
      '''
      UPDATE devices
      SET trust_status = ?,
          paired_at = CASE WHEN ? THEN ? ELSE paired_at END,
          last_seen_at = ?
      WHERE id = ?
      ''',
      [newStatus, isTrusted, now, now, deviceId],
    );
  }

  /// Retrieves a device by its identifier.
  DeviceEntity? getDeviceById(String deviceId) {
    final rs = db.connection.select('SELECT * FROM devices WHERE id = ?', [deviceId]);
    if (rs.isEmpty) return null;
    final row = rs.first;
    return DeviceEntity(
      id: row['id'] as String,
      name: row['name'] as String,
      trustStatus: row['trust_status'] as String,
      publicKey: row['public_key'] as String,
      pairedAt: row['paired_at'] != null ? DateTime.parse(row['paired_at'] as String) : null,
      lastSeenAt: DateTime.parse(row['last_seen_at'] as String),
      deviceType: row['device_type'] as String,
      ipAddress: row['ip_address'] as String?,
    );
  }

  /// Lists all devices with optional status filter.
  List<DeviceEntity> listDevices({String? status}) {
    final query = status != null
        ? 'SELECT * FROM devices WHERE trust_status = ? ORDER BY name ASC'
        : 'SELECT * FROM devices ORDER BY name ASC';
    final params = status != null ? [status] : const [];

    final rs = db.connection.select(query, params);
    return rs.map((row) => DeviceEntity(
      id: row['id'] as String,
      name: row['name'] as String,
      trustStatus: row['trust_status'] as String,
      publicKey: row['public_key'] as String,
      pairedAt: row['paired_at'] != null ? DateTime.parse(row['paired_at'] as String) : null,
      lastSeenAt: DateTime.parse(row['last_seen_at'] as String),
      deviceType: row['device_type'] as String,
      ipAddress: row['ip_address'] as String?,
    )).toList();
  }
}
