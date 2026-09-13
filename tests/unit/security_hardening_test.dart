import 'dart:io';
import 'package:auth/auth.dart';
import 'package:core/core.dart';
import 'package:database/database.dart';
import 'package:ui/ui.dart';

void main() {
  // ignore: avoid_print
  print('\n=== Running System Hardening, Security Audit & Golden Test 103 Tests ===');

  int passed = 0;
  int failed = 0;

  void test(String name, void Function() fn) {
    try {
      fn();
      // ignore: avoid_print
      print('  ✓ $name');
      passed++;
    } catch (e, st) {
      // ignore: avoid_print
      print('  ✗ $name: $e\n$st');
      failed++;
    }
  }

  void expect(dynamic actual, dynamic expected) {
    if (actual != expected) {
      throw Exception('Expected $expected but got $actual');
    }
  }

  AppDatabase openTestDb(Directory tempDir, String name) {
    final dbFile = File('${tempDir.path}/$name.db');
    final db = AppDatabase.openFile(dbFile.path);
    db.initialize();
    return db;
  }

  // -------------------------------------------------------------
  // Test 1: Untrusted Device Denied (Pending / Unknown / Blocked)
  // -------------------------------------------------------------
  test('Golden Test 103 (1/7): Untrusted devices (PENDING, BLOCKED, UNKNOWN) are strictly denied', () {
    final tempDir = Directory.systemTemp.createTempSync('zyn_sec_test_');
    final db = openTestDb(tempDir, 'sec_test_01');
    final deviceRepo = DeviceRepository(db);
    final deviceTrustManager = DeviceTrustManager(deviceRepo);
    final gatekeeper = SecurityGatekeeper(
      deviceTrustManager: deviceTrustManager,
      deviceRepo: deviceRepo,
    );

    final now = DateTime.now().toUtc();

    // Register devices with various trust states
    deviceRepo.registerPendingDevice(
      DeviceEntity(
        id: 'dev_pending_01',
        name: 'Pending Tablet',
        trustStatus: 'PENDING',
        publicKey: 'pub_pending_01',
        lastSeenAt: now,
      ),
    );

    deviceRepo.registerPendingDevice(
      DeviceEntity(
        id: 'dev_blocked_01',
        name: 'Blocked Mobile',
        trustStatus: 'PENDING',
        publicKey: 'pub_blocked_01',
        lastSeenAt: now,
      ),
    );
    deviceTrustManager.transitionDeviceState('dev_blocked_01', 'BLOCKED');

    // A. Pending device must be denied
    bool pendingDenied = false;
    try {
      gatekeeper.assertDeviceTrusted('dev_pending_01');
    } on AuthException catch (e) {
      pendingDenied = true;
      expect(e.code, 'AUTH_DEVICE_UNTRUSTED');
    }
    expect(pendingDenied, true);

    // B. Blocked device must be denied
    bool blockedDenied = false;
    try {
      gatekeeper.assertDeviceTrusted('dev_blocked_01');
    } on AuthException catch (e) {
      blockedDenied = true;
      expect(e.code, 'AUTH_DEVICE_UNTRUSTED');
    }
    expect(blockedDenied, true);

    // C. Unknown device must be denied
    bool unknownDenied = false;
    try {
      gatekeeper.assertDeviceTrusted('dev_unknown_99');
    } on AuthException catch (e) {
      unknownDenied = true;
      expect(e.code, 'AUTH_DEVICE_UNTRUSTED');
    }
    expect(unknownDenied, true);

    db.close();
    tempDir.deleteSync(recursive: true);
  });

  // -------------------------------------------------------------
  // Test 2: Revoked Device Denied
  // -------------------------------------------------------------
  test('Golden Test 103 (2/7): Revoked device is immediately and irrevocably denied from operations', () {
    final tempDir = Directory.systemTemp.createTempSync('zyn_sec_test_');
    final db = openTestDb(tempDir, 'sec_test_02');
    final deviceRepo = DeviceRepository(db);
    final deviceTrustManager = DeviceTrustManager(deviceRepo);
    final gatekeeper = SecurityGatekeeper(
      deviceTrustManager: deviceTrustManager,
      deviceRepo: deviceRepo,
    );

    final now = DateTime.now().toUtc();

    // Register and approve device
    deviceRepo.registerPendingDevice(
      DeviceEntity(
        id: 'dev_stolen_01',
        name: 'Compromised Device',
        trustStatus: 'PENDING',
        publicKey: 'pub_stolen_01',
        lastSeenAt: now,
      ),
    );
    deviceTrustManager.transitionDeviceState('dev_stolen_01', 'TRUSTED');
    expect(deviceTrustManager.isDeviceAuthorized('dev_stolen_01'), true);

    // Compromise reported -> transition to REVOKED
    deviceTrustManager.transitionDeviceState('dev_stolen_01', 'REVOKED');
    expect(deviceTrustManager.isDeviceAuthorized('dev_stolen_01'), false);

    bool revokedDenied = false;
    try {
      gatekeeper.assertDeviceTrusted('dev_stolen_01');
    } on AuthException catch (e) {
      revokedDenied = true;
      expect(e.code, 'AUTH_DEVICE_REVOKED');
    }
    expect(revokedDenied, true);

    db.close();
    tempDir.deleteSync(recursive: true);
  });

  // -------------------------------------------------------------
  // Test 3: Unauthorized User Denied (RBAC Role Boundaries)
  // -------------------------------------------------------------
  test('Golden Test 103 (3/7): Unauthorized users (Cashier/Salesman) are denied from privileged operations', () {
    final tempDir = Directory.systemTemp.createTempSync('zyn_sec_test_');
    final db = openTestDb(tempDir, 'sec_test_03');
    final deviceRepo = DeviceRepository(db);
    final deviceTrustManager = DeviceTrustManager(deviceRepo);
    final gatekeeper = SecurityGatekeeper(
      deviceTrustManager: deviceTrustManager,
      deviceRepo: deviceRepo,
    );

    final now = DateTime.now().toUtc();
    deviceRepo.registerPendingDevice(
      DeviceEntity(
        id: 'dev_trusted_01',
        name: 'Main Counter',
        trustStatus: 'PENDING',
        publicKey: 'pub_trusted_01',
        lastSeenAt: now,
      ),
    );
    deviceTrustManager.transitionDeviceState('dev_trusted_01', 'TRUSTED');

    final cashierSession = UserSession.create(
      userId: 'usr_cashier',
      name: 'Cashier Bilal',
      email: 'bilal@store.local',
      role: 'Cashier',
    );

    final salesmanSession = UserSession.create(
      userId: 'usr_salesman',
      name: 'Salesman Tariq',
      email: 'tariq@store.local',
      role: 'Salesman',
    );

    // Cashier allowed POS operations
    gatekeeper.assertCanOperatePos(cashierSession, 'dev_trusted_01');

    // Cashier denied Wallet Transfers
    bool walletDenied = false;
    try {
      gatekeeper.assertCanTransferWallets(cashierSession, 'dev_trusted_01');
    } on PermissionDeniedException catch (e) {
      walletDenied = true;
      expect(e.requiredPermission, Permissions.walletsTransfer);
    }
    expect(walletDenied, true);

    // Cashier denied Inventory Adjustments
    bool invAdjustDenied = false;
    try {
      gatekeeper.assertCanAdjustInventory(cashierSession, 'dev_trusted_01');
    } on PermissionDeniedException catch (e) {
      invAdjustDenied = true;
      expect(e.requiredPermission, Permissions.inventoryAdjust);
    }
    expect(invAdjustDenied, true);

    // Salesman denied POS Price Overrides
    bool priceOverrideDenied = false;
    try {
      gatekeeper.assertPermission(
        session: salesmanSession,
        deviceId: 'dev_trusted_01',
        requiredPermission: Permissions.posPriceOverride,
      );
    } on PermissionDeniedException catch (e) {
      priceOverrideDenied = true;
      expect(e.requiredPermission, Permissions.posPriceOverride);
    }
    expect(priceOverrideDenied, true);

    db.close();
    tempDir.deleteSync(recursive: true);
  });

  // -------------------------------------------------------------
  // Test 4: Direct API & Hidden UI Bypass Denied
  // -------------------------------------------------------------
  test('Golden Test 103 (4/7): Direct API invocation without valid active session or permission throws typed error', () {
    final tempDir = Directory.systemTemp.createTempSync('zyn_sec_test_');
    final db = openTestDb(tempDir, 'sec_test_04');
    final deviceRepo = DeviceRepository(db);
    final deviceTrustManager = DeviceTrustManager(deviceRepo);
    final gatekeeper = SecurityGatekeeper(
      deviceTrustManager: deviceTrustManager,
      deviceRepo: deviceRepo,
    );

    final now = DateTime.now().toUtc();
    deviceRepo.registerPendingDevice(
      DeviceEntity(
        id: 'dev_trusted_01',
        name: 'Main Counter',
        trustStatus: 'PENDING',
        publicKey: 'pub_trusted_01',
        lastSeenAt: now,
      ),
    );
    deviceTrustManager.transitionDeviceState('dev_trusted_01', 'TRUSTED');

    // Create an expired session
    final expiredSession = UserSession(
      token: 'tok_expired_test',
      userId: 'usr_admin',
      name: 'Admin User',
      email: 'admin@store.local',
      role: 'Admin',
      createdAt: now.subtract(const Duration(hours: 1)),
      lastActivityAt: now.subtract(const Duration(hours: 1)),
      timeoutDuration: const Duration(minutes: 15),
    );
    expect(expiredSession.isExpired, true);

    bool expiredDenied = false;
    try {
      gatekeeper.assertCanRestore(expiredSession, 'dev_trusted_01');
    } on AuthException catch (e) {
      expiredDenied = true;
      expect(e.code, 'AUTH_SESSION_EXPIRED');
    }
    expect(expiredDenied, true);

    db.close();
    tempDir.deleteSync(recursive: true);
  });

  // -------------------------------------------------------------
  // Test 5: Deep-Link Bypass Denied
  // -------------------------------------------------------------
  test('Golden Test 103 (5/7): Deep-link bypass attempts are intercepted by NavigationGuard and routed to Access Denied', () {
    // Unauthenticated guard
    final unauthGuard = NavigationGuard(
      isAuthenticated: () => false,
      hasPermission: (_) => false,
    );

    // Deep link to /settings/restore -> redirects to login
    expect(unauthGuard.evaluateRoute('/settings/restore'), AppRoute.login);
    expect(unauthGuard.evaluateRoute('/cctv/delete'), AppRoute.login);

    // Authenticated as Cashier (has pos:operate, wallets:view, reports:view_daily)
    final cashierPermissions = {
      Permissions.posOperate,
      Permissions.walletsView,
      Permissions.reportsViewDaily,
    };
    final cashierGuard = NavigationGuard(
      isAuthenticated: () => true,
      hasPermission: (perm) => cashierPermissions.contains(perm),
    );

    // Cashier trying to deep-link to /settings/restore -> access denied
    expect(cashierGuard.evaluateRoute('/settings/restore'), AppRoute.accessDenied);

    // Cashier trying to deep-link to /cctv/delete -> access denied
    expect(cashierGuard.evaluateRoute('/cctv/delete'), AppRoute.accessDenied);

    // Cashier trying to deep-link to /wallets/transfer -> access denied
    expect(cashierGuard.evaluateRoute('/wallets/transfer'), AppRoute.accessDenied);

    // Cashier navigating to permitted /pos -> allowed
    expect(cashierGuard.evaluateRoute('/pos'), AppRoute.pos);

    // Authenticated as Owner (wildcard)
    final ownerGuard = NavigationGuard(
      isAuthenticated: () => true,
      hasPermission: (_) => true,
    );
    expect(ownerGuard.evaluateRoute('/settings/restore'), AppRoute.backupRestore);
    expect(ownerGuard.evaluateRoute('/cctv/delete'), AppRoute.cctvDelete);
    expect(ownerGuard.evaluateRoute('/wallets/transfer'), AppRoute.walletsTransfer);
  });

  // -------------------------------------------------------------
  // Test 6: Backup Restore Permission Strictly Enforced
  // -------------------------------------------------------------
  test('Golden Test 103 (6/7): Backup Restore is restricted to Owner and Admin only; Manager/Cashier rejected', () {
    final tempDir = Directory.systemTemp.createTempSync('zyn_sec_test_');
    final db = openTestDb(tempDir, 'sec_test_06');
    final deviceRepo = DeviceRepository(db);
    final deviceTrustManager = DeviceTrustManager(deviceRepo);
    final gatekeeper = SecurityGatekeeper(
      deviceTrustManager: deviceTrustManager,
      deviceRepo: deviceRepo,
    );

    final now = DateTime.now().toUtc();
    deviceRepo.registerPendingDevice(
      DeviceEntity(
        id: 'dev_trusted_01',
        name: 'Main Counter',
        trustStatus: 'PENDING',
        publicKey: 'pub_trusted_01',
        lastSeenAt: now,
      ),
    );
    deviceTrustManager.transitionDeviceState('dev_trusted_01', 'TRUSTED');

    final ownerSession = UserSession.create(
      userId: 'usr_owner',
      name: 'Owner Zaynah',
      email: 'owner@store.local',
      role: 'Owner',
    );
    final adminSession = UserSession.create(
      userId: 'usr_admin',
      name: 'Admin Ali',
      email: 'admin@store.local',
      role: 'Admin',
    );
    final managerSession = UserSession.create(
      userId: 'usr_mgr',
      name: 'Manager Saad',
      email: 'mgr@store.local',
      role: 'Manager',
    );
    final cashierSession = UserSession.create(
      userId: 'usr_cashier',
      name: 'Cashier Bilal',
      email: 'cashier@store.local',
      role: 'Cashier',
    );

    // Owner and Admin must pass
    gatekeeper.assertCanRestore(ownerSession, 'dev_trusted_01');
    gatekeeper.assertCanRestore(adminSession, 'dev_trusted_01');

    // Manager must fail
    bool mgrDenied = false;
    try {
      gatekeeper.assertCanRestore(managerSession, 'dev_trusted_01');
    } on PermissionDeniedException {
      mgrDenied = true;
    }
    expect(mgrDenied, true);

    // Cashier must fail
    bool cashierDenied = false;
    try {
      gatekeeper.assertCanRestore(cashierSession, 'dev_trusted_01');
    } on PermissionDeniedException {
      cashierDenied = true;
    }
    expect(cashierDenied, true);

    db.close();
    tempDir.deleteSync(recursive: true);
  });

  // -------------------------------------------------------------
  // Test 7: Recording Deletion Protected (Owner-Only Rule 63, 103)
  // -------------------------------------------------------------
  test('Golden Test 103 (7/7): CCTV Segment Deletion is strictly reserved for Owner; Admin/Manager rejected', () {
    final tempDir = Directory.systemTemp.createTempSync('zyn_sec_test_');
    final db = openTestDb(tempDir, 'sec_test_07');
    final deviceRepo = DeviceRepository(db);
    final deviceTrustManager = DeviceTrustManager(deviceRepo);
    final gatekeeper = SecurityGatekeeper(
      deviceTrustManager: deviceTrustManager,
      deviceRepo: deviceRepo,
    );

    final now = DateTime.now().toUtc();
    deviceRepo.registerPendingDevice(
      DeviceEntity(
        id: 'dev_trusted_01',
        name: 'Main Counter',
        trustStatus: 'PENDING',
        publicKey: 'pub_trusted_01',
        lastSeenAt: now,
      ),
    );
    deviceTrustManager.transitionDeviceState('dev_trusted_01', 'TRUSTED');

    final ownerSession = UserSession.create(
      userId: 'usr_owner',
      name: 'Owner Zaynah',
      email: 'owner@store.local',
      role: 'Owner',
    );
    final adminSession = UserSession.create(
      userId: 'usr_admin',
      name: 'Admin Ali',
      email: 'admin@store.local',
      role: 'Admin',
    );

    // Owner passes
    gatekeeper.assertCanDeleteCctv(ownerSession, 'dev_trusted_01');

    // Admin rejected for CCTV deletion
    bool adminDenied = false;
    try {
      gatekeeper.assertCanDeleteCctv(adminSession, 'dev_trusted_01');
    } on PermissionDeniedException catch (e) {
      adminDenied = true;
      expect(e.requiredPermission, Permissions.cctvDelete);
    }
    expect(adminDenied, true);

    db.close();
    tempDir.deleteSync(recursive: true);
  });

  // -------------------------------------------------------------
  // Test 8: Secret Scanner & Log Hygiene (Zero Secrets Law)
  // -------------------------------------------------------------
  test('Secret Hygiene: Scanner flags unredacted tokens and confirms sanitized AppLogger streams', () {
    // A. Detect exposed secrets
    final sampleWithSecret = '''
      User logged in successfully.
      token: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.e30.t-IDcSemACt8x4iTMC6Y5
      endpoint: /api/v1/sync
    ''';
    final findings = SecretScanner.scanText(sampleWithSecret);
    expect(findings.isNotEmpty, true);
    expect(findings.first.rule, 'ZERO_SECRETS_VIOLATION');

    // B. Verify clean redacted output passes assertZeroSecrets
    final sanitizedLog = '''
      User logged in successfully.
      token: [REDACTED]
      endpoint: /api/v1/sync
    ''';
    SecretScanner.assertZeroSecrets(sanitizedLog);

    // C. Verify AppLogger redacts bearer tokens and passwords automatically
    final mockToken = 'cfut_' + 'synthetic_mock_security_token_0123456789abcdef';
    final logEntries = <LogEntry>[];
    final logger = AppLogger(tag: 'SecurityTest', sinks: [logEntries.add]);
    logger.info(
      'Connecting with Bearer $mockToken',
      {'password': 'SuperSecretPassword123!'},
    );
    expect(logEntries.length, 1);
    final logMsg = logEntries.first.message;
    final metaStr = logEntries.first.metadata.toString();
    expect(logMsg.contains(mockToken), false);
    expect(logMsg.contains('[REDACTED]'), true);
    expect(metaStr.contains('SuperSecretPassword123!'), false);
    expect(metaStr.contains('[REDACTED]'), true);

    final directRedacted = AppLogger.redact(
      'Bearer $mockToken',
    );
    expect(directRedacted.contains('[REDACTED]'), true);
  });

  // -------------------------------------------------------------
  // Test 9: Stress & Crash Recovery (SQLite WAL Atomic Rollback)
  // -------------------------------------------------------------
  test('Crash Recovery: Mid-transaction failure triggers WAL rollback leaving zero orphaned records', () {
    final tempDir = Directory.systemTemp.createTempSync('zyn_crash_test_');
    final db = openTestDb(tempDir, 'crash_test');

    // Pre-state: insert baseline user
    final now = DateTime.now().toUtc();
    db.connection.execute(
      '''
      INSERT INTO users (id, name, email, role, password_hash, pin_hash, is_active, created_at, updated_at)
      VALUES ('usr_baseline', 'Baseline User', 'base@store.local', 'Cashier', 'hash', 'pinhash', 1, ?, ?)
      ''',
      [now.toIso8601String(), now.toIso8601String()],
    );

    // Execute transaction that fails mid-way
    bool exceptionThrown = false;
    try {
      db.transaction(() {
        // Step 1: insert user
        db.connection.execute(
          '''
          INSERT INTO users (id, name, email, role, password_hash, pin_hash, is_active, created_at, updated_at)
          VALUES ('usr_crashed', 'Crashed User', 'crash@store.local', 'Cashier', 'hash', 'pinhash', 1, ?, ?)
          ''',
          [now.toIso8601String(), now.toIso8601String()],
        );

        // Step 2: Simulate crash or unhandled error before commit
        throw StateError('Simulated unexpected power loss / crash mid-transaction');
      });
    } catch (_) {
      exceptionThrown = true;
    }
    expect(exceptionThrown, true);

    // Verify: Database state rolled back completely
    final rows = db.connection.select("SELECT * FROM users WHERE id = 'usr_crashed'");
    expect(rows.isEmpty, true);

    // Baseline user still intact
    final baseline = db.connection.select("SELECT * FROM users WHERE id = 'usr_baseline'");
    expect(baseline.length, 1);

    db.close();
    tempDir.deleteSync(recursive: true);
  });

  // -------------------------------------------------------------
  // Test 10: Resource Leak Profiling (Rule 99, 105)
  // -------------------------------------------------------------
  test('Resource Profiling: Tracker asserts clean disposal without dangling handles', () {
    final tracker = ResourceTracker();
    tracker.reset();

    // Track simulated resources
    tracker.track('db_instance_01', 'DATABASE');
    tracker.track('stream_cctv_cam1', 'CAMERA_STREAM');
    tracker.track('file_sink_seg1', 'FILE_STREAM');
    expect(tracker.activeCount, 3);

    // Untrack as they are closed
    tracker.untrack('db_instance_01');
    tracker.untrack('stream_cctv_cam1');
    tracker.untrack('file_sink_seg1');
    expect(tracker.activeCount, 0);

    // Assert all released passes cleanly
    tracker.assertAllReleased();

    // Verify detection if a resource is leaked
    tracker.track('dangling_socket_01', 'NETWORK_SOCKET');
    bool leakDetected = false;
    try {
      tracker.assertAllReleased();
    } on StateError catch (e) {
      leakDetected = true;
      expect(e.message.contains('Resource leak detected'), true);
    }
    expect(leakDetected, true);

    tracker.reset();
  });

  // Summary
  // ignore: avoid_print
  print('\n=== System Hardening & Security Audit Summary ===');
  // ignore: avoid_print
  print('Passed: $passed, Failed: $failed');

  if (failed > 0) {
    throw Exception('$failed tests failed in System Hardening & Golden Test 103 (Phase 13)!');
  }
}
