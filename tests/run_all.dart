import 'dart:io';
import 'unit/core_test.dart' as core_test;
import 'unit/logger_test.dart' as logger_test;
import 'unit/di_test.dart' as di_test;
import 'unit/router_test.dart' as router_test;

void main() {
  // ignore: avoid_print
  print('====================================================');
  // ignore: avoid_print
  print('  ZAYNAHS ECOSYSTEM — PHASE-01 FOUNDATION TEST SUITE');
  // ignore: avoid_print
  print('====================================================');

  try {
    core_test.main();
    logger_test.main();
    di_test.main();
    router_test.main();

    // ignore: avoid_print
    print('\n====================================================');
    // ignore: avoid_print
    print('  ✓ ALL PHASE-01 FOUNDATION TESTS PASSED SUCCESSFULLY');
    // ignore: avoid_print
    print('====================================================');
    exit(0);
  } catch (e, st) {
    // ignore: avoid_print
    print('\nFATAL TEST FAILURE: $e\n$st');
    exit(1);
  }
}
