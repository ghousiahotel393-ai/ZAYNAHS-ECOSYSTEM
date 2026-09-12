/// Typed Domain Error Hierarchy for Zaynahs Ecosystem
/// Provides domain-specific, structured errors without raw uncaught exceptions.

abstract class AppException implements Exception {
  final String code;
  final String message;
  final Map<String, dynamic>? details;

  const AppException({
    required this.code,
    required this.message,
    this.details,
  });

  @override
  String toString() => '$runtimeType(code: $code, message: $message, details: $details)';
}

/// Authentication & Session Errors
class AuthException extends AppException {
  const AuthException({
    required super.code,
    required super.message,
    super.details,
  });

  factory AuthException.invalidCredentials() => const AuthException(
        code: 'AUTH_INVALID_CREDENTIALS',
        message: 'Invalid username, password, or PIN.',
      );

  factory AuthException.sessionExpired() => const AuthException(
        code: 'AUTH_SESSION_EXPIRED',
        message: 'Your active session has expired. Please log in again.',
      );

  factory AuthException.deviceRevoked() => const AuthException(
        code: 'AUTH_DEVICE_REVOKED',
        message: 'This device has been revoked and cannot access the ecosystem.',
      );
}

/// Permission & RBAC Errors
class PermissionDeniedException extends AppException {
  final String requiredPermission;
  final String? userRole;

  const PermissionDeniedException({
    required this.requiredPermission,
    this.userRole,
    required super.message,
    super.details,
  }) : super(code: 'PERMISSION_DENIED');

  factory PermissionDeniedException.forAction(String permission, [String? role]) =>
      PermissionDeniedException(
        requiredPermission: permission,
        userRole: role,
        message: 'Permission "$permission" is required to perform this operation.',
        details: {'permission': permission, 'role': role},
      );
}

/// Business Validation Errors
class ValidationException extends AppException {
  final String field;

  const ValidationException({
    required this.field,
    required super.code,
    required super.message,
    super.details,
  });

  factory ValidationException.required(String field) => ValidationException(
        field: field,
        code: 'VALIDATION_FIELD_REQUIRED',
        message: 'Field "$field" is mandatory.',
        details: {'field': field},
      );

  factory ValidationException.invalidValue(String field, String reason) => ValidationException(
        field: field,
        code: 'VALIDATION_INVALID_VALUE',
        message: 'Validation failed for "$field": $reason',
        details: {'field': field, 'reason': reason},
      );
}

/// Local Database & Repository Errors
class DatabaseException extends AppException {
  const DatabaseException({
    required super.code,
    required super.message,
    super.details,
  });

  factory DatabaseException.transactionFailed(String reason) => DatabaseException(
        code: 'DB_TRANSACTION_FAILED',
        message: 'Database transaction failed and was rolled back: $reason',
        details: {'reason': reason},
      );

  factory DatabaseException.constraintViolation(String constraint) => DatabaseException(
        code: 'DB_CONSTRAINT_VIOLATION',
        message: 'Database foreign key or unique constraint violated: $constraint',
        details: {'constraint': constraint},
      );
}

/// P2P Sync & Event Log Errors
class SyncException extends AppException {
  const SyncException({
    required super.code,
    required super.message,
    super.details,
  });

  factory SyncException.conflictDetected(String entityId, String reason) => SyncException(
        code: 'SYNC_CONFLICT_DETECTED',
        message: 'Conflict detected for entity $entityId: $reason',
        details: {'entityId': entityId, 'reason': reason},
      );

  factory SyncException.unknownSchemaVersion(int version) => SyncException(
        code: 'SYNC_UNKNOWN_SCHEMA',
        message: 'Received sync event with unsupported schema version: $version',
        details: {'schemaVersion': version},
      );
}

/// File Storage & Disk IO Errors
class StorageException extends AppException {
  const StorageException({
    required super.code,
    required super.message,
    super.details,
  });

  factory StorageException.diskFull() => const StorageException(
        code: 'STORAGE_DISK_FULL',
        message: 'Insufficient disk storage to write file.',
      );

  factory StorageException.pathTraversalAttempt(String path) => StorageException(
        code: 'STORAGE_PATH_TRAVERSAL',
        message: 'Security error: Illegal relative path traversal attempt detected.',
        details: {'path': path},
      );
}

/// Platform Hardware Errors
class PlatformHardwareException extends AppException {
  final String adapterName;

  const PlatformHardwareException({
    required this.adapterName,
    required super.code,
    required super.message,
    super.details,
  });
}
