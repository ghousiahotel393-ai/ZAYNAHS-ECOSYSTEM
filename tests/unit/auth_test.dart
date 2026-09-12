import 'dart:io';
import 'package:auth/auth.dart';
import 'package:database/database.dart';

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
  print('\n=== Running Identity, RBAC & Device Trust Tests ===');

  test('PBKDF2 password hashing and verification', () {
    const password = 'StrongPassword123!';
    final hash = CryptoUtils.hashPassword(password);
    assertTrue(hash.startsWith('pbkdf2\$'));

    assertTrue(CryptoUtils.verifyPassword(password, hash));
    assertTrue(!CryptoUtils.verifyPassword('WrongPassword', hash));
  });

  test('Salted numeric PIN hashing and verification', () {
    const pin = '123456';
    final hash = CryptoUtils.hashPin(pin);
    assertTrue(hash.startsWith('pin\$'));

    assertTrue(CryptoUtils.verifyPin('123456', hash));
    assertTrue(!CryptoUtils.verifyPin('654321', hash));
    assertTrue(!CryptoUtils.verifyPin('1234', hash));
  });

  test('Constant-time string comparison', () {
    assertTrue(CryptoUtils.constantTimeEquals('secret_token', 'secret_token'));
    assertTrue(!CryptoUtils.constantTimeEquals('secret_token', 'secret_tokeX'));
    assertTrue(!CryptoUtils.constantTimeEquals('short', 'longer_string'));
  });

  test('RBAC resolver enforces deny-by-default and role boundaries', () {
    // 1. Owner has wildcard access
    assertTrue(RbacResolver.resolve(
      role: 'Owner',
      isActive: true,
      requiredPermission: Permissions.walletsTransfer,
    ));
    assertTrue(RbacResolver.resolve(
      role: 'Owner',
      isActive: true,
      requiredPermission: Permissions.reportsViewPnl,
    ));

    // 2. Cashier can operate POS, but cannot transfer wallets or view P&L
    assertTrue(RbacResolver.resolve(
      role: 'Cashier',
      isActive: true,
      requiredPermission: Permissions.posOperate,
    ));
    assertTrue(!RbacResolver.resolve(
      role: 'Cashier',
      isActive: true,
      requiredPermission: Permissions.walletsTransfer,
    ));
    assertTrue(!RbacResolver.resolve(
      role: 'Cashier',
      isActive: true,
      requiredPermission: Permissions.reportsViewPnl,
    ));
    assertTrue(!RbacResolver.resolve(
      role: 'Cashier',
      isActive: true,
      requiredPermission: Permissions.devicesPair,
    ));

    // 3. Inactive users have 0 permissions even if Owner
    assertTrue(!RbacResolver.resolve(
      role: 'Owner',
      isActive: false,
      requiredPermission: Permissions.posOperate,
    ));

    // 4. Custom revocations strictly override role grants
    assertTrue(!RbacResolver.resolve(
      role: 'Manager',
      isActive: true,
      requiredPermission: Permissions.walletsTransfer,
      customRevocations: {Permissions.walletsTransfer},
    ));

    // 5. Custom grants allow specific extra privileges
    assertTrue(RbacResolver.resolve(
      role: 'Cashier',
      isActive: true,
      requiredPermission: Permissions.inventoryView,
      customGrants: {Permissions.inventoryView},
    ));
  });

  test('UserSession auto-lock timeout and refresh', () {
    final session = UserSession.create(
      userId: 'usr_cashier_01',
      name: 'Ali Cashier',
      email: 'ali@zaynahs.local',
      role: 'Cashier',
      timeoutDuration: const Duration(milliseconds: 50),
    );

    assertTrue(session.isValid);
    assertTrue(session.hasPermission(Permissions.posOperate));
    assertTrue(!session.hasPermission(Permissions.walletsTransfer));

    // Simulate timeout by modifying lastActivityAt to the past
    session.lastActivityAt = DateTime.now().toUtc().subtract(const Duration(minutes: 16));
    assertTrue(!session.isValid);
    assertTrue(!session.hasPermission(Permissions.posOperate));

    // Refresh activity
    session.touch();
    assertTrue(session.isValid);
  });

  test('DeviceTrustManager state machine transitions', () {
    final db = AppDatabase.openInMemory();
    db.initialize();
    final devRepo = DeviceRepository(db);
    final trustMgr = DeviceTrustManager(devRepo);

    const devId = 'dev_counter_01';
    final now = DateTime.now().toUtc();
    devRepo.registerPendingDevice(DeviceEntity(
      id: devId,
      name: 'Counter Tablet',
      trustStatus: 'PENDING',
      publicKey: 'pk_ed25519_counter',
      lastSeenAt: now,
    ));

    assertTrue(!trustMgr.isDeviceAuthorized(devId));

    // PENDING -> TRUSTED
    trustMgr.transitionDeviceState(devId, 'TRUSTED');
    assertTrue(trustMgr.isDeviceAuthorized(devId));

    // TRUSTED -> REVOKED
    trustMgr.transitionDeviceState(devId, 'REVOKED');
    assertTrue(!trustMgr.isDeviceAuthorized(devId));

    // REVOKED -> TRUSTED is illegal without new pairing handshake
    bool illegalThrew = false;
    try {
      trustMgr.transitionDeviceState(devId, 'TRUSTED');
    } catch (_) {
      illegalThrew = true;
    }
    assertTrue(illegalThrew, 'Expected illegal transition exception');

    db.close();
  });

  test('PairingService 6-digit challenge code and QR payload protocol', () {
    final db = AppDatabase.openInMemory();
    db.initialize();
    final devRepo = DeviceRepository(db);
    final pairingService = PairingService(devRepo);

    const devId = 'dev_sales_phone_02';
    final session = pairingService.createPairingSession(
      deviceId: devId,
      deviceName: 'Salesman Android',
      publicKey: 'pk_ed25519_phone',
    );

    expect(session.pairingCode.length, 6);
    assertTrue(int.tryParse(session.pairingCode) != null);

    // Verify QR payload serialization and roundtrip
    final qrString = session.toQrPayload();
    final parsed = PairingSession.fromQrPayload(qrString);
    expect(parsed.sessionId, session.sessionId);
    expect(parsed.deviceId, devId);
    expect(parsed.pairingCode, session.pairingCode);

    // Initial state: PENDING
    final dev = devRepo.getDeviceById(devId);
    assertTrue(dev != null);
    assertTrue(dev!.isPending);

    // Attempt with invalid 6-digit code
    final wrongApproval = pairingService.approvePairing(
      sessionId: session.sessionId,
      enteredPairingCode: '000000',
      approverUserId: 'usr_admin',
    );
    assertTrue(!wrongApproval);
    assertTrue(devRepo.getDeviceById(devId)!.isPending);

    // Approve with correct 6-digit code
    final correctApproval = pairingService.approvePairing(
      sessionId: session.sessionId,
      enteredPairingCode: session.pairingCode,
      approverUserId: 'usr_admin',
    );
    assertTrue(correctApproval);
    assertTrue(devRepo.getDeviceById(devId)!.isTrusted);

    db.close();
  });

  // ignore: avoid_print
  print('\nAuth tests summary: $passed passed, $failed failed.');
  if (failed > 0) {
    exit(1);
  }
}
