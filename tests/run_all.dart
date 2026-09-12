import 'dart:io';
import 'unit/core_test.dart' as core_test;
import 'unit/logger_test.dart' as logger_test;
import 'unit/di_test.dart' as di_test;
import 'unit/router_test.dart' as router_test;
import 'unit/database_test.dart' as database_test;

void main() {
  // ignore: avoid_print
  print('====================================================');
  // ignore: avoid_print
  print('  ZAYNAHS ECOSYSTEM — MASTER TEST SUITE (PHASES 01 & 02)');
  // ignore: avoid_print
  print('====================================================');

  try {
    core_test.main();
    logger_test.main();
    di_test.main();
    router_test.main();
    database_test.main();

    // ignore: avoid_print
    print('\n====================================================');
    // ignore: avoid_print
    print('  ✓ ALL PHASES 01 & 02 TESTS PASSED SUCCESSFULLY');
    // ignore: avoid_print
    print('====================================================');
    exit(0);
  } catch (e, st) {
    // ignore: avoid_print
    print('\nFATAL TEST FAILURE: $e\n$st');
    exit(1);
  }
}
