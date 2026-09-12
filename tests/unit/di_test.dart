import 'dart:io';
import 'package:core/core.dart';

class TestConfigService {
  final String appName;
  TestConfigService(this.appName);
}

class TestTransientWorker {
  final int id;
  TestTransientWorker(this.id);
}

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
  print('\n=== Running Dependency Injection & Service Locator Tests ===');

  test('Singleton registration and identity check', () {
    sl.reset();
    final config = TestConfigService('Zaynahs POS');
    sl.registerSingleton<TestConfigService>(config, tier: DiLifecycleTier.foundation);

    assertTrue(sl.isRegistered<TestConfigService>());
    final retrieved = sl.get<TestConfigService>();
    expect(identical(config, retrieved), true);
    expect(retrieved.appName, 'Zaynahs POS');
  });

  test('Lazy singleton defers instantiation until get()', () {
    sl.reset();
    int instantiations = 0;
    sl.registerLazySingleton<TestConfigService>(() {
      instantiations++;
      return TestConfigService('LazyPOS');
    });

    expect(instantiations, 0);
    final instance1 = sl.get<TestConfigService>();
    expect(instantiations, 1);
    final instance2 = sl.get<TestConfigService>();
    expect(instantiations, 1);
    expect(identical(instance1, instance2), true);
  });

  test('Factory registration returns fresh instances', () {
    sl.reset();
    int counter = 0;
    sl.registerFactory<TestTransientWorker>(() => TestTransientWorker(++counter));

    final w1 = sl.get<TestTransientWorker>();
    final w2 = sl.get<TestTransientWorker>();
    expect(w1.id, 1);
    expect(w2.id, 2);
    expect(identical(w1, w2), false);
  });

  test('Container reset clears all registered services', () {
    sl.reset();
    sl.registerSingleton<TestConfigService>(TestConfigService('To be cleared'));
    assertTrue(sl.isRegistered<TestConfigService>());

    sl.reset();
    assertTrue(!sl.isRegistered<TestConfigService>());
    expect(sl.tryGet<TestConfigService>(), null);
  });

  test('Platform Hardware Adapter registration via DI', () {
    sl.reset();
    final mockCamera = MockCameraAdapter();
    final mockPrinter = MockPrinterAdapter();

    sl.registerSingleton<CameraAdapter>(mockCamera, tier: DiLifecycleTier.adapters);
    sl.registerSingleton<PrinterAdapter>(mockPrinter, tier: DiLifecycleTier.adapters);

    final resolvedCamera = sl.get<CameraAdapter>();
    final resolvedPrinter = sl.get<PrinterAdapter>();

    assertTrue(resolvedCamera is MockCameraAdapter);
    assertTrue(resolvedPrinter is MockPrinterAdapter);
  });

  // ignore: avoid_print
  print('\nDI tests summary: $passed passed, $failed failed.');
  if (failed > 0) {
    exit(1);
  }
}
