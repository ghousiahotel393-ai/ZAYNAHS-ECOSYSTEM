/// Device Trust State Machine and Authorization Manager.
/// Enforces Rule 66-68: Strict peer device trust lifecycle.
library device_trust_manager;

import 'package:database/database.dart';

enum DeviceTrustState { pending, trusted, revoked, blocked }

class DeviceTrustManager {
  final DeviceRepository deviceRepo;

  DeviceTrustManager(this.deviceRepo);

  /// Checks whether a peer device is fully authorized to operate or sync.
  bool isDeviceAuthorized(String deviceId) {
    final device = deviceRepo.getDeviceById(deviceId);
    if (device == null) return false;
    return device.trustStatus == 'TRUSTED';
  }

  /// Verifies whether a transition between two device trust states is legally permitted.
  static bool isValidTransition(String fromStatus, String toStatus) {
    final from = fromStatus.toUpperCase();
    final to = toStatus.toUpperCase();

    if (from == to) return true;

    switch (from) {
      case 'PENDING':
        // A pending device may be approved to TRUSTED or rejected to BLOCKED
        return to == 'TRUSTED' || to == 'BLOCKED';
      case 'TRUSTED':
        // A trusted device may be REVOKED (e.g. lost/stolen) or BLOCKED
        return to == 'REVOKED' || to == 'BLOCKED';
      case 'REVOKED':
        // A revoked device cannot simply be re-trusted without complete re-pairing
        return to == 'BLOCKED';
      case 'BLOCKED':
        // Blocked devices cannot transition anywhere
        return false;
      default:
        return false;
    }
  }

  /// Transitions a device to a new trust state enforcing state machine rules.
  void transitionDeviceState(String deviceId, String newStatus) {
    final device = deviceRepo.getDeviceById(deviceId);
    if (device == null) {
      throw StateError('Device $deviceId not found.');
    }

    if (!isValidTransition(device.trustStatus, newStatus)) {
      throw StateError(
        'Illegal device state transition from ${device.trustStatus} to $newStatus',
      );
    }

    deviceRepo.setTrustStatus(deviceId, newStatus);
  }
}
