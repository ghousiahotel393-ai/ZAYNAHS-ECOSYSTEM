/// Deny-by-default Role-Based Access Control (RBAC) Permission Resolver.
/// Enforces Rule 69-78: Strict permission hierarchy, no unauthorized ledger or security operations.
library rbac_resolver;

class Permissions {
  // POS
  static const String posOperate = 'pos:operate';
  static const String posDiscount = 'pos:discount';
  static const String posVoid = 'pos:void';
  static const String posPriceOverride = 'pos:price_override';

  // Inventory
  static const String inventoryView = 'inventory:view';
  static const String inventoryAdjust = 'inventory:adjust';
  static const String inventoryCostView = 'inventory:cost_view';

  // Wallets
  static const String walletsView = 'wallets:view';
  static const String walletsTransfer = 'wallets:transfer';
  static const String walletsDeposit = 'wallets:deposit';
  static const String walletsWithdraw = 'wallets:withdraw';

  // Devices
  static const String devicesView = 'devices:view';
  static const String devicesPair = 'devices:pair';
  static const String devicesRevoke = 'devices:revoke';
  static const String devicesBlock = 'devices:block';

  // Reports
  static const String reportsViewDaily = 'reports:view_daily';
  static const String reportsViewPnl = 'reports:view_pnl';
  static const String reportsExport = 'reports:export';

  // CCTV
  static const String cctvView = 'cctv:view';
  static const String cctvExport = 'cctv:export';
  static const String cctvDelete = 'cctv:delete';

  // System
  static const String settingsManage = 'settings:manage';
  static const String backupCreate = 'backup:create';
  static const String backupRestore = 'backup:restore';
}

class RbacResolver {
  static const Map<String, Set<String>> _rolePermissions = {
    'Owner': {
      '*', // Wildcard - full ecosystem authority
    },
    'Admin': {
      Permissions.posOperate,
      Permissions.posDiscount,
      Permissions.posVoid,
      Permissions.posPriceOverride,
      Permissions.inventoryView,
      Permissions.inventoryAdjust,
      Permissions.inventoryCostView,
      Permissions.walletsView,
      Permissions.walletsTransfer,
      Permissions.walletsDeposit,
      Permissions.walletsWithdraw,
      Permissions.devicesView,
      Permissions.devicesPair,
      Permissions.devicesRevoke,
      Permissions.devicesBlock,
      Permissions.reportsViewDaily,
      Permissions.reportsViewPnl,
      Permissions.reportsExport,
      Permissions.cctvView,
      Permissions.cctvExport,
      Permissions.settingsManage,
      Permissions.backupCreate,
      Permissions.backupRestore,
    },
    'Manager': {
      Permissions.posOperate,
      Permissions.posDiscount,
      Permissions.posVoid,
      Permissions.inventoryView,
      Permissions.inventoryAdjust,
      Permissions.inventoryCostView,
      Permissions.walletsView,
      Permissions.walletsTransfer,
      Permissions.walletsDeposit,
      Permissions.walletsWithdraw,
      Permissions.devicesView,
      Permissions.devicesPair,
      Permissions.reportsViewDaily,
      Permissions.reportsViewPnl,
      Permissions.reportsExport,
      Permissions.cctvView,
      Permissions.cctvExport,
      Permissions.backupCreate,
    },
    'Cashier': {
      Permissions.posOperate,
      Permissions.walletsView,
      Permissions.reportsViewDaily,
    },
    'Salesman': {
      Permissions.posOperate,
      Permissions.inventoryView,
    },
  };

  /// Evaluates whether a role has permission by default (deny-by-default).
  static bool hasRolePermission(String role, String requiredPermission) {
    final permissions = _rolePermissions[role];
    if (permissions == null) return false;

    // Wildcard match for Owner
    if (permissions.contains('*')) return true;

    return permissions.contains(requiredPermission);
  }

  /// Resolves effective permissions by merging role base permissions + custom grants - custom revocations.
  static bool resolve({
    required String? role,
    required bool isActive,
    required String requiredPermission,
    Set<String> customGrants = const {},
    Set<String> customRevocations = const {},
  }) {
    // 1. Inactive or unauthenticated users have ZERO permissions
    if (!isActive || role == null) {
      return false;
    }

    // 2. Custom explicit revocation takes absolute precedence
    if (customRevocations.contains(requiredPermission) || customRevocations.contains('*')) {
      return false;
    }

    // 3. Custom explicit grant
    if (customGrants.contains(requiredPermission) || customGrants.contains('*')) {
      return true;
    }

    // 4. Default role evaluation
    return hasRolePermission(role, requiredPermission);
  }
}
