/// User session state and token validation with auto-lock timeout.
/// Complies with Rule 69-78 (Session security & automatic register locking).
library user_session;

import 'package:core/core.dart';
import 'rbac_resolver.dart';

class UserSession {
  final String token;
  final String userId;
  final String name;
  final String email;
  final String role;
  final bool isActive;
  final DateTime createdAt;
  DateTime lastActivityAt;
  final Duration timeoutDuration;
  final Set<String> customGrants;
  final Set<String> customRevocations;

  UserSession({
    required this.token,
    required this.userId,
    required this.name,
    required this.email,
    required this.role,
    this.isActive = true,
    required this.createdAt,
    required this.lastActivityAt,
    this.timeoutDuration = const Duration(minutes: 15),
    this.customGrants = const {},
    this.customRevocations = const {},
  });

  /// Factory constructor to establish a new authenticated session.
  factory UserSession.create({
    required String userId,
    required String name,
    required String email,
    required String role,
    bool isActive = true,
    Duration timeoutDuration = const Duration(minutes: 15),
    Set<String> customGrants = const {},
    Set<String> customRevocations = const {},
  }) {
    final now = DateTime.now().toUtc();
    final token = 'tok_${EntityId.generateUuidV4()}';
    return UserSession(
      token: token,
      userId: userId,
      name: name,
      email: email,
      role: role,
      isActive: isActive,
      createdAt: now,
      lastActivityAt: now,
      timeoutDuration: timeoutDuration,
      customGrants: customGrants,
      customRevocations: customRevocations,
    );
  }

  /// Returns true if the session is still active and has not timed out.
  bool get isValid {
    if (!isActive) return false;
    final now = DateTime.now().toUtc();
    return now.difference(lastActivityAt) <= timeoutDuration;
  }

  /// Checks if this active user has a specific permission.
  bool hasPermission(String requiredPermission) {
    if (!isValid) return false;
    return RbacResolver.resolve(
      role: role,
      isActive: isActive,
      requiredPermission: requiredPermission,
      customGrants: customGrants,
      customRevocations: customRevocations,
    );
  }

  /// Refreshes last active timestamp.
  void touch() {
    lastActivityAt = DateTime.now().toUtc();
  }
}
