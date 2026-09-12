/// Deep link and route navigation architecture for Zaynahs Ecosystem.
/// Enforces Rule 106-119 (Type-safe routing, deep link sanitization, and RBAC guards).
library router;

class AppRoute {
  final String path;
  final String title;
  final String? requiredPermission;
  final bool requiresAuth;

  const AppRoute({
    required this.path,
    required this.title,
    this.requiredPermission,
    this.requiresAuth = true,
  });

  static const AppRoute dashboard = AppRoute(
    path: '/',
    title: 'Dashboard',
    requiresAuth: true,
  );

  static const AppRoute pos = AppRoute(
    path: '/pos',
    title: 'Universal POS',
    requiredPermission: 'pos:operate',
  );

  static const AppRoute inventory = AppRoute(
    path: '/inventory',
    title: 'Inventory Ledger',
    requiredPermission: 'inventory:view',
  );

  static const AppRoute wallets = AppRoute(
    path: '/wallets',
    title: 'Wallets & Cash',
    requiredPermission: 'wallets:view',
  );

  static const AppRoute devices = AppRoute(
    path: '/devices',
    title: 'Trusted Peer Devices',
    requiredPermission: 'devices:manage',
  );

  static const AppRoute reports = AppRoute(
    path: '/reports',
    title: 'Financial Reports',
    requiredPermission: 'reports:view',
  );

  static const AppRoute cctv = AppRoute(
    path: '/cctv',
    title: 'CCTV Monitoring',
    requiredPermission: 'cctv:view',
  );

  static const AppRoute settings = AppRoute(
    path: '/settings',
    title: 'System Settings',
    requiredPermission: 'settings:manage',
  );

  static const AppRoute login = AppRoute(
    path: '/login',
    title: 'Sign In',
    requiresAuth: false,
  );

  static const AppRoute accessDenied = AppRoute(
    path: '/access-denied',
    title: 'Access Denied',
    requiresAuth: false,
  );

  static const AppRoute notFound = AppRoute(
    path: '/not-found',
    title: 'Page Not Found',
    requiresAuth: false,
  );

  static const List<AppRoute> allRoutes = [
    dashboard,
    pos,
    inventory,
    wallets,
    devices,
    reports,
    cctv,
    settings,
    login,
    accessDenied,
    notFound,
  ];

  static AppRoute findByPath(String path) {
    final sanitized = sanitizePath(path);
    return allRoutes.firstWhere(
      (r) => r.path == sanitized,
      orElse: () => notFound,
    );
  }

  /// Sanitizes URL path to prevent path traversal and script injection.
  static String sanitizePath(String rawPath) {
    var path = rawPath.trim();
    if (path.isEmpty) return '/';
    // Remove query parameters or fragments for path matching
    if (path.contains('?')) path = path.split('?').first;
    if (path.contains('#')) path = path.split('#').first;
    // Strip illegal characters
    path = path.replaceAll(RegExp(r'[^a-zA-Z0-9_\-\/]'), '');
    // Normalize double slashes
    while (path.contains('//')) {
      path = path.replaceAll('//', '/');
    }
    // Trim trailing slashes unless root '/'
    while (path.length > 1 && path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }
    return path;
  }
}

/// Navigation Guard evaluating authentication and permissions before route transition.
class NavigationGuard {
  final bool Function() isAuthenticated;
  final bool Function(String permission) hasPermission;

  const NavigationGuard({
    required this.isAuthenticated,
    required this.hasPermission,
  });

  /// Evaluates target route and returns redirect route if access is denied.
  AppRoute evaluateRoute(String rawPath) {
    final route = AppRoute.findByPath(rawPath);

    if (route == AppRoute.notFound || route == AppRoute.login || route == AppRoute.accessDenied) {
      return route;
    }

    if (route.requiresAuth && !isAuthenticated()) {
      return AppRoute.login;
    }

    if (route.requiredPermission != null && !hasPermission(route.requiredPermission!)) {
      return AppRoute.accessDenied;
    }

    return route;
  }
}
