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
  print('\n=== Running AppLogger & Zero Secrets Tests ===');

  test('AppLogger automatically redacts Bearer tokens', () {
    final entries = <LogEntry>[];
    final logger = AppLogger(
      tag: 'TestAuth',
      sinks: [entries.add],
    );

    logger.info('User request with Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.xyz.abc');
    expect(entries.length, 1);
    assertTrue(!entries[0].message.contains('eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9'));
    assertTrue(entries[0].message.contains('[REDACTED]'));
  });

  test('AppLogger automatically redacts password in metadata', () {
    final entries = <LogEntry>[];
    final logger = AppLogger(
      tag: 'TestAuth',
      sinks: [entries.add],
    );

    logger.info('Login attempt', {
      'username': 'admin',
      'password': 'SuperSecretPassword123!',
      'pin': '1234',
    });

    expect(entries.length, 1);
    final meta = entries[0].metadata!;
    expect(meta['username'], 'admin');
    expect(meta['password'], '[REDACTED]');
    expect(meta['pin'], '[REDACTED]');
  });

  test('AppLogger redacts Cloudflare API tokens', () {
    final entries = <LogEntry>[];
    final logger = AppLogger(
      tag: 'Cloudflare',
      sinks: [entries.add],
    );

    logger.info('Using token cfut_MOCKDUMMYTOKENFORTESTINGONLY0123456789');
    expect(entries.length, 1);
    assertTrue(!entries[0].message.contains('cfut_MOCKDUMMYTOKENFORTESTINGONLY0123456789'));
    assertTrue(entries[0].message.contains('[REDACTED]'));
  });

  test('Structured audit log records actor and details', () {
    final entries = <LogEntry>[];
    final logger = AppLogger(
      tag: 'Audit',
      sinks: [entries.add],
    );

    logger.audit('DEVICE_REVOKED', actorId: 'usr_admin_01', details: {
      'deviceId': 'dev_pos_counter_02',
      'reason': 'Lost hardware device',
    });

    expect(entries.length, 1);
    expect(entries[0].level, LogLevel.audit);
    expect(entries[0].metadata!['actorId'], 'usr_admin_01');
    expect(entries[0].metadata!['action'], 'DEVICE_REVOKED');
  });

  test('Log level filtering suppresses lower level logs', () {
    final entries = <LogEntry>[];
    final logger = AppLogger(
      tag: 'FilterTest',
      minLevel: LogLevel.warn,
      sinks: [entries.add],
    );

    logger.debug('Debug message');
    logger.info('Info message');
    logger.warn('Warning message');
    logger.error('Error message');

    expect(entries.length, 2);
    expect(entries[0].level, LogLevel.warn);
    expect(entries[1].level, LogLevel.error);
  });

  // ignore: avoid_print
  print('\nLogger tests summary: $passed passed, $failed failed.');
  if (failed > 0) {
    exit(1);
  }
}
