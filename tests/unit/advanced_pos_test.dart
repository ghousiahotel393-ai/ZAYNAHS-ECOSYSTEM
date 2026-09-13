import 'package:core/core.dart';
import 'package:database/database.dart';
import 'package:pos/pos.dart';

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
  print('\n=== Running Advanced POS & Supply Chain Tests (Phase 09) ===');

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

  test('Multi-tier Tax calculation computes exact inclusive and exclusive amounts', () {
    const curr = Currency.pkr;
    final baseAmount = Money.fromMinorUnits(100000, curr); // 1000.00 PKR

    // 1. Exclusive 18% GST: 1000 * 0.18 = 180.00 PKR
    final gstTax = TaxRate.standardGst18.calculateTax(baseAmount);
    expect(gstTax.minorUnits, 18000);

    // 2. Exclusive 5% VAT: 1000 * 0.05 = 50.00 PKR
    final vatTax = TaxRate.standardVat5.calculateTax(baseAmount);
    expect(vatTax.minorUnits, 5000);

    // 3. Inclusive 15% VAT: 1000 - (1000 / 1.15) = 1000 - 869.565... = 130.43 PKR -> 13043 minor
    final incTax = TaxRate.inclusiveVat15.calculateTax(baseAmount);
    expect(incTax.minorUnits, 13043);

    // 4. Zero-rated / Exempt
    final zeroTax = TaxRate.zeroRated.calculateTax(baseAmount);
    expect(zeroTax.minorUnits, 0);
  });

  test('Discount authorization enforces cashier thresholds and requires manager PIN override', () {
    const curr = Currency.pkr;
    const auth = DiscountAuthorization(maxCashierPercent: 10.0);
    final subtotal = Money.fromMinorUnits(100000, curr); // 1000 PKR

    // 1. Cashier applies 8% discount (80 PKR) -> Permitted
    auth.validateDiscount(
      subtotal: subtotal,
      discountAmount: Money.fromMinorUnits(8000, curr),
      userRole: 'Cashier',
    );

    // 2. Cashier applies 15% discount (150 PKR) without override -> Blocked
    bool caughtPermission = false;
    try {
      auth.validateDiscount(
        subtotal: subtotal,
        discountAmount: Money.fromMinorUnits(15000, curr),
        userRole: 'Cashier',
      );
    } on PermissionDeniedException {
      caughtPermission = true;
    }
    assertTrue(caughtPermission, 'Cashier should not exceed 10% discount without manager approval');

    // 3. Cashier applies 15% discount WITH manager override -> Permitted
    auth.validateDiscount(
      subtotal: subtotal,
      discountAmount: Money.fromMinorUnits(15000, curr),
      userRole: 'Cashier',
      isManagerOverrideApproved: true,
    );

    // 4. Manager role applies 25% discount directly -> Permitted
    auth.validateDiscount(
      subtotal: subtotal,
      discountAmount: Money.fromMinorUnits(25000, curr),
      userRole: 'Manager',
    );
  });

  test('Barcode & QR Code Engine validates EAN-13, UPC-A check digits and generates QR payloads', () {
    // 1. EAN-13 Modulo-10 checksum validation
    // Example: "978020137962" -> check digit is 4 -> "9780201379624"
    expect(BarcodeEngine.calculateEan13CheckDigit('978020137962'), 4);
    assertTrue(BarcodeEngine.isValidEan13('9780201379624'));
    assertTrue(!BarcodeEngine.isValidEan13('9780201379625')); // Invalid check digit

    // 2. UPC-A Modulo-10 checksum validation
    // Example: "03600029145" -> check digit is 2 -> "036000291452"
    expect(BarcodeEngine.calculateUpcACheckDigit('03600029145'), 2);
    assertTrue(BarcodeEngine.isValidUpcA('036000291452'));
    assertTrue(!BarcodeEngine.isValidUpcA('036000291453'));

    // 3. Format detection
    expect(BarcodeEngine.detectAndValidate('9780201379624'), BarcodeFormat.ean13);
    expect(BarcodeEngine.detectAndValidate('036000291452'), BarcodeFormat.upcA);
    expect(BarcodeEngine.detectAndValidate('ABC-12345'), BarcodeFormat.code128);

    // 4. QR Code payload generator
    final qr = BarcodeEngine.generateReceiptQrPayload(
      invoiceNumber: 'INV-20260912-001',
      totalMinor: 45000,
      currency: 'PKR',
      timestamp: DateTime.parse('2026-09-12T12:00:00Z'),
      deviceId: 'dev_01',
    );
    assertTrue(qr.startsWith('ZYN:INV-20260912-001|45000|PKR|'));
  });

  test('Thermal ESC/POS printing pipeline formats receipt and includes cash drawer kick and paper cut', () {
    final now = DateTime.now().toUtc();
    const curr = Currency.pkr;

    final sale = SaleEntity(
      id: 'sale_esc_test',
      invoiceNumber: 'INV-ESC-01',
      subtotal: Money.fromMinorUnits(50000, curr),
      discount: Money.fromMinorUnits(5000, curr),
      tax: Money.fromMinorUnits(8100, curr),
      grandTotal: Money.fromMinorUnits(53100, curr),
      paidAmount: Money.fromMinorUnits(53100, curr),
      dueAmount: Money.zero(curr),
      paymentStatus: 'PAID',
      actorId: 'usr_owner_01',
      deviceId: 'dev_counter_01',
      createdAt: now,
    );

    final bytes = EscPosBuilder.renderSaleReceipt(
      sale: sale,
      storeName: 'Zaynahs Boutique',
      items: [
        {'name': 'Lawn Kurti', 'qty': 1, 'price': 'Rs. 3,500'},
        {'name': 'Silk Scarf', 'qty': 1, 'price': 'Rs. 1,500'},
      ],
      width: PaperWidth.width80mm,
      kickDrawer: true,
    );

    assertTrue(bytes.isNotEmpty);
    // Verify cash drawer pulse command exists in byte stream: [0x1B, 0x70, 0x00, 0x19, 0xFA]
    final kickIndex = bytes.indexOf(0x70);
    assertTrue(kickIndex > 0 && bytes[kickIndex - 1] == 0x1B, 'Byte stream must include cash drawer kick pulse');

    // Verify paper cut command exists at end: [0x1D, 0x56, 0x42, 0x00]
    final cutIndex = bytes.lastIndexOf(0x56);
    assertTrue(cutIndex > 0 && bytes[cutIndex - 1] == 0x1D, 'Byte stream must include paper cut command');
  });

  test('ProcurementService restocks items (Stock IN) and derives supplier payables ledger', () {
    final db = createDb();
    seedEcosystem(db);

    final invRepo = InventoryRepository(db);
    final walletRepo = WalletRepository(db);
    final procurement = ProcurementService(
      db: db,
      inventoryRepo: invRepo,
      walletRepo: walletRepo,
    );

    final now = DateTime.now().toUtc();
    const curr = Currency.pkr;

    // 1. Setup Cash Drawer Wallet with 50,000 PKR balance
    walletRepo.createWallet(WalletEntity(
      id: 'wal_drawer',
      name: 'Main Drawer',
      type: 'CASH',
      currency: curr,
      balance: Money.fromMinorUnits(5000000, curr),
      createdAt: now,
      updatedAt: now,
    ));
    walletRepo.recordTransaction(
      walletId: 'wal_drawer',
      type: 'DEPOSIT',
      amount: Money.fromMinorUnits(5000000, curr),
      referenceId: 'opening_float',
      actorId: 'usr_owner_01',
      deviceId: 'dev_counter_01',
    );

    // 2. Setup Supplier
    const supId = 'sup_fabric_mill';
    procurement.createSupplier(
      id: supId,
      name: 'Al-Karam Textile Mills',
      company: 'Al-Karam Textiles Ltd',
      phone: '+92-300-1234567',
    );
    expect(procurement.getSupplierPayable(supId, curr).minorUnits, 0);

    // 3. Setup Item
    const itemId = 'itm_fabric_01';
    invRepo.createItem(InventoryItemEntity(
      id: itemId,
      sku: 'SKU-FABRIC-01',
      name: 'Premium Egyptian Cotton (Meter)',
      costPrice: Money.fromMinorUnits(80000, curr), // 800 PKR cost
      sellingPrice: Money.fromMinorUnits(140000, curr),
      createdAt: now,
      updatedAt: now,
    ));
    expect(invRepo.getStockBalance(itemId), 0);

    // 4. Receive Purchase Order: 50 meters @ 800 PKR = 40,000 PKR total
    // Pay 30,000 PKR cash immediately, 10,000 PKR remaining due to supplier
    final po = procurement.receivePurchaseOrder(
      poNumber: 'PO-2026-001',
      supplierId: supId,
      items: [
        PurchaseOrderItemInput(
          itemId: itemId,
          quantity: 50,
          unitCost: Money.fromMinorUnits(80000, curr),
        ),
      ],
      paidAmount: Money.fromMinorUnits(3000000, curr), // 30,000 PKR paid
      walletId: 'wal_drawer',
      actorId: 'usr_owner_01',
      deviceId: 'dev_counter_01',
    );

    expect(po.totalAmount.minorUnits, 4000000);   // 40,000 PKR
    expect(po.paidAmount.minorUnits, 3000000);    // 30,000 PKR
    expect(po.dueToSupplier.minorUnits, 1000000); // 10,000 PKR payable

    // Verify inventory Stock IN occurred (+50 meters)
    expect(invRepo.getStockBalance(itemId), 50);

    // Verify supplier payable ledger balance (Purchases - Payments = 10,000 PKR)
    expect(procurement.getSupplierPayable(supId, curr).minorUnits, 1000000);

    // Verify Cash Drawer was debited 30,000 PKR (50,000 - 30,000 = 20,000 PKR)
    expect(walletRepo.getWalletBalance('wal_drawer', curr).minorUnits, 2000000);

    db.close();
  });

  test('StockCountService executes Rule 51 physical audit, detects discrepancies, and posts adjustments', () {
    final db = createDb();
    seedEcosystem(db);

    final invRepo = InventoryRepository(db);
    final stockAudit = StockCountService(db: db, inventoryRepo: invRepo);

    final now = DateTime.now().toUtc();
    const curr = Currency.pkr;

    // 1. Create two items with initial stock movements
    const itemA = 'itm_audit_a';
    const itemB = 'itm_audit_b';

    invRepo.createItem(InventoryItemEntity(
      id: itemA,
      sku: 'SKU-AUDIT-A',
      name: 'Wireless Mouse',
      costPrice: Money.fromMinorUnits(150000, curr),
      sellingPrice: Money.fromMinorUnits(250000, curr),
      createdAt: now,
      updatedAt: now,
    ));
    invRepo.createItem(InventoryItemEntity(
      id: itemB,
      sku: 'SKU-AUDIT-B',
      name: 'Mechanical Keyboard',
      costPrice: Money.fromMinorUnits(600000, curr),
      sellingPrice: Money.fromMinorUnits(900000, curr),
      createdAt: now,
      updatedAt: now,
    ));

    // Ledger stock: Item A = 50, Item B = 20
    invRepo.recordMovement(
      itemId: itemA,
      type: 'PURCHASE',
      quantity: 50,
      costPrice: Money.fromMinorUnits(150000, curr),
      referenceId: 'initial_a',
      actorId: 'usr_owner_01',
      deviceId: 'dev_counter_01',
    );
    invRepo.recordMovement(
      itemId: itemB,
      type: 'PURCHASE',
      quantity: 20,
      costPrice: Money.fromMinorUnits(600000, curr),
      referenceId: 'initial_b',
      actorId: 'usr_owner_01',
      deviceId: 'dev_counter_01',
    );

    expect(invRepo.getStockBalance(itemA), 50);
    expect(invRepo.getStockBalance(itemB), 20);

    // 2. Physical count performed by staff:
    // Item A counted = 48 (Discrepancy: -2 shrinkage)
    // Item B counted = 23 (Discrepancy: +3 surplus found in storage)
    final report = stockAudit.executeStockCount(
      countNumber: 'STK-2026-001',
      physicalCounts: [
        const CountItemEntry(itemId: itemA, countedQuantity: 48),
        const CountItemEntry(itemId: itemB, countedQuantity: 23),
      ],
      notes: 'Quarterly warehouse physical audit',
      actorId: 'usr_owner_01',
      deviceId: 'dev_counter_01',
    );

    expect(report.totalAdjustmentsPosted, 2);
    expect(report.discrepancies.length, 2);

    final discA = report.discrepancies.firstWhere((d) => d.itemId == itemA);
    expect(discA.expectedQuantity, 50);
    expect(discA.countedQuantity, 48);
    expect(discA.variance, -2);

    final discB = report.discrepancies.firstWhere((d) => d.itemId == itemB);
    expect(discB.expectedQuantity, 20);
    expect(discB.countedQuantity, 23);
    expect(discB.variance, 3);

    // 3. Verify ledger stock reflects exact physical count after compensating adjustments
    expect(invRepo.getStockBalance(itemA), 48);
    expect(invRepo.getStockBalance(itemB), 23);

    // 4. Verify audit log and sync outbox
    final auditRs = db.connection.select("SELECT * FROM audit_logs WHERE action = 'STOCK_COUNT_RECONCILED';");
    expect(auditRs.length, 1);

    final syncRs = db.connection.select("SELECT * FROM sync_outbox WHERE entity_table = 'stock_counts';");
    expect(syncRs.length, 1);

    db.close();
  });

  // ignore: avoid_print
  print('\nAdvanced POS tests summary: $passed passed, $failed failed.');
  if (failed > 0) {
    throw AssertionError('$failed Advanced POS tests failed');
  }
}
