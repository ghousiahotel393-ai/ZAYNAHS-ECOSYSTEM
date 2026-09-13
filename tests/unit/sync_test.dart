import 'dart:convert';
import 'dart:io';
import 'package:database/database.dart';
import 'package:sync/sync.dart';

Future<void> main() async {
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

  Future<void> testAsync(String name, Future<void> Function() body) async {
    try {
      await body();
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
  print('\n=== Running Event & Sync Foundation Tests ===');

  AppDatabase createSeededDb(String name) {
    final db = AppDatabase.openInMemory();
    db.initialize();

    db.connection.execute(
      "INSERT INTO ecosystems (id, name, created_at, updated_at) VALUES ('eco_main', 'Zaynahs Flagship', '2026-09-12T00:00:00Z', '2026-09-12T00:00:00Z');",
    );
    db.connection.execute(
      "INSERT INTO devices (id, name, trust_status, public_key, last_seen_at) VALUES ('dev_a', 'Terminal A', 'TRUSTED', 'pk_a', '2026-09-12T00:00:00Z');",
    );
    db.connection.execute(
      "INSERT INTO devices (id, name, trust_status, public_key, last_seen_at) VALUES ('dev_b', 'Terminal B', 'TRUSTED', 'pk_b', '2026-09-12T00:00:00Z');",
    );
    db.connection.execute(
      "INSERT INTO users (id, name, email, role, password_hash, pin_hash, created_at, updated_at) VALUES ('usr_cashier', 'Cashier', 'cashier@zaynahs.local', 'Cashier', 'h', 'p', '2026-09-12T00:00:00Z', '2026-09-12T00:00:00Z');",
    );
    db.connection.execute(
      "INSERT INTO inventory_items (id, sku, name, cost_price_minor, selling_price_minor, created_at, updated_at) VALUES ('itm_coffee', 'SKU-COF-01', 'Espresso Blend', 500, 1000, '2026-09-12T00:00:00Z', '2026-09-12T00:00:00Z');",
    );
    db.connection.execute(
      "INSERT INTO wallets (id, name, type, currency, is_active, created_at, updated_at) VALUES ('wal_cash', 'Cash Drawer', 'CASH', 'PKR', 1, '2026-09-12T00:00:00Z', '2026-09-12T00:00:00Z');",
    );

    return db;
  }

  // 1. SyncEvent Hashing and Integrity
  test('SyncEvent computes deterministic SHA-256 hash and verifies payload integrity', () {
    final event = SyncEvent.create(
      eventId: 'evt_test_01',
      eventType: 'INVENTORY_MOVEMENT',
      aggregateId: 'mov_1',
      aggregateType: 'inventory_movements',
      deviceId: 'dev_a',
      userId: 'usr_cashier',
      createdAt: '2026-09-12T12:00:00.000Z',
      payload: {
        'item_id': 'itm_coffee',
        'quantity': -20,
        'type': 'SALE',
        'cost_price_minor': 500,
      },
    );

    assertTrue(event.hash.isNotEmpty);
    assertTrue(event.verifyIntegrity());

    // Tampered event detection
    final tamperedEvent = SyncEvent(
      eventId: event.eventId,
      eventType: event.eventType,
      aggregateId: event.aggregateId,
      aggregateType: event.aggregateType,
      deviceId: event.deviceId,
      userId: event.userId,
      createdAt: event.createdAt,
      logicalVersion: event.logicalVersion,
      payload: {
        'item_id': 'itm_coffee',
        'quantity': -100, // Tampered from -20 to -100
        'type': 'SALE',
        'cost_price_minor': 500,
      },
      hash: event.hash,
    );

    assertTrue(!tamperedEvent.verifyIntegrity(), 'Tampered payload must fail integrity check');
  });

  // 2. Durable Outbox Queue Lifecycle
  test('SyncOutboxQueue enqueues, dispatches, and tracks retry states durably', () {
    final db = createSeededDb('outbox_test');
    final outbox = SyncOutboxQueue(db);

    final event1 = SyncEvent.create(
      eventId: 'evt_outbox_1',
      eventType: 'SALE_CREATED',
      aggregateId: 'sal_1',
      aggregateType: 'sales',
      deviceId: 'dev_a',
      userId: 'usr_cashier',
      payload: {'net_minor': 2000},
    );
    final event2 = SyncEvent.create(
      eventId: 'evt_outbox_2',
      eventType: 'SALE_CREATED',
      aggregateId: 'sal_2',
      aggregateType: 'sales',
      deviceId: 'dev_a',
      userId: 'usr_cashier',
      payload: {'net_minor': 3500},
    );

    outbox.enqueue(event1);
    outbox.enqueue(event2);

    expect(outbox.getPendingCount(), 2);

    // Fetch FIFO
    final pending = outbox.fetchPending(limit: 10);
    expect(pending.length, 2);
    expect(pending[0].eventId, 'evt_outbox_1');
    expect(pending[1].eventId, 'evt_outbox_2');

    // State transitions
    outbox.markSending('evt_outbox_1');
    outbox.markAcknowledged('evt_outbox_1');
    expect(outbox.getPendingCount(), 1);

    outbox.markFailed('evt_outbox_2', reason: 'Network unreachable');
    final failedRow = db.connection.select("SELECT status, retry_count FROM sync_outbox WHERE id = 'evt_outbox_2';");
    expect(failedRow.first['status'], 'FAILED');
    expect(failedRow.first['retry_count'], 1);

    db.close();
  });

  // 3. Sacred Sync Laws: Cursor progression & Idempotency
  await testAsync('SyncEngine enforces Sacred Sync Laws and idempotent deduplication', () async {
    final db = createSeededDb('laws_test');
    final engine = SyncEngine(db: db);

    // Initial stock setup = 100
    db.connection.execute(
      '''
      INSERT INTO inventory_movements (
        id, item_id, type, quantity, cost_price_minor, previous_balance, new_balance,
        reference_id, actor_id, device_id, created_at
      ) VALUES ('mov_init', 'itm_coffee', 'PURCHASE', 100, 500, 0, 100, 'ref_init', 'usr_cashier', 'dev_a', '2026-09-12T00:00:00Z');
      ''',
    );

    final event = SyncEvent.create(
      eventId: 'evt_sale_a1',
      eventType: 'INVENTORY_MOVEMENT',
      aggregateId: 'mov_sale_a1',
      aggregateType: 'inventory_movements',
      deviceId: 'dev_a',
      userId: 'usr_cashier',
      createdAt: '2026-09-12T10:00:00Z',
      payload: {
        'id': 'mov_sale_a1',
        'item_id': 'itm_coffee',
        'quantity': -20,
        'type': 'SALE',
        'cost_price_minor': 500,
      },
    );

    // Law 1 & 2: Cursor must be null before application
    expect(engine.cursors.getCursor('dev_a'), null);

    // Apply inbound event
    final result1 = await engine.applyInboundEvent(event);
    expect(result1.status, SyncApplyStatus.applied);

    // Verify cursor updated AFTER application
    final cursor = engine.cursors.getCursor('dev_a');
    assertTrue(cursor != null);
    expect(cursor!.lastAckedEventId, 'evt_sale_a1');

    // Balance after application = 80
    final rs1 = db.connection.select('SELECT SUM(quantity) as balance FROM inventory_movements WHERE item_id = ?;', ['itm_coffee']);
    expect(rs1.first['balance'], 80);

    // Law 3: Duplicate event must be recognized and handled idempotently without re-deducting stock
    final result2 = await engine.applyInboundEvent(event);
    expect(result2.status, SyncApplyStatus.duplicate);

    // Balance must remain strictly 80 (not 60)
    final rs2 = db.connection.select('SELECT SUM(quantity) as balance FROM inventory_movements WHERE item_id = ?;', ['itm_coffee']);
    expect(rs2.first['balance'], 80);

    db.close();
  });

  // 4. GOLDEN TEST #101: Multi-Device Offline Split Ledger Reconciliation
  await testAsync('Golden Test 101: Multi-Device Offline Split Ledger reconciles with zero LWW loss', () async {
    // Both devices start with identical shared state: Initial stock = 100
    final dbDeviceA = createSeededDb('golden_dev_a');
    final dbDeviceB = createSeededDb('golden_dev_b');

    for (final db in [dbDeviceA, dbDeviceB]) {
      db.connection.execute(
        '''
        INSERT INTO inventory_movements (
          id, item_id, type, quantity, cost_price_minor, previous_balance, new_balance,
          reference_id, actor_id, device_id, created_at
        ) VALUES ('mov_init', 'itm_coffee', 'PURCHASE', 100, 500, 0, 100, 'ref_init', 'usr_cashier', 'dev_a', '2026-09-12T00:00:00Z');
        ''',
      );
    }

    final engineA = SyncEngine(db: dbDeviceA);
    final engineB = SyncEngine(db: dbDeviceB);

    // Step 1: Device A goes offline and executes Sale A: -20 units
    final saleAEvent = SyncEvent.create(
      eventId: 'evt_dev_a_sale_20',
      eventType: 'INVENTORY_MOVEMENT',
      aggregateId: 'mov_sale_a',
      aggregateType: 'inventory_movements',
      deviceId: 'dev_a',
      userId: 'usr_cashier',
      createdAt: '2026-09-12T10:30:00Z',
      payload: {
        'id': 'mov_sale_a',
        'item_id': 'itm_coffee',
        'quantity': -20,
        'type': 'SALE',
        'cost_price_minor': 500,
      },
    );
    // Apply locally on Device A
    final resA = await engineA.applyInboundEvent(saleAEvent);
    expect(resA.status, SyncApplyStatus.applied);
    final stockA = dbDeviceA.connection.select('SELECT SUM(quantity) as b FROM inventory_movements WHERE item_id = ?;', ['itm_coffee']);
    expect(stockA.first['b'], 80); // 100 - 20 = 80

    // Step 2: Device B goes offline independently and executes Sale B: -30 units
    final saleBEvent = SyncEvent.create(
      eventId: 'evt_dev_b_sale_30',
      eventType: 'INVENTORY_MOVEMENT',
      aggregateId: 'mov_sale_b',
      aggregateType: 'inventory_movements',
      deviceId: 'dev_b',
      userId: 'usr_cashier',
      createdAt: '2026-09-12T10:45:00Z',
      payload: {
        'id': 'mov_sale_b',
        'item_id': 'itm_coffee',
        'quantity': -30,
        'type': 'SALE',
        'cost_price_minor': 500,
      },
    );
    // Apply locally on Device B
    final resB = await engineB.applyInboundEvent(saleBEvent);
    expect(resB.status, SyncApplyStatus.applied);
    final stockB = dbDeviceB.connection.select('SELECT SUM(quantity) as b FROM inventory_movements WHERE item_id = ?;', ['itm_coffee']);
    expect(stockB.first['b'], 70); // 100 - 30 = 70

    // Step 3: Network reconnects — peer sync exchange
    // Device A receives Device B's event:
    final syncToA = await engineA.applyInboundEvent(saleBEvent);
    expect(syncToA.status, SyncApplyStatus.applied);

    // Device B receives Device A's event:
    final syncToB = await engineB.applyInboundEvent(saleAEvent);
    expect(syncToB.status, SyncApplyStatus.applied);

    // Step 4: Verify Holy Grail of Golden Test 101:
    // Final derived stock on Device A = 50 (100 - 20 - 30)
    final finalStockA = dbDeviceA.connection.select('SELECT SUM(quantity) as b FROM inventory_movements WHERE item_id = ?;', ['itm_coffee']);
    expect(finalStockA.first['b'], 50);

    // Final derived stock on Device B = 50 (100 - 20 - 30)
    final finalStockB = dbDeviceB.connection.select('SELECT SUM(quantity) as b FROM inventory_movements WHERE item_id = ?;', ['itm_coffee']);
    expect(finalStockB.first['b'], 50);

    // Both sales exist in both databases (Zero Last-Write-Wins overwrite!)
    final devASales = dbDeviceA.connection.select("SELECT id FROM inventory_movements WHERE type = 'SALE' ORDER BY id ASC;");
    expect(devASales.length, 2);
    expect(devASales[0]['id'], 'mov_sale_a');
    expect(devASales[1]['id'], 'mov_sale_b');

    final devBSales = dbDeviceB.connection.select("SELECT id FROM inventory_movements WHERE type = 'SALE' ORDER BY id ASC;");
    expect(devBSales.length, 2);
    expect(devBSales[0]['id'], 'mov_sale_a');
    expect(devBSales[1]['id'], 'mov_sale_b');

    dbDeviceA.close();
    dbDeviceB.close();
  });

  // 5. Conflict Logging for Non-Ledger Entity Updates
  test('SyncConflictResolver logs entity collisions in sync_conflicts without data loss', () {
    final db = createSeededDb('conflict_test');
    final resolver = SyncConflictResolver(db);

    expect(resolver.getUnresolvedConflicts().length, 0);

    // Seed local event in sync_outbox for foreign key
    db.connection.execute(
      '''
      INSERT INTO sync_outbox (id, event_type, entity_table, entity_id, payload_json, device_id, status, retry_count, created_at)
      VALUES ('evt_local_01', 'UPDATE', 'inventory_items', 'itm_coffee', '{}', 'dev_a', 'SENT', 0, '2026-09-12T00:00:00Z');
      ''',
    );

    resolver.recordConflict(
      entityTable: 'inventory_items',
      entityId: 'itm_coffee',
      localEventId: 'evt_local_01',
      remoteEventId: 'evt_remote_02',
      conflictType: 'CONCURRENT_PRICE_CHANGE',
      conflictData: {
        'local_retail_price_minor': 1100,
        'remote_retail_price_minor': 1200,
      },
    );

    final conflicts = resolver.getUnresolvedConflicts();
    expect(conflicts.length, 1);
    expect(conflicts.first.entityTable, 'inventory_items');
    expect(conflicts.first.conflictType, 'CONCURRENT_PRICE_CHANGE');
    expect(conflicts.first.status, 'UNRESOLVED');

    // Operator resolves conflict
    resolver.resolveConflict(conflicts.first.id, newStatus: 'RESOLVED');
    expect(resolver.getUnresolvedConflicts().length, 0);

    db.close();
  });

  // ignore: avoid_print
  print('\nSync tests summary: $passed passed, $failed failed.');
  if (failed > 0) {
    exit(1);
  }
}
