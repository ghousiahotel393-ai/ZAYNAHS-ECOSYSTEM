/// Privacy-Preserving Screen, Camera & Ephemeral Location Sharing.
/// Enforces Section 04, Rule 54-65: Explicit user consent, visual indicators, and auto-expiring location.
library privacy_sharing_manager;

import 'dart:async';

class PrivacyConsentRequiredException implements Exception {
  final String action;
  const PrivacyConsentRequiredException(this.action);

  @override
  String toString() =>
      'PrivacyConsentRequiredException: Action "$action" strictly requires explicit user confirmation. Covert or automated capture is prohibited (Rule 54-65).';
}

class EphemeralLocationSession {
  final DateTime startedAt;
  final Duration duration;
  final DateTime expiresAt;
  bool isActive;

  EphemeralLocationSession({
    required this.startedAt,
    required this.duration,
  })  : expiresAt = startedAt.add(duration),
        isActive = true;

  bool get isExpired => DateTime.now().toUtc().isAfter(expiresAt);
}

class PrivacySharingManager {
  bool _isScreenSharing = false;
  bool _isCameraSharing = false;
  EphemeralLocationSession? _locationSession;
  Timer? _locationExpiryTimer;

  bool get isScreenSharing => _isScreenSharing;
  bool get isCameraSharing => _isCameraSharing;
  bool get isLocationSharing =>
      _locationSession != null && _locationSession!.isActive && !_locationSession!.isExpired;

  Duration? get remainingLocationDuration {
    if (!isLocationSharing || _locationSession == null) return null;
    final rem = _locationSession!.expiresAt.difference(DateTime.now().toUtc());
    return rem.isNegative ? Duration.zero : rem;
  }

  /// Starts screen sharing ONLY when explicit user consent is granted.
  bool startScreenSharing({required bool userExplicitlyConsented}) {
    if (!userExplicitlyConsented) {
      throw const PrivacyConsentRequiredException('Screen Sharing');
    }
    _isScreenSharing = true;
    return true;
  }

  void stopScreenSharing() {
    _isScreenSharing = false;
  }

  /// Starts camera sharing with visible indicator requirement.
  bool startCameraSharing({required bool userExplicitlyConsented}) {
    if (!userExplicitlyConsented) {
      throw const PrivacyConsentRequiredException('Camera Sharing');
    }
    _isCameraSharing = true;
    return true;
  }

  void stopCameraSharing() {
    _isCameraSharing = false;
  }

  /// Starts ephemeral location sharing with automatic expiration timer.
  bool startEphemeralLocationSharing({
    required Duration duration,
    required bool userExplicitlyConsented,
  }) {
    if (!userExplicitlyConsented) {
      throw const PrivacyConsentRequiredException('Location Sharing');
    }

    _locationExpiryTimer?.cancel();
    final session = EphemeralLocationSession(
      startedAt: DateTime.now().toUtc(),
      duration: duration,
    );
    _locationSession = session;

    _locationExpiryTimer = Timer(duration, () {
      stopLocationSharing();
    });

    return true;
  }

  void stopLocationSharing() {
    _locationExpiryTimer?.cancel();
    _locationExpiryTimer = null;
    if (_locationSession != null) {
      _locationSession!.isActive = false;
    }
  }

  void dispose() {
    _isScreenSharing = false;
    _isCameraSharing = false;
    stopLocationSharing();
  }
}
