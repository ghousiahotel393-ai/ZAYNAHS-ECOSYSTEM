/// Centralized Runtime Security Gatekeeper for Zaynahs Ecosystem.
/// Enforces Rules 66-78, 106-119, and Golden Test #103:
/// - Trusted Peer Device Verification (Untrusted and Revoked devices blocked)
/// - Deny-by-default RBAC on all direct actions and endpoints
/// - Guarding of critical operations (restore, CCTV deletion, wallets, inventory)
library security_gatekeeper;

import 'package:core/core.dart';
import 'package:database/database.dart';
import 'device_trust_manager.dart';
import 'rbac_resolver.dart';
import 'user_session.dart';

class SecurityGatekeeper {
  final DeviceTrustManager deviceTrustManager;
  final DeviceRepository deviceRepo;

  SecurityGatekeeper({
    required this.deviceTrustManager,
    required this.deviceRepo,
  });

  /// Enforces that a device is strictly in TRUSTED state.
  /// Throws AuthException if the device is unknown, pending, blocked, or revoked.
  void assertDeviceTrusted(String deviceId) {
    final device = deviceRepo.getDeviceById(deviceId);
    if (device == null) {
      throw AuthException.deviceUntrusted('UNKNOWN');
    }

    if (device.trustStatus == 'REVOKED') {
      throw AuthException.deviceRevoked();
    }

    if (device.trustStatus != 'TRUSTED') {
      throw AuthException.deviceUntrusted(device.trustStatus);
    }
  }

  /// Verifies device trust AND user permissions before granting execution.
  /// Enforces strict deny-by-default.
  void assertPermission({
    required UserSession session,
    required String deviceId,
    required String requiredPermission,
  }) {
    // 1. Device Trust Gate
    assertDeviceTrusted(deviceId);

    // 2. Session Expiration Gate
    if (session.isExpired) {
      throw AuthException.sessionExpired();
    }

    // 3. RBAC Resolution Gate (Deny-by-default)
    final permitted = RbacResolver.resolve(
      role: session.role,
      isActive: true,
      requiredPermission: requiredPermission,
    );

    if (!permitted) {
      throw PermissionDeniedException.forAction(
        requiredPermission,
        session.role,
      );
    }
  }

  /// Guards Database Restore operations (Rule 89, 102, 103).
  /// Strictly requires Permissions.backupRestore (Owner, Admin only).
  void assertCanRestore(UserSession session, String deviceId) {
    assertPermission(
      session: session,
      deviceId: deviceId,
      requiredPermission: Permissions.backupRestore,
    );
  }

  /// Guards CCTV Segment Deletion operations (Rule 63, 103, 105).
  /// Strictly requires Permissions.cctvDelete (Owner only).
  void assertCanDeleteCctv(UserSession session, String deviceId) {
    assertPermission(
      session: session,
      deviceId: deviceId,
      requiredPermission: Permissions.cctvDelete,
    );
  }

  /// Guards POS Operations.
  void assertCanOperatePos(UserSession session, String deviceId) {
    assertPermission(
      session: session,
      deviceId: deviceId,
      requiredPermission: Permissions.posOperate,
    );
  }

  /// Guards Inventory Stock Adjustments (Physical Audits/Loss).
  void assertCanAdjustInventory(UserSession session, String deviceId) {
    assertPermission(
      session: session,
      deviceId: deviceId,
      requiredPermission: Permissions.inventoryAdjust,
    );
  }

  /// Guards Wallet Fund Transfers.
  void assertCanTransferWallets(UserSession session, String deviceId) {
    assertPermission(
      session: session,
      deviceId: deviceId,
      requiredPermission: Permissions.walletsTransfer,
    );
  }
}
