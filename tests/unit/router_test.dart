import 'dart:io';
import 'package:ui/ui.dart';

void main() {
  int passed = 0;
  int failed = 0;

  void test(String name, void Function() body) {
    try {
      body();
      passed++;
      // ignore: avoid_print
      print('  ✓ $name');
    } catch (e, st) {
      failed++;
      // ignore: avoid_print
      print('  ✗ $name: $e\n$st');
    }
  }

  void expect(dynamic actual, dynamic expected) {
    if (actual != expected) {
      throw AssertionError('Expected: $expected, Actual: $actual');
    }
  }

  // ignore: avoid_print
  print('\n=== Running Router & Deep Link Sanitization Tests ===');

  test('Route resolution matches defined application paths', () {
    expect(AppRoute.findByPath('/pos'), AppRoute.pos);
    expect(AppRoute.findByPath('/inventory'), AppRoute.inventory);
    expect(AppRoute.findByPath('/wallets'), AppRoute.wallets);
    expect(AppRoute.findByPath('/cctv'), AppRoute.cctv);
    expect(AppRoute.findByPath('/non-existent'), AppRoute.notFound);
  });

  test('Path sanitization neutralizes malicious injections and fragments', () {
    expect(AppRoute.sanitizePath('/pos?search=item#header'), '/pos');
    expect(AppRoute.sanitizePath('///inventory///'), '/inventory');
    expect(AppRoute.sanitizePath('/pos/<script>alert(1)</script>'), '/pos/scriptalert1/script');
    expect(AppRoute.sanitizePath('/devices/../../etc/passwd'), '/devices/etc/passwd');
  });

  test('NavigationGuard redirects unauthenticated users to login', () {
    final unauthGuard = NavigationGuard(
      isAuthenticated: () => false,
      hasPermission: (_) => false,
    );

    final dest = unauthGuard.evaluateRoute('/pos');
    expect(dest, AppRoute.login);
  });

  test('NavigationGuard redirects unauthorized users to access-denied', () {
    final authNoPermGuard = NavigationGuard(
      isAuthenticated: () => true,
      hasPermission: (perm) => perm == 'inventory:view', // has inventory, but not pos
    );

    final posDest = authNoPermGuard.evaluateRoute('/pos');
    expect(posDest, AppRoute.accessDenied);

    final invDest = authNoPermGuard.evaluateRoute('/inventory');
    expect(invDest, AppRoute.inventory);
  });

  test('NavigationGuard allows public routes without auth', () {
    final publicGuard = NavigationGuard(
      isAuthenticated: () => false,
      hasPermission: (_) => false,
    );

    expect(publicGuard.evaluateRoute('/login'), AppRoute.login);
    expect(publicGuard.evaluateRoute('/access-denied'), AppRoute.accessDenied);
    expect(publicGuard.evaluateRoute('/unknown-404'), AppRoute.notFound);
  });

  // ignore: avoid_print
  print('\nRouter tests summary: $passed passed, $failed failed.');
  if (failed > 0) {
    exit(1);
  }
}
