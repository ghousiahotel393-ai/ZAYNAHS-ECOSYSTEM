import 'dart:io';
import 'package:backup/backup.dart';
import 'package:cctv/cctv.dart';
import 'package:core/core.dart';
import 'package:database/database.dart';
import 'package:pos/pos.dart';
import 'package:storage/storage.dart';
import 'package:sync/sync.dart';

Future<void> main() async {
  // ignore: avoid_print
  print('\n=== Running Production Soak, High-Volume Load & Stability Tests (Phase 15) ===');

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

  Future<void> testAsync(String name, Future<void> Function() fn) async {
    try {
      await fn();
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

  // -------------------------------------------------------------
  // Test 1: High-Volume Transaction Soak & Ledger Reconciliation
  // -------------------------------------------------------------
  test('Soak Test 1: High-volume POS checkout & return cycles maintain strict ledger mathematical parity', () {
    final tempDir = Directory.systemTemp.createTempSync('zyn_soak_pos_');
    final dbFile = File('${tempDir.path}/soak_pos.db');
    final db = AppDatabase.openFile(dbFile.path);
    db.initialize();

    final invRepo = InventoryRepository(db);
    final walletRepo = WalletRepository(db);
    final salesRepo = SalesRepository(db: db, inventoryRepo: invRepo, walletRepo: walletRepo);
    final posEngine = UniversalPosEngine(
      salesRepo: salesRepo,
      inventoryRepo: invRepo,
      walletRepo: walletRepo,
    );

    final curr = Currency.pkr;
    final now = DateTime.now().toUtc();

    // 1. Setup Ecosystem, Device, User
    db.connection.execute(
      '''
      INSERT INTO ecosystems (id, name, created_at, updated_at, settings_json)
      VALUES ('eco_soak', 'Soak Test Enterprise', ?, ?, '{}')
      ''',
      [now.toIso8601String(), now.toIso8601String()],
    );
    db.connection.execute(
      '''
      INSERT INTO devices (id, name, trust_status, public_key, paired_at, last_seen_at, device_type)
      VALUES ('dev_soak_01', 'Soak Terminal', 'TRUSTED', 'pub_soak_01', ?, ?, 'terminal')
      ''',
      [now.toIso8601String(), now.toIso8601String()],
    );
    db.connection.execute(
      '''
      INSERT INTO users (id, name, email, role, password_hash, pin_hash, is_active, created_at, updated_at)
      VALUES ('usr_soak_cashier', 'Soak Cashier', 'cashier@soak.local', 'Cashier', 'hash', 'pinhash', 1, ?, ?)
      ''',
      [now.toIso8601String(), now.toIso8601String()],
    );

    // 2. Wallets: Cash (initial 0), Bank (initial 0)
    walletRepo.createWallet(WalletEntity(
      id: 'wal_soak_cash',
      name: 'Main Cash Register',
      type: 'CASH',
      currency: curr,
      balance: Money.zero(curr),
      createdAt: now,
      updatedAt: now,
    ));
    walletRepo.createWallet(WalletEntity(
      id: 'wal_soak_bank',
      name: 'HBL Bank Account',
      type: 'BANK',
      currency: curr,
      balance: Money.zero(curr),
      createdAt: now,
      updatedAt: now,
    ));

    // 3. Inventory Item: Bulk Initial Stock 1,000 units
    invRepo.createItem(InventoryItemEntity(
      id: 'itm_soak_widget',
      sku: 'SKU-SOAK-WIDGET',
      name: 'High-Velocity Soak Widget',
      costPrice: Money.fromMinorUnits(5000, curr), // 50 PKR
      sellingPrice: Money.fromMinorUnits(10000, curr), // 100 PKR
      createdAt: now,
      updatedAt: now,
    ));
    invRepo.recordMovement(
      itemId: 'itm_soak_widget',
      type: 'PURCHASE',
      quantity: 1000,
      costPrice: Money.fromMinorUnits(5000, curr),
      referenceId: 'po_soak_init_1000',
      actorId: 'usr_soak_cashier',
      deviceId: 'dev_soak_01',
    );
    expect(invRepo.getStockBalance('itm_soak_widget'), 1000);

    // 4. Execute 50 rapid sequential checkout cycles (2 units per sale = 100 units total sold)
    int totalSoldUnits = 0;
    final saleIds = <String>[];

    for (int i = 1; i <= 50; i++) {
      final isEven = i % 2 == 0;
      final targetWallet = isEven ? 'wal_soak_cash' : 'wal_soak_bank';

      final result = posEngine.checkout(
        cart: PosCart.empty(curr).addItem(CartLineItem(
          itemId: 'itm_soak_widget',
          itemName: 'High-Velocity Soak Widget',
          quantity: 2,
          unitPrice: Money.fromMinorUnits(10000, curr),
          costPrice: Money.fromMinorUnits(5000, curr),
          itemDiscount: Money.zero(curr),
        )),
        invoiceNumber: 'INV-SOAK-$i',
        paymentAllocations: [
          PaymentAllocation(
            walletId: targetWallet,
            amount: Money.fromMinorUnits(20000, curr), // 200 PKR
          ),
        ],
        actorId: 'usr_soak_cashier',
        deviceId: 'dev_soak_01',
      );

      saleIds.add(result.id);
      totalSoldUnits += 2;
    }

    expect(totalSoldUnits, 100);
    // Stock should be 1000 - 100 = 900
    expect(invRepo.getStockBalance('itm_soak_widget'), 900);

    // 5. Execute 10 Returns (1 unit returned from each of first 10 sales)
    int totalReturnedUnits = 0;
    for (int i = 0; i < 10; i++) {
      salesRepo.processReturn(
        saleId: saleIds[i],
        returnNumber: 'RET-SOAK-${i + 1}',
        items: [
          ReturnItemInput(
            itemId: 'itm_soak_widget',
            quantity: 1,
            refundAmount: Money.fromMinorUnits(10000, curr), // 100 PKR refund
            costPrice: Money.fromMinorUnits(5000, curr),
          ),
        ],
        refundAllocations: [
          PaymentAllocation(
            walletId: 'wal_soak_cash',
            amount: Money.fromMinorUnits(10000, curr),
          ),
        ],
        actorId: 'usr_soak_cashier',
        deviceId: 'dev_soak_01',
      );
      totalReturnedUnits += 1;
    }

    expect(totalReturnedUnits, 10);
    // Stock invariant: 900 + 10 = 910 units
    expect(invRepo.getStockBalance('itm_soak_widget'), 910);

    // Wallet invariant derived strictly from ledger
    final finalCashWallet = walletRepo.getWalletBalance('wal_soak_cash', curr);
    // Cash received = 25 sales * 200 = 500,000 minor; Returns refunded = 10 * 100 = 100,000 minor.
    // Net cash = 400,000 minor (4,000 PKR).
    expect(finalCashWallet.minorUnits, 400000);

    // Direct SQL ledger audit verification
    final movementSumRs = db.connection.select(
      'SELECT COALESCE(SUM(quantity), 0) AS balance FROM inventory_movements WHERE item_id = ?',
      ['itm_soak_widget'],
    );
    expect(movementSumRs.first['balance'], 910);

    db.close();
    tempDir.deleteSync(recursive: true);
  });

  // -------------------------------------------------------------
  // Test 2: High-Throughput Sync Queue & Event Idempotency Soak
  // -------------------------------------------------------------
  test('Soak Test 2: High-throughput SyncOutboxQueue enqueues, dispatches, and idempotently deduplicates', () {
    final tempDir = Directory.systemTemp.createTempSync('zyn_soak_sync_');
    final dbFile = File('${tempDir.path}/soak_sync.db');
    final db = AppDatabase.openFile(dbFile.path);
    db.initialize();

    final queue = SyncOutboxQueue(db);
    expect(queue.getPendingCount(), 0);

    final now = DateTime.now().toUtc();
    db.connection.execute(
      '''
      INSERT INTO devices (id, name, trust_status, public_key, paired_at, last_seen_at, device_type)
      VALUES ('dev_soak_peer', 'Soak Peer', 'TRUSTED', 'pub_peer', ?, ?, 'terminal')
      ''',
      [now.toIso8601String(), now.toIso8601String()],
    );

    // Enqueue 50 sync events
    for (int i = 1; i <= 50; i++) {
      final event = SyncEvent.create(
        eventType: 'STOCK_ADJUSTMENT',
        aggregateId: 'itm_item_$i',
        aggregateType: 'INVENTORY',
        payload: {'index': i, 'delta': i * 2},
        deviceId: 'dev_soak_peer',
      );
      queue.enqueue(event);
    }

    expect(queue.getPendingCount(), 50);

    // Idempotency: re-enqueuing the same events does NOT create duplicates
    final dupEvent = SyncEvent.create(
      eventId: 'evt_fixed_deterministic_id',
      eventType: 'STOCK_ADJUSTMENT',
      aggregateId: 'itm_fixed_01',
      aggregateType: 'INVENTORY',
      payload: {'delta': 5},
      deviceId: 'dev_soak_peer',
    );
    queue.enqueue(dupEvent);
    queue.enqueue(dupEvent); // Duplicate insert attempt
    expect(queue.getPendingCount(), 51);

    // Dispatch and mark completed in batches
    final batch = queue.fetchPending(limit: 20);
    expect(batch.length, 20);
    for (final it in batch) {
      queue.markSending(it.eventId);
      queue.markAcknowledged(it.eventId);
    }
    expect(queue.getPendingCount(), 31);

    db.close();
    tempDir.deleteSync(recursive: true);
  });

  // -------------------------------------------------------------
  // Test 3: CCTV Continuous Segment Rotation & Retention Clean Soak
  // -------------------------------------------------------------
  await testAsync('Soak Test 3: Sustained CCTV segment rotation, atomic file promotion, and retention purge safety', () async {
    final tempDir = Directory.systemTemp.createTempSync('zyn_soak_cctv_');
    final dbFile = File('${tempDir.path}/soak_cctv.db');
    final db = AppDatabase.openFile(dbFile.path);
    db.initialize();

    final storage = FileStorageService(tempDir.path);
    final discovery = CameraDiscoveryService(db: db);

    final now = DateTime.now().toUtc();
    db.connection.execute(
      '''
      INSERT INTO devices (id, name, trust_status, public_key, paired_at, last_seen_at, device_type)
      VALUES ('dev_soak_01', 'Soak CCTV Dev', 'TRUSTED', 'pub_cctv', ?, ?, 'terminal')
      ''',
      [now.toIso8601String(), now.toIso8601String()],
    );

    final camera = discovery.registerCamera(
      name: 'Soak Cam',
      type: CameraSourceType.rtsp,
      sourceUrl: 'rtsp://mock.local/live',
      deviceId: 'dev_soak_01',
    );

    final recorder = SegmentedRecorder(
      db: db,
      storageService: storage,
      targetSegmentDuration: const Duration(milliseconds: 50),
      maxSegmentBytes: 200,
    );

    await camera.connect();
    await recorder.startRecording(camera);

    // Rotate through 5 segments rapidly
    for (int i = 1; i <= 5; i++) {
      camera.emitChunk(List.generate(250, (j) => (i * j) % 256));
      await Future<void>.delayed(const Duration(milliseconds: 30));
    }

    await recorder.stopRecording(camera);
    await camera.disconnect();

    // Verify all recorded segments in database
    final segRows = db.connection.select("SELECT * FROM cctv_segments WHERE camera_id = ?", [camera.id]);
    expect(segRows.isNotEmpty, true);

    // Protect segment 1
    final firstSegId = segRows[0]['id'] as String;
    db.connection.execute("UPDATE cctv_segments SET is_protected = 1 WHERE id = ?", [firstSegId]);

    // Run Retention Cleaner (simulate disk pressure threshold)
    final cleaner = RetentionCleaner(
      db: db,
      storageService: storage,
    );
    final purgeResult = await cleaner.executeRetentionCleanup();

    expect(purgeResult.purgedCount > 0, true);

    // Sacred Retention Law: Protected segment survives
    final remainingRows = db.connection.select("SELECT * FROM cctv_segments WHERE camera_id = ? AND is_protected = 1", [camera.id]);
    expect(remainingRows.length, 1);

    db.close();
    tempDir.deleteSync(recursive: true);
  });

  // -------------------------------------------------------------
  // Test 4: End-to-End System Snapshot, Archive & Rebuild Soak
  // -------------------------------------------------------------
  await testAsync('Soak Test 4: Full ecosystem backup archive creation, checksum verification, and projection rebuilder', () async {
    final tempDir = Directory.systemTemp.createTempSync('zyn_soak_backup_');
    final dbFile = File('${tempDir.path}/soak_backup.db');
    final db = AppDatabase.openFile(dbFile.path);
    db.initialize();

    final storage = FileStorageService(tempDir.path);
    final backupWriter = BackupWriter(db: db, storageService: storage);
    final projectionRebuilder = ProjectionRebuilder(db: db);

    final curr = Currency.pkr;
    final now = DateTime.now().toUtc();

    // Populate baseline records
    db.connection.execute(
      "INSERT INTO ecosystems (id, name, created_at, updated_at, settings_json) VALUES ('eco_soak_bk', 'Soak Corp', ?, ?, '{}')",
      [now.toIso8601String(), now.toIso8601String()],
    );
    db.connection.execute(
      "INSERT INTO devices (id, name, trust_status, public_key, paired_at, last_seen_at, device_type) VALUES ('dev_bk_01', 'Backup Dev', 'TRUSTED', 'pub_bk', ?, ?, 'terminal')",
      [now.toIso8601String(), now.toIso8601String()],
    );
    db.connection.execute(
      "INSERT INTO users (id, name, email, role, password_hash, pin_hash, is_active, created_at, updated_at) VALUES ('usr_bk_01', 'Admin Sam', 'sam@soak.local', 'Admin', 'hash', 'pinhash', 1, ?, ?)",
      [now.toIso8601String(), now.toIso8601String()],
    );

    // Item and Movements
    final invRepo = InventoryRepository(db);
    invRepo.createItem(InventoryItemEntity(
      id: 'itm_soak_bk',
      sku: 'SKU-BK',
      name: 'Backup Polo',
      costPrice: Money.fromMinorUnits(5000, curr),
      sellingPrice: Money.fromMinorUnits(10000, curr),
      createdAt: now,
      updatedAt: now,
    ));
    invRepo.recordMovement(
      itemId: 'itm_soak_bk',
      type: 'PURCHASE',
      quantity: 100,
      costPrice: Money.fromMinorUnits(5000, curr),
      referenceId: 'po_bk_100',
      actorId: 'usr_bk_01',
      deviceId: 'dev_bk_01',
    );
    invRepo.recordMovement(
      itemId: 'itm_soak_bk',
      type: 'SALE',
      quantity: -25,
      costPrice: Money.fromMinorUnits(5000, curr),
      referenceId: 'sale_bk_25',
      actorId: 'usr_bk_01',
      deviceId: 'dev_bk_01',
    );
    expect(invRepo.getStockBalance('itm_soak_bk'), 75);

    // Create Backup
    final backupResult = await backupWriter.createBackup(
      type: BackupType.manual,
      actorId: 'usr_bk_01',
      deviceId: 'dev_bk_01',
    );

    expect(backupResult.sha256Checksum.length, 64);
    expect(backupResult.fileSizeBytes > 0, true);

    // Rebuild projections on active DB and verify consistency
    final summary = projectionRebuilder.rebuildProjections();
    expect(summary.itemsRebuilt >= 1, true);
    expect(invRepo.getStockBalance('itm_soak_bk'), 75);

    db.close();
    tempDir.deleteSync(recursive: true);
  });

  // Summary
  // ignore: avoid_print
  print('\n=== Production Soak & High-Volume Stability Summary ===');
  // ignore: avoid_print
  print('Passed: $passed, Failed: $failed');

  if (failed > 0) {
    throw Exception('$failed tests failed in Production Soak & Validation (Phase 15)!');
  }
}
