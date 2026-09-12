import 'dart:io';
import 'package:core/core.dart';

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

  void assertTrue(bool condition, [String? message]) {
    if (!condition) {
      throw AssertionError(message ?? 'Expected condition to be true');
    }
  }

  // ignore: avoid_print
  print('\n=== Running Core Domain & Primitives Tests ===');

  test('Result type fold and accessors', () {
    final success = Result<int, String>.success(42);
    assertTrue(success.isSuccess);
    assertTrue(!success.isFailure);
    expect(success.dataOrNull, 42);
    expect(success.errorOrNull, null);
    final val = success.fold(onSuccess: (d) => d * 2, onFailure: (e) => 0);
    expect(val, 84);

    final failure = Result<int, String>.failure('error_code');
    assertTrue(failure.isFailure);
    assertTrue(!failure.isSuccess);
    expect(failure.dataOrNull, null);
    expect(failure.errorOrNull, 'error_code');
  });

  test('Exception hierarchy code and message mapping', () {
    final authEx = AuthException.invalidCredentials();
    expect(authEx.code, 'AUTH_INVALID_CREDENTIALS');
    assertTrue(authEx.message.contains('Invalid'));

    final rbacEx = PermissionDeniedException.forAction('pos:operate');
    expect(rbacEx.code, 'PERMISSION_DENIED');
    assertTrue(rbacEx.message.contains('pos:operate'));
  });

  test('EntityId validation and UUID generation', () {
    final ecoId = EcosystemId.generate();
    assertTrue(ecoId.value.startsWith('eco_'));
    assertTrue(EntityId.isValidId(ecoId.value));

    final devId = DeviceId.generate();
    assertTrue(devId.value.startsWith('dev_'));

    final usrId = UserId.generate();
    assertTrue(usrId.value.startsWith('usr_'));

    final saleId = SaleId.generate();
    assertTrue(saleId.value.startsWith('sale_'));

    final walletId = WalletId.generate();
    assertTrue(walletId.value.startsWith('wal_'));

    expect(EcosystemId.fromString('eco_test_123').value, 'eco_test_123');
  });

  test('Money precision arithmetic and allocation (zero penny loss)', () {
    final m1 = Money.fromMinorUnits(15050, Currency.pkr); // 150.50
    final m2 = Money.fromMinorUnits(4950, Currency.pkr);  // 49.50
    final sum = m1 + m2;
    expect(sum.minorUnits, 20000);
    expect(sum.format(), 'Rs 200.00');

    final diff = m1 - m2;
    expect(diff.minorUnits, 10100);
    expect(diff.format(), 'Rs 101.00');

    final multiplied = m2 * 3;
    expect(multiplied.minorUnits, 14850);

    // Allocation test: 1000 minor units divided into 3 portions
    final hundredPkr = Money.fromMinorUnits(1000, Currency.pkr);
    final shares = hundredPkr.allocate(3);
    expect(shares.length, 3);
    expect(shares[0].minorUnits, 334);
    expect(shares[1].minorUnits, 333);
    expect(shares[2].minorUnits, 333);
    // Strict sum conservation
    final allocatedTotal = shares[0] + shares[1] + shares[2];
    expect(allocatedTotal.minorUnits, 1000);
  });

  test('AppConfig parsing and validation', () {
    const rawEnv = '''
ENVIRONMENT=production
APP_VERSION=2.0.1
ECOSYSTEM_NAME=Zaynahs Flagship
SUPABASE_URL=https://nuttyuaobjuscvvkittd.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOi...
CLOUDFLARE_ACCOUNT_ID=46a125bb1125e257393bcdf17864afd4
LOCAL_P2P_PORT=53317
''';
    final parsed = AppConfig.parseEnvString(rawEnv);
    final config = AppConfig.fromMap(parsed);
    expect(config.environment, 'production');
    assertTrue(config.isProduction);
    expect(config.appVersion, '2.0.1');
    expect(config.ecosystemName, 'Zaynahs Flagship');
    expect(config.supabaseUrl, 'https://nuttyuaobjuscvvkittd.supabase.co');
    expect(config.localP2pPort, 53317);

    final errors = config.validate();
    expect(errors.length, 0);
  });

  // ignore: avoid_print
  print('\nCore tests summary: $passed passed, $failed failed.');
  if (failed > 0) {
    exit(1);
  }
}
