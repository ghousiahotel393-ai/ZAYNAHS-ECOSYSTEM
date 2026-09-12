/// Strongly typed identifiers for the Zaynahs Ecosystem.
/// Enforces type-safety across domain boundaries, preventing ID swapping bugs.
library identifiers;

import 'dart:math';

/// Abstract base class for all domain entity identifiers.
abstract class EntityId implements Comparable<EntityId> {
  final String value;

  const EntityId(this.value);

  /// Validates the format of an identifier string.
  static bool isValidId(String? id) {
    if (id == null) return false;
    final trimmed = id.trim();
    if (trimmed.isEmpty || trimmed.length < 3 || trimmed.length > 128) {
      return false;
    }
    // Allowed characters: letters, numbers, hyphens, underscores
    final regex = RegExp(r'^[a-zA-Z0-9_\-]+$');
    return regex.hasMatch(trimmed);
  }

  /// Generates a pseudo-random UUID v4 string without external dependencies.
  static String generateUuidV4() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));

    // Set version to 4 (0100)
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    // Set variant to RFC 4122 (10xx)
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    String hex(int byte) => byte.toRadixString(16).padLeft(2, '0');

    return '${hex(bytes[0])}${hex(bytes[1])}${hex(bytes[2])}${hex(bytes[3])}-'
        '${hex(bytes[4])}${hex(bytes[5])}-'
        '${hex(bytes[6])}${hex(bytes[7])}-'
        '${hex(bytes[8])}${hex(bytes[9])}-'
        '${hex(bytes[10])}${hex(bytes[11])}${hex(bytes[12])}${hex(bytes[13])}${hex(bytes[14])}${hex(bytes[15])}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EntityId &&
          runtimeType == other.runtimeType &&
          other.value == value);

  @override
  int get hashCode => value.hashCode;

  @override
  int compareTo(EntityId other) => value.compareTo(other.value);

  @override
  String toString() => '$runtimeType($value)';

  String toJson() => value;
}

/// Global Ecosystem Identifier.
/// Strictly enforces ONE ECOSYSTEM law across all devices.
class EcosystemId extends EntityId {
  const EcosystemId(super.value);

  factory EcosystemId.fromString(String value) {
    if (!EntityId.isValidId(value)) {
      throw ArgumentError.value(value, 'value', 'Invalid EcosystemId format');
    }
    return EcosystemId(value.trim());
  }

  factory EcosystemId.generate() =>
      EcosystemId('eco_${EntityId.generateUuidV4()}');

  factory EcosystemId.fromJson(String json) => EcosystemId.fromString(json);
}

/// Device Identifier for trusted peer devices.
class DeviceId extends EntityId {
  const DeviceId(super.value);

  factory DeviceId.fromString(String value) {
    if (!EntityId.isValidId(value)) {
      throw ArgumentError.value(value, 'value', 'Invalid DeviceId format');
    }
    return DeviceId(value.trim());
  }

  factory DeviceId.generate() =>
      DeviceId('dev_${EntityId.generateUuidV4()}');

  factory DeviceId.fromJson(String json) => DeviceId.fromString(json);
}

/// User Identifier for system operators.
class UserId extends EntityId {
  const UserId(super.value);

  factory UserId.fromString(String value) {
    if (!EntityId.isValidId(value)) {
      throw ArgumentError.value(value, 'value', 'Invalid UserId format');
    }
    return UserId(value.trim());
  }

  factory UserId.generate() =>
      UserId('usr_${EntityId.generateUuidV4()}');

  factory UserId.fromJson(String json) => UserId.fromString(json);
}

/// Universal Financial Transaction Identifier.
class TransactionId extends EntityId {
  const TransactionId(super.value);

  factory TransactionId.fromString(String value) {
    if (!EntityId.isValidId(value)) {
      throw ArgumentError.value(value, 'value', 'Invalid TransactionId format');
    }
    return TransactionId(value.trim());
  }

  factory TransactionId.generate() =>
      TransactionId('tx_${EntityId.generateUuidV4()}');

  factory TransactionId.fromJson(String json) => TransactionId.fromString(json);
}

/// Universal POS Sale Identifier.
class SaleId extends EntityId {
  const SaleId(super.value);

  factory SaleId.fromString(String value) {
    if (!EntityId.isValidId(value)) {
      throw ArgumentError.value(value, 'value', 'Invalid SaleId format');
    }
    return SaleId(value.trim());
  }

  factory SaleId.generate() =>
      SaleId('sale_${EntityId.generateUuidV4()}');

  factory SaleId.fromJson(String json) => SaleId.fromString(json);
}

/// Inventory Movement Event Identifier.
class MovementId extends EntityId {
  const MovementId(super.value);

  factory MovementId.fromString(String value) {
    if (!EntityId.isValidId(value)) {
      throw ArgumentError.value(value, 'value', 'Invalid MovementId format');
    }
    return MovementId(value.trim());
  }

  factory MovementId.generate() =>
      MovementId('mov_${EntityId.generateUuidV4()}');

  factory MovementId.fromJson(String json) => MovementId.fromString(json);
}

/// Wallet Account Identifier (Cash, Bank, Online).
class WalletId extends EntityId {
  const WalletId(super.value);

  factory WalletId.fromString(String value) {
    if (!EntityId.isValidId(value)) {
      throw ArgumentError.value(value, 'value', 'Invalid WalletId format');
    }
    return WalletId(value.trim());
  }

  factory WalletId.generate() =>
      WalletId('wal_${EntityId.generateUuidV4()}');

  factory WalletId.fromJson(String json) => WalletId.fromString(json);
}

/// Sync Event Identifier for durable outbox ledger.
class EventId extends EntityId {
  const EventId(super.value);

  factory EventId.fromString(String value) {
    if (!EntityId.isValidId(value)) {
      throw ArgumentError.value(value, 'value', 'Invalid EventId format');
    }
    return EventId(value.trim());
  }

  factory EventId.generate() =>
      EventId('evt_${EntityId.generateUuidV4()}');

  factory EventId.fromJson(String json) => EventId.fromString(json);
}
