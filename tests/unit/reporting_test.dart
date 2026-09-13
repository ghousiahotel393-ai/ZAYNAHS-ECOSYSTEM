import 'dart:convert';
import 'package:core/core.dart';
import 'package:database/database.dart';
import 'package:pos/pos.dart';

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
  print('\n=== Running Financial Reports & Analytics Tests (Phase 10) ===');

  AppDatabase createDb() {
    final db = AppDatabase.openInMemory();
    db.initialize();
    return db;
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
      "INSERT INTO users (id, name, email, role, password_hash, pin_hash, created_at, updated_at) VALUES (?, 'Store Cashier', 'cashier@zaynahs.local', 'Cashier', 'pwd_hash', 'pin_hash', '2026-09-12T00:00:00Z', '2026-09-12T00:00:00Z');",
      [actorId],
    );
  }

  // -------------------------------------------------------------
  // 1. Profit & Loss Report Tests
  // -------------------------------------------------------------
  test('P&L derives Gross Revenue, Returns, COGS, Operating Expenses and Net Profit directly from ledgers', () {
    final db = createDb();
    seedEcosystem(db);
    final invRepo = InventoryRepository(db);
    final walletRepo = WalletRepository(db);
    final salesRepo = SalesRepository(db: db, inventoryRepo: invRepo, walletRepo: walletRepo);
    final reportingEngine = ReportingEngine(
      db: db,
      inventoryRepo: invRepo,
      walletRepo: walletRepo,
      salesRepo: salesRepo,
    );

    final now = DateTime.now().toUtc();
    const curr = Currency.pkr;

    // Create Cash Wallet
    walletRepo.createWallet(WalletEntity(
      id: 'wal_cash_01',
      name: 'Main Cash Drawer',
      type: 'CASH',
      currency: curr,
      balance: Money.zero(curr),
      createdAt: now,
      updatedAt: now,
    ));

    // Create item: Cost 100 PKR, Retail 150 PKR
    invRepo.createItem(InventoryItemEntity(
      id: 'itm_shirt_01',
      sku: 'SKU_SHIRT_01',
      name: 'Polo Shirt',
      costPrice: Money.fromMinorUnits(10000, curr), // 100.00
      sellingPrice: Money.fromMinorUnits(15000, curr), // 150.00
      createdAt: now,
      updatedAt: now,
    ));

    // Add initial stock: 20 units
    invRepo.recordMovement(
      itemId: 'itm_shirt_01',
      type: 'PURCHASE',
      quantity: 20,
      costPrice: Money.fromMinorUnits(10000, curr),
      referenceId: 'po_01',
      actorId: 'usr_owner_01',
      deviceId: 'dev_counter_01',
    );

    // Execute Sale 1: 5 units @ 150.00 = 750.00 PKR (Cost: 5 * 100 = 500.00 PKR)
    final posEngine = UniversalPosEngine(
      salesRepo: salesRepo,
      inventoryRepo: invRepo,
      walletRepo: walletRepo,
    );

    final cart = PosCart.empty(curr).addItem(CartLineItem(
      itemId: 'itm_shirt_01',
      itemName: 'Polo Shirt',
      quantity: 5,
      unitPrice: Money.fromMinorUnits(15000, curr),
      costPrice: Money.fromMinorUnits(10000, curr),
      itemDiscount: Money.zero(curr),
    ));

    final saleResult = posEngine.checkout(
      cart: cart,
      invoiceNumber: 'INV-PNL-01',
      paymentAllocations: [
        PaymentAllocation(walletId: 'wal_cash_01', amount: Money.fromMinorUnits(75000, curr)),
      ],
      actorId: 'usr_owner_01',
      deviceId: 'dev_counter_01',
    );
    expect(saleResult.grandTotal.minorUnits, 75000);

    // Record an Operating Expense: 50.00 PKR from cash wallet
    walletRepo.recordTransaction(
      walletId: 'wal_cash_01',
      type: 'EXPENSE',
      amount: Money.fromMinorUnits(5000, curr),
      referenceId: 'exp_cleaning_01',
      actorId: 'usr_owner_01',
      deviceId: 'dev_counter_01',
    );

    // Generate P&L
    final pnl = reportingEngine.generateProfitAndLoss();

    // Gross Revenue = 750.00 PKR
    expect(pnl.grossRevenue.minorUnits, 75000);
    // Returns = 0
    expect(pnl.returnsTotal.minorUnits, 0);
    // Net Revenue = 750.00 PKR
    expect(pnl.netRevenue.minorUnits, 75000);
    // COGS = 500.00 PKR (5 units * 100.00)
    expect(pnl.costOfGoodsSold.minorUnits, 50000);
    // Gross Profit = 750.00 - 500.00 = 250.00 PKR
    expect(pnl.grossProfit.minorUnits, 25000);
    // Operating Expenses = 50.00 PKR
    expect(pnl.operatingExpenses.minorUnits, 5000);
    // Net Profit = 250.00 - 50.00 = 200.00 PKR
    expect(pnl.netProfit.minorUnits, 20000);
    db.close();
  });

  // -------------------------------------------------------------
  // 2. Inventory Valuation Report Tests
  // -------------------------------------------------------------
  test('Inventory valuation computes total units, cost valuation, retail valuation and potential margin', () {
    final db = createDb();
    seedEcosystem(db);
    final invRepo = InventoryRepository(db);
    final walletRepo = WalletRepository(db);
    final salesRepo = SalesRepository(db: db, inventoryRepo: invRepo, walletRepo: walletRepo);
    final reportingEngine = ReportingEngine(
      db: db,
      inventoryRepo: invRepo,
      walletRepo: walletRepo,
      salesRepo: salesRepo,
    );

    final now = DateTime.now().toUtc();
    const curr = Currency.pkr;

    // Item 1: Cost 200, Retail 300, Stock 10
    invRepo.createItem(InventoryItemEntity(
      id: 'itm_jeans_01',
      sku: 'SKU_JEANS_01',
      name: 'Denim Jeans',
      costPrice: Money.fromMinorUnits(20000, curr),
      sellingPrice: Money.fromMinorUnits(30000, curr),
      createdAt: now,
      updatedAt: now,
    ));
    invRepo.recordMovement(
      itemId: 'itm_jeans_01',
      type: 'PURCHASE',
      quantity: 10,
      costPrice: Money.fromMinorUnits(20000, curr),
      referenceId: 'po_jeans',
      actorId: 'usr_owner_01',
      deviceId: 'dev_counter_01',
    );

    // Item 2: Cost 50, Retail 80, Stock 20
    invRepo.createItem(InventoryItemEntity(
      id: 'itm_socks_01',
      sku: 'SKU_SOCKS_01',
      name: 'Cotton Socks',
      costPrice: Money.fromMinorUnits(5000, curr),
      sellingPrice: Money.fromMinorUnits(8000, curr),
      createdAt: now,
      updatedAt: now,
    ));
    invRepo.recordMovement(
      itemId: 'itm_socks_01',
      type: 'PURCHASE',
      quantity: 20,
      costPrice: Money.fromMinorUnits(5000, curr),
      referenceId: 'po_socks',
      actorId: 'usr_owner_01',
      deviceId: 'dev_counter_01',
    );

    final val = reportingEngine.generateInventoryValuation();

    expect(val.totalItemCount, 2);
    expect(val.totalStockUnits, 30); // 10 + 20
    // Cost Valuation: (10 * 200) + (20 * 50) = 2000 + 1000 = 3000 PKR (300,000 minor)
    expect(val.valuationAtCost.minorUnits, 300000);
    // Retail Valuation: (10 * 300) + (20 * 80) = 3000 + 1600 = 4600 PKR (460,000 minor)
    expect(val.valuationAtRetail.minorUnits, 460000);
    // Potential Margin: 4600 - 3000 = 1600 PKR (160,000 minor)
    expect(val.potentialMargin.minorUnits, 160000);
    db.close();
  });

  // -------------------------------------------------------------
  // 3. Payment Method Breakdown Report Tests
  // -------------------------------------------------------------
  test('Payment breakdown groups collected revenue across Cash, Bank, and Online wallets', () {
    final db = createDb();
    seedEcosystem(db);
    final invRepo = InventoryRepository(db);
    final walletRepo = WalletRepository(db);
    final salesRepo = SalesRepository(db: db, inventoryRepo: invRepo, walletRepo: walletRepo);
    final reportingEngine = ReportingEngine(
      db: db,
      inventoryRepo: invRepo,
      walletRepo: walletRepo,
      salesRepo: salesRepo,
    );

    final now = DateTime.now().toUtc();
    const curr = Currency.pkr;

    walletRepo.createWallet(WalletEntity(id: 'wal_cash_01', name: 'Cash Register', type: 'CASH', currency: curr, balance: Money.zero(curr), createdAt: now, updatedAt: now));
    walletRepo.createWallet(WalletEntity(id: 'wal_bank_01', name: 'Habib Bank POS', type: 'BANK', currency: curr, balance: Money.zero(curr), createdAt: now, updatedAt: now));
    walletRepo.createWallet(WalletEntity(id: 'wal_online_01', name: 'JazzCash Merchant', type: 'ONLINE', currency: curr, balance: Money.zero(curr), createdAt: now, updatedAt: now));

    invRepo.createItem(InventoryItemEntity(
      id: 'itm_multi_01',
      sku: 'SKU_ITEM_MULTI',
      name: 'Multi Item',
      costPrice: Money.fromMinorUnits(50000, curr),
      sellingPrice: Money.fromMinorUnits(100000, curr), // 1000 PKR
      createdAt: now,
      updatedAt: now,
    ));
    invRepo.recordMovement(
      itemId: 'itm_multi_01',
      type: 'PURCHASE',
      quantity: 5,
      costPrice: Money.fromMinorUnits(50000, curr),
      referenceId: 'po_multi',
      actorId: 'usr_owner_01',
      deviceId: 'dev_counter_01',
    );

    final posEngine = UniversalPosEngine(
      salesRepo: salesRepo,
      inventoryRepo: invRepo,
      walletRepo: walletRepo,
    );

    // Multi-payment split sale: 400 Cash, 350 Bank, 250 Online = 1000 PKR
    final cart = PosCart.empty(curr).addItem(CartLineItem(
      itemId: 'itm_multi_01',
      itemName: 'Multi Item',
      quantity: 1,
      unitPrice: Money.fromMinorUnits(100000, curr),
      costPrice: Money.fromMinorUnits(50000, curr),
      itemDiscount: Money.zero(curr),
    ));

    posEngine.checkout(
      cart: cart,
      invoiceNumber: 'INV-SPLIT-01',
      paymentAllocations: [
        PaymentAllocation(walletId: 'wal_cash_01', amount: Money.fromMinorUnits(40000, curr)),
        PaymentAllocation(walletId: 'wal_bank_01', amount: Money.fromMinorUnits(35000, curr)),
        PaymentAllocation(walletId: 'wal_online_01', amount: Money.fromMinorUnits(25000, curr)),
      ],
      actorId: 'usr_owner_01',
      deviceId: 'dev_counter_01',
    );

    final breakdown = reportingEngine.generatePaymentBreakdown();
    expect(breakdown.cashTotal.minorUnits, 40000);
    expect(breakdown.bankTotal.minorUnits, 35000);
    expect(breakdown.onlineTotal.minorUnits, 25000);
    expect(breakdown.totalCollected.minorUnits, 100000);
    db.close();
  });

  // -------------------------------------------------------------
  // 4. Shift Manager & Z-Report Tests
  // -------------------------------------------------------------
  test('ShiftManager handles opening, summary derivation, cash reconciliation, and Z-report printing', () {
    final db = createDb();
    seedEcosystem(db);
    final invRepo = InventoryRepository(db);
    final walletRepo = WalletRepository(db);
    final salesRepo = SalesRepository(db: db, inventoryRepo: invRepo, walletRepo: walletRepo);
    final shiftManager = ShiftManager(db: db);

    final now = DateTime.now().toUtc();
    const curr = Currency.pkr;

    walletRepo.createWallet(WalletEntity(
      id: 'wal_shift_cash',
      name: 'Shift Cash Box',
      type: 'CASH',
      currency: curr,
      balance: Money.zero(curr),
      createdAt: now,
      updatedAt: now,
    ));

    // 1. Open Shift with 5000.00 PKR opening float
    final shiftId = shiftManager.openShift(
      shiftNumber: 'SHIFT-20260912-001',
      cashierId: 'usr_owner_01',
      deviceId: 'dev_counter_01',
      openingFloat: Money.fromMinorUnits(500000, curr), // 5000.00
      notes: 'Morning shift opening',
    );

    assertTrue(shiftId.startsWith('shf_'));

    // Attempting to open another shift on same device throws validation error
    var errorThrown = false;
    try {
      shiftManager.openShift(
        shiftNumber: 'SHIFT-20260912-002',
        cashierId: 'usr_owner_01',
        deviceId: 'dev_counter_01',
        openingFloat: Money.fromMinorUnits(100000, curr),
      );
    } catch (_) {
      errorThrown = true;
    }
    assertTrue(errorThrown, 'Should reject opening second shift on same device while first is open');

    // 2. Perform Cash Sale: 1500.00 PKR
    invRepo.createItem(InventoryItemEntity(
      id: 'itm_jacket_01',
      sku: 'SKU_JACKET_01',
      name: 'Leather Jacket',
      costPrice: Money.fromMinorUnits(80000, curr),
      sellingPrice: Money.fromMinorUnits(150000, curr),
      createdAt: now,
      updatedAt: now,
    ));
    invRepo.recordMovement(
      itemId: 'itm_jacket_01',
      type: 'PURCHASE',
      quantity: 5,
      costPrice: Money.fromMinorUnits(80000, curr),
      referenceId: 'po_jacket',
      actorId: 'usr_owner_01',
      deviceId: 'dev_counter_01',
    );

    final posEngine = UniversalPosEngine(
      salesRepo: salesRepo,
      inventoryRepo: invRepo,
      walletRepo: walletRepo,
    );

    posEngine.checkout(
      cart: PosCart.empty(curr).addItem(CartLineItem(
        itemId: 'itm_jacket_01',
        itemName: 'Leather Jacket',
        quantity: 1,
        unitPrice: Money.fromMinorUnits(150000, curr),
        costPrice: Money.fromMinorUnits(80000, curr),
        itemDiscount: Money.zero(curr),
      )),
      invoiceNumber: 'INV-SHIFT-01',
      paymentAllocations: [
        PaymentAllocation(walletId: 'wal_shift_cash', amount: Money.fromMinorUnits(150000, curr)),
      ],
      actorId: 'usr_owner_01',
      deviceId: 'dev_counter_01',
    );

    // 3. Record a Cash Expense during shift: 200.00 PKR for tea/snacks
    walletRepo.recordTransaction(
      walletId: 'wal_shift_cash',
      type: 'EXPENSE',
      amount: Money.fromMinorUnits(20000, curr),
      referenceId: 'exp_tea_01',
      actorId: 'usr_owner_01',
      deviceId: 'dev_counter_01',
    );

    // Check intermediate summary:
    // Opening Float: 5000.00
    // Cash Sales: 1500.00
    // Cash Refunds: 0.00
    // Cash Expenses: 200.00
    // Expected Cash = 5000 + 1500 - 0 - 200 = 6300.00 PKR (630,000 minor)
    final intermediate = shiftManager.getShiftSummary(shiftId);
    expect(intermediate.openingFloat.minorUnits, 500000);
    expect(intermediate.cashSales.minorUnits, 150000);
    expect(intermediate.cashExpenses.minorUnits, 20000);
    expect(intermediate.cashRefunds.minorUnits, 0);
    expect(intermediate.expectedCash.minorUnits, 630000);

    // 4. Close Shift with Physical Count: 6250.00 PKR (50.00 PKR shortage)
    final closeResult = shiftManager.closeShift(
      shiftId: shiftId,
      countedCash: Money.fromMinorUnits(625000, curr),
      notes: 'Closing with 50 PKR shortage',
      actorId: 'usr_owner_01',
      deviceId: 'dev_counter_01',
    );

    expect(closeResult.countedCash.minorUnits, 625000);
    // Variance: 6250.00 - 6300.00 = -50.00 PKR (-5000 minor)
    expect(closeResult.variance.minorUnits, -5000);
    assertTrue(closeResult.zReportReceiptBytes.isNotEmpty);

    // Verify ESC/POS receipt contains Z-REPORT header
    final receiptUtf8 = latin1.decode(closeResult.zReportReceiptBytes);
    assertTrue(receiptUtf8.contains('DAILY REGISTER CLOSEOUT (Z-REPORT)'));
    assertTrue(receiptUtf8.contains('SHIFT-20260912-001'));
    assertTrue(receiptUtf8.contains('EXPECTED CASH'));
    assertTrue(receiptUtf8.contains('ACTUAL COUNTED'));
    assertTrue(receiptUtf8.contains('VARIANCE'));

    // Verify DB shift record is marked CLOSED
    final rs = db.connection.select('SELECT status, cash_variance_minor FROM register_shifts WHERE id = ?', [shiftId]);
    expect(rs.first['status'], 'CLOSED');
    expect(rs.first['cash_variance_minor'], -5000);

    // Verify Audit log was created
    final auditRs = db.connection.select("SELECT * FROM audit_logs WHERE action = 'REGISTER_SHIFT_CLOSED'");
    expect(auditRs.length, 1);
    expect(auditRs.first['entity_id'], shiftId);

    // Verify Sync Outbox was queued
    final syncRs = db.connection.select("SELECT * FROM sync_outbox WHERE entity_table = 'register_shifts'");
    expect(syncRs.length, 1);
    db.close();
  });

  // -------------------------------------------------------------
  // 5. Streaming CSV Exporter Tests
  // -------------------------------------------------------------
  await testAsync('StreamingExporter yields CSV rows in memory-bounded batches for sales, movements, and wallets', () async {
    final db = createDb();
    seedEcosystem(db);
    final invRepo = InventoryRepository(db);
    final walletRepo = WalletRepository(db);
    final salesRepo = SalesRepository(db: db, inventoryRepo: invRepo, walletRepo: walletRepo);
    final exporter = StreamingExporter(db: db);

    final now = DateTime.now().toUtc();
    const curr = Currency.pkr;

    walletRepo.createWallet(WalletEntity(
      id: 'wal_exp_01',
      name: 'Export Cash Wallet',
      type: 'CASH',
      currency: curr,
      balance: Money.zero(curr),
      createdAt: now,
      updatedAt: now,
    ));

    invRepo.createItem(InventoryItemEntity(
      id: 'itm_exp_01',
      sku: 'SKU_EXP_01',
      name: 'Export Item, With "Quotes"',
      costPrice: Money.fromMinorUnits(5000, curr),
      sellingPrice: Money.fromMinorUnits(10000, curr),
      createdAt: now,
      updatedAt: now,
    ));

    // Generate 5 movements
    for (int i = 0; i < 5; i++) {
      invRepo.recordMovement(
        itemId: 'itm_exp_01',
        type: 'PURCHASE',
        quantity: 10,
        costPrice: Money.fromMinorUnits(5000, curr),
        referenceId: 'po_exp_$i',
        actorId: 'usr_owner_01',
        deviceId: 'dev_counter_01',
      );
    }

    // Generate 3 wallet transactions
    for (int i = 0; i < 3; i++) {
      walletRepo.recordTransaction(
        walletId: 'wal_exp_01',
        type: 'DEPOSIT',
        amount: Money.fromMinorUnits(10000, curr),
        referenceId: 'ref_dep_$i',
        actorId: 'usr_owner_01',
        deviceId: 'dev_counter_01',
      );
    }

    // Generate 2 sales
    final posEngine = UniversalPosEngine(
      salesRepo: salesRepo,
      inventoryRepo: invRepo,
      walletRepo: walletRepo,
    );

    for (int i = 0; i < 2; i++) {
      posEngine.checkout(
        cart: PosCart.empty(curr).addItem(CartLineItem(
          itemId: 'itm_exp_01',
          itemName: 'Export Item',
          quantity: 1,
          unitPrice: Money.fromMinorUnits(10000, curr),
          costPrice: Money.fromMinorUnits(5000, curr),
          itemDiscount: Money.zero(curr),
        )),
        invoiceNumber: 'INV-EXP-$i',
        paymentAllocations: [
          PaymentAllocation(walletId: 'wal_exp_01', amount: Money.fromMinorUnits(10000, curr)),
        ],
        actorId: 'usr_owner_01',
        deviceId: 'dev_counter_01',
      );
    }

    // 1. Test streamSalesCsv
    final salesChunks = await exporter.streamSalesCsv(batchSize: 1).toList();
    assertTrue(salesChunks.isNotEmpty);
    final salesCsv = salesChunks.join();
    assertTrue(salesCsv.startsWith('ID,InvoiceNumber,SubtotalMinor'));
    assertTrue(salesCsv.contains('INV-'));

    // 2. Test streamInventoryMovementsCsv
    final moveChunks = await exporter.streamInventoryMovementsCsv(batchSize: 2).toList();
    assertTrue(moveChunks.isNotEmpty);
    final moveCsv = moveChunks.join();
    assertTrue(moveCsv.startsWith('ID,ItemId,Type,Quantity'));
    assertTrue(moveCsv.contains('PURCHASE'));
    assertTrue(moveCsv.contains('SALE'));

    // 3. Test streamWalletTransactionsCsv
    final walletChunks = await exporter.streamWalletTransactionsCsv(batchSize: 2).toList();
    assertTrue(walletChunks.isNotEmpty);
    final walletCsv = walletChunks.join();
    assertTrue(walletCsv.startsWith('ID,WalletId,Type,AmountMinor'));
    assertTrue(walletCsv.contains('DEPOSIT'));
    assertTrue(walletCsv.contains('SALE_PAYMENT'));

    // 4. Test CSV escaping helper
    expect(StreamingExporter.escapeCsv('SimpleText'), 'SimpleText');
    expect(StreamingExporter.escapeCsv('Text,With,Commas'), '"Text,With,Commas"');
    expect(StreamingExporter.escapeCsv('Text With "Quotes"'), '"Text With ""Quotes"""');
    expect(StreamingExporter.escapeCsv('Text\nWith\nNewlines'), '"Text\nWith\nNewlines"');
    expect(StreamingExporter.escapeCsv(null), '');
    db.close();
  });

  // Summary
  // ignore: avoid_print
  print('\n=== Financial Reports & Analytics Tests Summary ===');
  // ignore: avoid_print
  print('Passed: $passed, Failed: $failed');
  if (failed > 0) {
    throw Exception('$failed tests failed in Financial Reports & Analytics (Phase 10)!');
  }
}
