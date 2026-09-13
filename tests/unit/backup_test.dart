import 'dart:io';
import 'package:backup/backup.dart';
import 'package:core/core.dart';
import 'package:crypto/crypto.dart';
import 'package:database/database.dart';
import 'package:pos/pos.dart';
import 'package:storage/storage.dart';

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
    if (actual is List && expected is List) {
      if (actual.length != expected.length) {
        throw AssertionError('Expected length: ${expected.length}, Actual length: ${actual.length}');
      }
      for (int i = 0; i < actual.length; i++) {
        if (actual[i] != expected[i]) {
          throw AssertionError('Mismatch at index $i: Expected ${expected[i]}, Actual ${actual[i]}');
        }
      }
      return;
    }
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
  print('\n=== Running Backup, Disaster Recovery & Golden Test 102 Tests ===');

  AppDatabase createDb() {
    final db = AppDatabase.openInMemory();
    db.initialize();
    return db;
  }

  Directory createTempStorageDir() {
    return Directory.systemTemp.createTempSync('zaynahs_backup_test_');
  }

  void seedEcosystem(AppDatabase db, {String actorId = 'usr_owner_01', String deviceId = 'dev_counter_01'}) {
    db.connection.execute(
      "INSERT INTO ecosystems (id, name, created_at, updated_at) VALUES ('eco_flagship', 'Zaynahs Flagship', '2026-09-12T00:00:00Z', '2026-09-12T00:00:00Z');",
    );
    db.connection.execute(
      "INSERT INTO devices (id, name, trust_status, public_key, last_seen_at) VALUES (?, 'POS Terminal 1', 'TRUSTED', 'pk_terminal', '2026-09-12T00:00:00Z');",
      [deviceId],
    );
    db.connection.execute(
      "INSERT INTO users (id, name, email, role, password_hash, pin_hash, created_at, updated_at) VALUES (?, 'Store Admin', 'admin@zaynahs.local', 'Admin', 'pwd_hash', 'pin_hash', '2026-09-12T00:00:00Z', '2026-09-12T00:00:00Z');",
      [actorId],
    );
  }

  // -------------------------------------------------------------
  // 1. .ZYNB Archive Packing, Integrity & Unpacking Tests
  // -------------------------------------------------------------
  test('.ZYNB Archive packing compresses payload and enforces cryptographic checksum verification', () {
    final manifest = ZynbManifest(
      ecosystemId: 'eco_flagship',
      backupType: BackupType.manual,
      createdAt: DateTime.parse('2026-09-12T12:00:00Z'),
      tableRecordCounts: {'users': 2, 'wallets': 1},
    );

    final tables = {
      'users': [
        {'id': 'usr_01', 'name': 'Alice', 'role': 'Admin'},
        {'id': 'usr_02', 'name': 'Bob', 'role': 'Cashier'},
      ],
      'wallets': [
        {'id': 'wal_01', 'name': 'Cash Box', 'type': 'CASH'},
      ],
    };

    final packedBytes = ZynbArchive.pack(
      manifest: manifest,
      databaseTables: tables,
    );

    assertTrue(packedBytes.isNotEmpty);

    // Unpack valid archive
    final unpacked = ZynbArchive.unpack(packedBytes);
    expect(unpacked.manifest.ecosystemId, 'eco_flagship');
    expect(unpacked.manifest.tableRecordCounts['users'], 2);
    expect(unpacked.databaseTables['users']!.length, 2);
    expect(unpacked.databaseTables['users']![0]['name'], 'Alice');

    // Corrupt 1 byte in the archive body
    final corruptedBytes = List<int>.from(packedBytes);
    corruptedBytes[20] ^= 0xFF; // Invert a byte in header/manifest

    bool caught = false;
    try {
      ZynbArchive.unpack(corruptedBytes);
    } catch (_) {
      caught = true;
    }
    assertTrue(caught, 'Corrupted .zynb archive must fail unpack validation');
  });

  // -------------------------------------------------------------
  // 2. MASTER GOLDEN TEST #102 (Rule 102)
  // -------------------------------------------------------------
  await testAsync('Golden Test 102: Complete dataset backup, checksum verification, 1-byte corrupt restore rejection, and safe restore with pre-restore snapshot', () async {
    // =========================================================================
    // GOLDEN TEST 102 SCENARIO SPECIFICATION (Rule 102):
    // 1. Create complete dataset:
    //    - Product
    //    - Inventory movement (Stock IN)
    //    - Customer
    //    - Sale (POS checkout)
    //    - Return
    //    - Wallet
    // 2. Create .zynb backup.
    // 3. Verify checksum.
    // 4. Corrupt 1 byte of archive.
    // 5. Restore attempt on corrupt archive fails with verification failure.
    // 6. Verify current database remains untouched.
    // 7. Execute valid restore:
    //    - Pre-restore snapshot created
    //    - Database restored
    //    - Projections rebuilt
    // =========================================================================

    final db = createDb();
    seedEcosystem(db);
    final tempDir = createTempStorageDir();
    final storageService = FileStorageService(tempDir.path);

    final invRepo = InventoryRepository(db);
    final walletRepo = WalletRepository(db);
    final salesRepo = SalesRepository(db: db, inventoryRepo: invRepo, walletRepo: walletRepo);
    final posEngine = UniversalPosEngine(salesRepo: salesRepo, inventoryRepo: invRepo, walletRepo: walletRepo);

    final now = DateTime.now().toUtc();
    const curr = Currency.pkr;

    // 1. CREATE COMPLETE DATASET
    // A. Wallet: Main Cash Drawer (initial 0)
    walletRepo.createWallet(WalletEntity(
      id: 'wal_golden_cash',
      name: 'Main Cash Drawer',
      type: 'CASH',
      currency: curr,
      balance: Money.zero(curr),
      createdAt: now,
      updatedAt: now,
    ));

    // B. Product: Premium Polo (Cost 50 PKR, Selling 100 PKR)
    invRepo.createItem(InventoryItemEntity(
      id: 'itm_golden_polo',
      sku: 'SKU-GOLDEN-POLO',
      name: 'Golden Polo Shirt',
      costPrice: Money.fromMinorUnits(5000, curr),
      sellingPrice: Money.fromMinorUnits(10000, curr),
      createdAt: now,
      updatedAt: now,
    ));

    // C. Inventory Movement: Stock IN (50 units)
    invRepo.recordMovement(
      itemId: 'itm_golden_polo',
      type: 'PURCHASE',
      quantity: 50,
      costPrice: Money.fromMinorUnits(5000, curr),
      referenceId: 'po_initial_50',
      actorId: 'usr_owner_01',
      deviceId: 'dev_counter_01',
    );
    expect(invRepo.getStockBalance('itm_golden_polo'), 50);

    // D. Customer: VIP Client
    db.connection.execute(
      '''
      INSERT INTO customers (id, name, phone, email, balance_minor, created_at, updated_at)
      VALUES ('cust_golden_vip', 'Hamza Khan', '+923001234567', 'hamza@vip.local', 0, ?, ?)
      ''',
      [now.toIso8601String(), now.toIso8601String()],
    );

    // E. Sale: Sell 10 units for 1000 PKR (Paid 1000 PKR via Cash Wallet)
    final saleResult = posEngine.checkout(
      cart: PosCart.empty(curr).addItem(CartLineItem(
        itemId: 'itm_golden_polo',
        itemName: 'Golden Polo Shirt',
        quantity: 10,
        unitPrice: Money.fromMinorUnits(10000, curr),
        costPrice: Money.fromMinorUnits(5000, curr),
        itemDiscount: Money.zero(curr),
      )),
      invoiceNumber: 'INV-GOLDEN-102',
      customerId: 'cust_golden_vip',
      paymentAllocations: [
        PaymentAllocation(walletId: 'wal_golden_cash', amount: Money.fromMinorUnits(100000, curr)),
      ],
      actorId: 'usr_owner_01',
      deviceId: 'dev_counter_01',
    );

    expect(saleResult.grandTotal.minorUnits, 100000); // 1000 PKR
    expect(invRepo.getStockBalance('itm_golden_polo'), 40); // 50 - 10 = 40
    expect(walletRepo.getWalletBalance('wal_golden_cash', curr).minorUnits, 100000);

    // F. Return: Return 2 units (Refund 200 PKR from Cash Wallet)
    final returnResult = salesRepo.processReturn(
      saleId: saleResult.id,
      returnNumber: 'RET-GOLDEN-001',
      items: [
        ReturnItemInput(
          itemId: 'itm_golden_polo',
          quantity: 2,
          refundAmount: Money.fromMinorUnits(20000, curr),
          costPrice: Money.fromMinorUnits(5000, curr),
        ),
      ],
      refundAllocations: [
        PaymentAllocation(walletId: 'wal_golden_cash', amount: Money.fromMinorUnits(20000, curr)),
      ],
      actorId: 'usr_owner_01',
      deviceId: 'dev_counter_01',
    );

    expect(returnResult.totalRefund.minorUnits, 20000);
    // Verified pre-backup balances:
    // Stock = 40 + 2 = 42
    // Cash Wallet = 1000 - 200 = 800 PKR (80000 minor)
    expect(invRepo.getStockBalance('itm_golden_polo'), 42);
    expect(walletRepo.getWalletBalance('wal_golden_cash', curr).minorUnits, 80000);

    // 2. CREATE .ZYNB BACKUP
    final backupWriter = BackupWriter(db: db, storageService: storageService);
    final projectionRebuilder = ProjectionRebuilder(db: db);
    final restoreManager = RestoreManager(
      db: db,
      storageService: storageService,
      backupWriter: backupWriter,
      projectionRebuilder: projectionRebuilder,
    );

    final backupRecord = await backupWriter.createBackup(
      type: BackupType.daily,
      actorId: 'usr_owner_01',
      deviceId: 'dev_counter_01',
    );

    expect(backupRecord.status, 'COMPLETED');
    assertTrue(backupRecord.fileSizeBytes > 0);

    // 3. VERIFY CHECKSUM
    final originalArchiveBytes = await storageService.readBytes(StorageCategory.backupsDaily, backupRecord.filePath.split('/').last);
    final actualChecksum = sha256.convert(originalArchiveBytes).toString();
    expect(actualChecksum, backupRecord.sha256Checksum);

    // 4. CORRUPT EXACTLY 1 BYTE OF THE ARCHIVE
    final corruptedArchiveBytes = List<int>.from(originalArchiveBytes);
    // Invert a single byte at byte offset 45
    corruptedArchiveBytes[45] ^= 0x55;

    // 5. RESTORE ATTEMPT FAILS SAFELY WITH VERIFICATION FAILURE
    bool restoreFailed = false;
    try {
      await restoreManager.restoreFromArchive(
        archiveBytes: corruptedArchiveBytes,
        actorId: 'usr_owner_01',
        deviceId: 'dev_counter_01',
      );
    } on ValidationException catch (e) {
      restoreFailed = true;
      assertTrue(e.message.contains('Cryptographic integrity failure'));
    }
    assertTrue(restoreFailed, 'Restore on corrupted archive must throw ValidationException');

    // 6. VERIFY CURRENT DATABASE REMAINS 100% UNTOUCHED
    expect(invRepo.getStockBalance('itm_golden_polo'), 42);
    expect(walletRepo.getWalletBalance('wal_golden_cash', curr).minorUnits, 80000);
    final customerRow = db.connection.select('SELECT name FROM customers WHERE id = ?', ['cust_golden_vip']);
    expect(customerRow.first['name'], 'Hamza Khan');

    // 7. EXECUTE VALID RESTORE FROM ORIGINAL UNCORRUPTED BACKUP
    // First, modify current DB to simulate subsequent state change (e.g. add dummy item)
    invRepo.createItem(InventoryItemEntity(
      id: 'itm_subsequent_mod',
      sku: 'SKU-SUBSEQUENT',
      name: 'Subsequent Item That Should Be Replaced',
      costPrice: Money.zero(curr),
      sellingPrice: Money.zero(curr),
      createdAt: now,
      updatedAt: now,
    ));
    expect(invRepo.getItemById('itm_subsequent_mod') != null, true);

    // Restore from valid backup
    final restoreResult = await restoreManager.restoreFromArchive(
      archiveBytes: originalArchiveBytes,
      actorId: 'usr_owner_01',
      deviceId: 'dev_counter_01',
    );

    // A. Verify Pre-Restore Snapshot was created (Rule 60, 81)
    expect(restoreResult.preRestoreBackup.backupType, BackupType.preRestore);
    final preRestoreDbRow = db.connection.select("SELECT * FROM backup_records WHERE backup_type = 'PRE_RESTORE'");
    expect(preRestoreDbRow.length, 1);

    // B. Verify Database was accurately restored (Subsequent modification is gone)
    expect(invRepo.getItemById('itm_subsequent_mod'), null);
    expect(invRepo.getItemById('itm_golden_polo') != null, true);

    // C. Verify Projections and Ledgers Rebuilt
    expect(invRepo.getStockBalance('itm_golden_polo'), 42);
    expect(walletRepo.getWalletBalance('wal_golden_cash', curr).minorUnits, 80000);

    // D. Verify Audit Log recorded restore event
    final auditRestore = db.connection.select("SELECT * FROM audit_logs WHERE action = 'DATABASE_RESTORE_COMPLETED'");
    expect(auditRestore.length, 1);

    db.close();
    tempDir.deleteSync(recursive: true);
  });

  // Summary
  // ignore: avoid_print
  print('\n=== Backup & Disaster Recovery Tests Summary ===');
  // ignore: avoid_print
  print('Passed: $passed, Failed: $failed');
  if (failed > 0) {
    throw Exception('$failed tests failed in Backup & Disaster Recovery (Phase 12)!');
  }
}
