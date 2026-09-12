import 'dart:io';
import 'package:core/core.dart';
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
  print('\n=== Running Local SQLite & Ledger Integrity Tests ===');

  AppDatabase createTestDb() {
    final db = AppDatabase.openInMemory();
    db.initialize();
    return db;
  }

  void seedPrerequisites(AppDatabase db, {String actorId = 'usr_test_01', String deviceId = 'dev_test_01'}) {
    // 1. Seed ecosystem
    db.connection.execute(
      "INSERT INTO ecosystems (id, name, created_at, updated_at) VALUES ('eco_main', 'Zaynahs Flagship', '2026-09-12T00:00:00Z', '2026-09-12T00:00:00Z');",
    );
    // 2. Seed device
    db.connection.execute(
      "INSERT INTO devices (id, name, trust_status, public_key, last_seen_at) VALUES (?, 'Test Device', 'TRUSTED', 'pk_123', '2026-09-12T00:00:00Z');",
      [deviceId],
    );
    // 3. Seed user
    db.connection.execute(
      "INSERT INTO users (id, name, email, role, password_hash, pin_hash, created_at, updated_at) VALUES (?, 'Admin User', 'admin@zaynahs.local', 'Admin', 'hash', 'pin', '2026-09-12T00:00:00Z', '2026-09-12T00:00:00Z');",
      [actorId],
    );
  }

  test('Database engine initializes schema v2 and sets user_version', () {
    final db = createTestDb();
    expect(db.getSchemaVersion(), 2);

    // Verify all 13 core tables exist
    final tables = [
      'ecosystems', 'devices', 'users', 'inventory_items', 'inventory_movements',
      'wallets', 'wallet_transactions', 'customers', 'sales', 'sale_items',
      'sync_outbox', 'sync_cursors', 'audit_logs', 'storage_files'
    ];

    for (final table in tables) {
      final rs = db.connection.select(
        "SELECT name FROM sqlite_master WHERE type='table' AND name = ?",
        [table],
      );
      expect(rs.length, 1);
    }
    db.close();
  });

  test('Schema migration from v1 to v2 preserves data and upgrades user_version', () {
    // 1. Manually create a v1 database
    final conn = DatabaseConnection.openInMemory();
    for (final sql in SchemaV1.ddlStatements) {
      conn.execute(sql);
    }
    conn.execute('PRAGMA user_version = 1;');
    conn.execute(
      "INSERT INTO ecosystems (id, name, created_at, updated_at) VALUES ('eco_v1', 'Ecosystem V1', '2026-09-12T00:00:00Z', '2026-09-12T00:00:00Z');",
    );

    // 2. Open with AppDatabase and trigger migration
    final db = AppDatabase(conn);
    expect(db.getSchemaVersion(), 1);
    db.initialize();

    // 3. Verify upgraded to version 2
    expect(db.getSchemaVersion(), 2);

    // 4. Verify existing v1 data preserved
    final ecoRs = db.connection.select("SELECT name FROM ecosystems WHERE id = 'eco_v1';");
    expect(ecoRs.first['name'], 'Ecosystem V1');

    // 5. Verify new v2 storage_files table exists and is writable
    final sfRs = db.connection.select("SELECT name FROM sqlite_master WHERE type='table' AND name = 'storage_files';");
    expect(sfRs.length, 1);

    db.close();
  });

  test('Strict foreign key enforcement rejects orphaned movements', () {
    final db = createTestDb();
    seedPrerequisites(db);

    bool threw = false;
    try {
      db.connection.execute(
        '''
        INSERT INTO inventory_movements (
          id, item_id, type, quantity, cost_price_minor,
          previous_balance, new_balance, reference_id,
          actor_id, device_id, created_at
        ) VALUES ('mov_orphan', 'itm_non_existent', 'PURCHASE', 10, 1000, 0, 10, 'ref_1', 'usr_test_01', 'dev_test_01', '2026-09-12T00:00:00Z')
        ''',
      );
    } catch (_) {
      threw = true;
    }
    assertTrue(threw, 'Expected foreign key constraint failure for non-existent item');
    db.close();
  });

  test('Immutable inventory movements strictly derive stock balance', () {
    final db = createTestDb();
    seedPrerequisites(db);
    final invRepo = InventoryRepository(db);

    const itemId = 'itm_cotton_shirt_01';
    final now = DateTime.now().toUtc();
    invRepo.createItem(InventoryItemEntity(
      id: itemId,
      sku: 'SKU-SHIRT-WHT-M',
      barcode: '896400012345',
      name: 'Cotton White Shirt M',
      costPrice: Money.fromMinorUnits(80000, Currency.pkr), // Rs 800.00
      sellingPrice: Money.fromMinorUnits(150000, Currency.pkr), // Rs 1,500.00
      createdAt: now,
      updatedAt: now,
    ));

    expect(invRepo.getStockBalance(itemId), 0);

    // 1. Initial Purchase +100 units
    invRepo.recordMovement(
      itemId: itemId,
      type: 'PURCHASE',
      quantity: 100,
      costPrice: Money.fromMinorUnits(80000, Currency.pkr),
      referenceId: 'po_batch_01',
      actorId: 'usr_test_01',
      deviceId: 'dev_test_01',
    );
    expect(invRepo.getStockBalance(itemId), 100);

    // 2. POS Sale -25 units
    invRepo.recordMovement(
      itemId: itemId,
      type: 'SALE',
      quantity: -25,
      costPrice: Money.fromMinorUnits(80000, Currency.pkr),
      referenceId: 'sale_001',
      actorId: 'usr_test_01',
      deviceId: 'dev_test_01',
    );
    expect(invRepo.getStockBalance(itemId), 75);

    // 3. Customer Return +5 units
    invRepo.recordMovement(
      itemId: itemId,
      type: 'RETURN',
      quantity: 5,
      costPrice: Money.fromMinorUnits(80000, Currency.pkr),
      referenceId: 'ret_001',
      actorId: 'usr_test_01',
      deviceId: 'dev_test_01',
    );
    expect(invRepo.getStockBalance(itemId), 80);

    db.close();
  });

  test('Multi-wallet accounts and atomic balance transfers', () {
    final db = createTestDb();
    seedPrerequisites(db);
    final walletRepo = WalletRepository(db);
    final now = DateTime.now().toUtc();

    const cashWalletId = 'wal_cash_drawer_1';
    const bankWalletId = 'wal_meezan_bank';

    walletRepo.createWallet(WalletEntity(
      id: cashWalletId,
      name: 'Counter Cash Drawer',
      type: 'CASH',
      currency: Currency.pkr,
      balance: Money.zero(Currency.pkr),
      createdAt: now,
      updatedAt: now,
    ));

    walletRepo.createWallet(WalletEntity(
      id: bankWalletId,
      name: 'Meezan Current Account',
      type: 'BANK',
      currency: Currency.pkr,
      balance: Money.zero(Currency.pkr),
      createdAt: now,
      updatedAt: now,
    ));

    // 1. Initial Cash Deposit Rs 50,000.00
    walletRepo.recordTransaction(
      walletId: cashWalletId,
      type: 'DEPOSIT',
      amount: Money.fromMinorUnits(5000000, Currency.pkr),
      referenceId: 'dep_opening_float',
      actorId: 'usr_test_01',
      deviceId: 'dev_test_01',
    );
    expect(walletRepo.getWalletBalance(cashWalletId).minorUnits, 5000000);
    expect(walletRepo.getWalletBalance(bankWalletId).minorUnits, 0);

    // 2. Atomic Transfer: Transfer Rs 20,000.00 from Cash Drawer to Bank
    walletRepo.transferBetweenWallets(
      fromWalletId: cashWalletId,
      toWalletId: bankWalletId,
      amount: Money.fromMinorUnits(2000000, Currency.pkr),
      actorId: 'usr_test_01',
      deviceId: 'dev_test_01',
      notes: 'Evening cash drop to bank',
    );

    // 3. Verify ledger balance conservation (Sum remains strictly 50,000.00)
    final cashBalance = walletRepo.getWalletBalance(cashWalletId);
    final bankBalance = walletRepo.getWalletBalance(bankWalletId);
    expect(cashBalance.minorUnits, 3000000); // Rs 30,000.00
    expect(bankBalance.minorUnits, 2000000); // Rs 20,000.00
    expect((cashBalance + bankBalance).minorUnits, 5000000);

    db.close();
  });

  test('Universal POS Checkout atomicity across all tables', () {
    final db = createTestDb();
    seedPrerequisites(db);
    final invRepo = InventoryRepository(db);
    final walletRepo = WalletRepository(db);
    final salesRepo = SalesRepository(
      db: db,
      inventoryRepo: invRepo,
      walletRepo: walletRepo,
    );

    final now = DateTime.now().toUtc();
    const itemId = 'itm_laptop_charger';
    invRepo.createItem(InventoryItemEntity(
      id: itemId,
      sku: 'SKU-CHG-65W',
      barcode: '789123456',
      name: 'USB-C 65W Fast Charger',
      costPrice: Money.fromMinorUnits(200000, Currency.pkr), // Rs 2,000.00
      sellingPrice: Money.fromMinorUnits(350000, Currency.pkr), // Rs 3,500.00
      createdAt: now,
      updatedAt: now,
    ));

    // Add initial stock 10 units
    invRepo.recordMovement(
      itemId: itemId,
      type: 'PURCHASE',
      quantity: 10,
      costPrice: Money.fromMinorUnits(200000, Currency.pkr),
      referenceId: 'po_01',
      actorId: 'usr_test_01',
      deviceId: 'dev_test_01',
    );

    const cashWalletId = 'wal_pos_counter';
    walletRepo.createWallet(WalletEntity(
      id: cashWalletId,
      name: 'POS Cash Register',
      type: 'CASH',
      currency: Currency.pkr,
      balance: Money.zero(Currency.pkr),
      createdAt: now,
      updatedAt: now,
    ));

    // Execute checkout: 2 units (2 * 3500 = 7000, discount 500, tax 0 = 6500 PKR)
    final sale = salesRepo.processSaleCheckout(
      invoiceNumber: 'INV-2026-0001',
      items: [
        SaleItemInput(
          itemId: itemId,
          itemName: 'USB-C 65W Fast Charger',
          quantity: 2,
          unitPrice: Money.fromMinorUnits(350000, Currency.pkr),
          costPrice: Money.fromMinorUnits(200000, Currency.pkr),
        ),
      ],
      discount: Money.fromMinorUnits(50000, Currency.pkr), // Rs 500.00 discount
      tax: Money.zero(Currency.pkr),
      paidAmount: Money.fromMinorUnits(650000, Currency.pkr), // Fully paid Rs 6,500.00
      walletId: cashWalletId,
      actorId: 'usr_test_01',
      deviceId: 'dev_test_01',
    );

    expect(sale.grandTotal.minorUnits, 650000);
    expect(sale.paymentStatus, 'PAID');

    // 1. Verify Stock decremented from 10 to 8
    expect(invRepo.getStockBalance(itemId), 8);

    // 2. Verify Wallet received Rs 6,500.00
    expect(walletRepo.getWalletBalance(cashWalletId).minorUnits, 650000);

    // 3. Verify Sync Outbox queued an INSERT event for this sale
    final syncRepo = SyncRepository(db);
    final pendingSync = syncRepo.getPendingEvents();
    expect(pendingSync.length, 1);
    expect(pendingSync[0].entityId, sale.id);
    expect(pendingSync[0].entityTable, 'sales');

    // 4. Verify Audit log was recorded
    final auditRs = db.connection.select('SELECT * FROM audit_logs WHERE entity_id = ?', [sale.id]);
    expect(auditRs.length, 1);
    expect(auditRs.first['action'], 'SALE_CREATED');

    db.close();
  });

  test('Atomic transaction rollbacks all tables on mid-transaction error', () {
    final db = createTestDb();
    seedPrerequisites(db);
    final invRepo = InventoryRepository(db);
    final walletRepo = WalletRepository(db);
    final now = DateTime.now().toUtc();

    const itemId = 'itm_rollback_test';
    invRepo.createItem(InventoryItemEntity(
      id: itemId,
      sku: 'SKU-ROLLBACK',
      name: 'Rollback Test Item',
      costPrice: Money.fromMinorUnits(10000, Currency.pkr),
      sellingPrice: Money.fromMinorUnits(20000, Currency.pkr),
      createdAt: now,
      updatedAt: now,
    ));

    const walletId = 'wal_rollback_test';
    walletRepo.createWallet(WalletEntity(
      id: walletId,
      name: 'Rollback Test Wallet',
      type: 'CASH',
      currency: Currency.pkr,
      balance: Money.zero(Currency.pkr),
      createdAt: now,
      updatedAt: now,
    ));

    // Attempt an atomic transaction that modifies inventory and wallet, but throws before commit
    bool caught = false;
    try {
      db.transaction(() {
        invRepo.recordMovement(
          itemId: itemId,
          type: 'PURCHASE',
          quantity: 50,
          costPrice: Money.fromMinorUnits(10000, Currency.pkr),
          referenceId: 'ref_aborted',
          actorId: 'usr_test_01',
          deviceId: 'dev_test_01',
        );

        walletRepo.recordTransaction(
          walletId: walletId,
          type: 'DEPOSIT',
          amount: Money.fromMinorUnits(500000, Currency.pkr),
          referenceId: 'ref_aborted',
          actorId: 'usr_test_01',
          deviceId: 'dev_test_01',
        );

        // Simulate crash/abort before commit
        throw StateError('Simulated unexpected power outage / error');
      });
    } catch (_) {
      caught = true;
    }

    assertTrue(caught);
    // Strict verification: Zero changes survived the rollback!
    expect(invRepo.getStockBalance(itemId), 0);
    expect(walletRepo.getWalletBalance(walletId).minorUnits, 0);

    final movCount = db.connection.select('SELECT COUNT(*) as count FROM inventory_movements');
    expect(movCount.first['count'], 0);

    final txCount = db.connection.select('SELECT COUNT(*) as count FROM wallet_transactions');
    expect(txCount.first['count'], 0);

    db.close();
  });

  test('Device Trust Lifecycle PENDING -> TRUSTED -> REVOKED', () {
    final db = createTestDb();
    seedPrerequisites(db);
    final devRepo = DeviceRepository(db);
    final now = DateTime.now().toUtc();

    const devId = 'dev_mobile_waiter_03';
    devRepo.registerPendingDevice(DeviceEntity(
      id: devId,
      name: 'Waiter Tablet Android',
      trustStatus: 'PENDING',
      publicKey: 'pk_ed25519_waiter',
      lastSeenAt: now,
      deviceType: 'tablet',
      ipAddress: '192.168.1.150',
    ));

    var dev = devRepo.getDeviceById(devId);
    assertTrue(dev != null);
    assertTrue(dev!.isPending);
    expect(dev.pairedAt, null);

    // Approve device to TRUSTED
    devRepo.setTrustStatus(devId, 'TRUSTED');
    dev = devRepo.getDeviceById(devId);
    assertTrue(dev!.isTrusted);
    assertTrue(dev.pairedAt != null);

    // Revoke compromised device
    devRepo.setTrustStatus(devId, 'REVOKED');
    dev = devRepo.getDeviceById(devId);
    assertTrue(dev!.isRevoked);

    db.close();
  });

  // ignore: avoid_print
  print('\nDatabase tests summary: $passed passed, $failed failed.');
  if (failed > 0) {
    exit(1);
  }
}
