import 'dart:io';
import 'unit/core_test.dart' as core_test;
import 'unit/logger_test.dart' as logger_test;
import 'unit/di_test.dart' as di_test;
import 'unit/router_test.dart' as router_test;
import 'unit/database_test.dart' as database_test;
import 'unit/auth_test.dart' as auth_test;
import 'unit/storage_test.dart' as storage_test;
import 'unit/sync_test.dart' as sync_test;
import 'unit/p2p_test.dart' as p2p_test;
import 'unit/collaboration_test.dart' as collaboration_test;
import 'unit/pos_test.dart' as pos_test;
import 'unit/advanced_pos_test.dart' as advanced_pos_test;
import 'unit/reporting_test.dart' as reporting_test;
import 'unit/cctv_test.dart' as cctv_test;
import 'unit/backup_test.dart' as backup_test;
import 'unit/security_hardening_test.dart' as security_hardening_test;
import 'unit/cross_platform_test.dart' as cross_platform_test;

Future<void> main() async {
  // ignore: avoid_print
  print('====================================================');
  // ignore: avoid_print
  print('  ZAYNAHS ECOSYSTEM — MASTER TEST SUITE (PHASES 01-14)');
  // ignore: avoid_print
  print('====================================================');

  try {
    core_test.main();
    logger_test.main();
    di_test.main();
    router_test.main();
    database_test.main();
    auth_test.main();
    await storage_test.main();
    await sync_test.main();
    await p2p_test.main();
    await collaboration_test.main();
    pos_test.main();
    advanced_pos_test.main();
    await reporting_test.main();
    await cctv_test.main();
    await backup_test.main();
    security_hardening_test.main();
    cross_platform_test.main();

    // ignore: avoid_print
    print('\n====================================================');
    // ignore: avoid_print
    print('  ✓ ALL PHASES 01-14 TESTS PASSED SUCCESSFULLY (INCL GOLDEN 100, 101, 102, 103, 104, 105)');
    // ignore: avoid_print
    print('====================================================');
    exit(0);
  } catch (e, st) {
    // ignore: avoid_print
    print('\nFATAL TEST FAILURE: $e\n$st');
    exit(1);
  }
}
