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
  print('\n=== Running Universal POS Engine & Golden Test 100 Tests ===');

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

  test('Business templates validate domain attributes correctly without altering POS logic', () {
    // 1. Clothing template enforces size & color
    final clothingTpl = BusinessTemplate.clothing;
    bool caughtClothing = false;
    try {
      clothingTpl.sanitizeAttributes({'size': 'XL'}); // Missing required 'color'
    } catch (_) {
      caughtClothing = true;
    }
    assertTrue(caughtClothing, 'Clothing should require both size and color');

    final validClothing = clothingTpl.sanitizeAttributes({'size': 'M', 'color': 'Blue', 'gender': 'Unisex'});
    expect(validClothing['size'], 'M');
    expect(validClothing['color'], 'Blue');

    // 2. Electronics template requires serial
    final elecTpl = BusinessTemplate.electronics;
    bool caughtElec = false;
    try {
      elecTpl.sanitizeAttributes({'model': 'Pro 15'}); // Missing required 'serial'
    } catch (_) {
      caughtElec = true;
    }
    assertTrue(caughtElec, 'Electronics should require serial number');

    // 3. Pharmacy template requires batch & expiry
    final pharmTpl = BusinessTemplate.pharmacy;
    bool caughtPharm = false;
    try {
      pharmTpl.sanitizeAttributes({'batch': 'B123'}); // Missing required 'expiry'
    } catch (_) {
      caughtPharm = true;
    }
    assertTrue(caughtPharm, 'Pharmacy should require batch and expiry');
  });

  test('PosCart calculates subtotal, discounts, and taxes with exact penny arithmetic', () {
    final cart = PosCart.empty(Currency.pkr)
        .addItem(CartLineItem(
          itemId: 'itm_01',
          itemName: 'Silk Shirt',
          quantity: 2,
          unitPrice: Money.fromMinorUnits(250000, Currency.pkr), // 2500 PKR
          costPrice: Money.fromMinorUnits(150000, Currency.pkr),
          itemDiscount: Money.fromMinorUnits(20000, Currency.pkr), // 200 PKR item discount
        ))
        .addItem(CartLineItem(
          itemId: 'itm_02',
          itemName: 'Cotton Chino',
          quantity: 1,
          unitPrice: Money.fromMinorUnits(300000, Currency.pkr), // 3000 PKR
          costPrice: Money.fromMinorUnits(180000, Currency.pkr),
          itemDiscount: Money.zero(Currency.pkr),
        ))
        .withCartDiscount(Money.fromMinorUnits(30000, Currency.pkr)) // 300 PKR cart discount
        .withTax(Money.fromMinorUnits(15000, Currency.pkr)); // 150 PKR tax

    expect(cart.totalItemCount, 3);
    // Subtotal: (2500 * 2) + 3000 = 8000 PKR (800000 minor)
    expect(cart.subtotal.minorUnits, 800000);
    // Item discounts: 200 PKR (20000 minor)
    expect(cart.itemDiscountsTotal.minorUnits, 20000);
    // Total discount: 200 + 300 = 500 PKR (50000 minor)
    expect(cart.totalDiscount.minorUnits, 50000);
    // Grand Total: (8000 - 500) + 150 = 7650 PKR (765000 minor)
    expect(cart.grandTotal.minorUnits, 765000);
  });

  test('UniversalPosEngine enforces NegativeStockPolicy.block when stock is insufficient', () {
    final db = createDb();
    seedEcosystem(db);

    final invRepo = InventoryRepository(db);
    final walletRepo = WalletRepository(db);
    final salesRepo = SalesRepository(db: db, inventoryRepo: invRepo, walletRepo: walletRepo);

    final engine = UniversalPosEngine(
      salesRepo: salesRepo,
      inventoryRepo: invRepo,
      walletRepo: walletRepo,
      stockPolicy: NegativeStockPolicy.block,
    );

    // Create item with stock of 2
    final now = DateTime.now().toUtc();
    invRepo.createItem(InventoryItemEntity(
      id: 'itm_limited',
      sku: 'SKU-LIMITED',
      name: 'Limited Edition Watch',
      costPrice: Money.fromMinorUnits(10000, Currency.pkr),
      sellingPrice: Money.fromMinorUnits(20000, Currency.pkr),
      createdAt: now,
      updatedAt: now,
    ));

    invRepo.recordMovement(
      itemId: 'itm_limited',
      type: 'PURCHASE',
      quantity: 2,
      costPrice: Money.fromMinorUnits(10000, Currency.pkr),
      referenceId: 'po_01',
      actorId: 'usr_owner_01',
      deviceId: 'dev_counter_01',
    );

    // Attempt to sell 5 units
    final cart = PosCart.empty(Currency.pkr).addItem(CartLineItem(
      itemId: 'itm_limited',
      itemName: 'Limited Edition Watch',
      quantity: 5,
      unitPrice: Money.fromMinorUnits(20000, Currency.pkr),
      costPrice: Money.fromMinorUnits(10000, Currency.pkr),
      itemDiscount: Money.zero(Currency.pkr),
    ));

    bool caught = false;
    try {
      engine.checkout(
        cart: cart,
        invoiceNumber: 'INV-TEST-001',
        paymentAllocations: [
          PaymentAllocation(walletId: 'wal_cash', amount: cart.grandTotal),
        ],
        actorId: 'usr_owner_01',
        deviceId: 'dev_counter_01',
      );
    } catch (_) {
      caught = true;
    }

    assertTrue(caught, 'UniversalPosEngine should block checkout when stock is insufficient');
    db.close();
  });

  test('Golden Test 100: Universal POS Engine executing multi-sale, split payment, and return scenario', () {
    // =========================================================================
    // GOLDEN TEST 100 SCENARIO SPECIFICATION (Rule 100):
    // Item price = 100, initial stock = 100.
    //
    // Sales:
    //   4 cash   -> cash +400,  stock -4  (stock remaining: 96)
    //   5 online -> online +500, stock -5 (stock remaining: 91)
    //   10 bank  -> bank +1000, stock -10 (stock remaining: 81)
    //
    // Discounted Split Sale:
    //   5 items, gross = 500, discount = 50, net = 450
    //   Split: 225 cash / 225 bank (stock remaining: 76)
    //
    // Return:
    //   quantity = 3 items from discounted sale returned
    //   refund = 270 (3 * net 90 per item)
    //   cash refund = 135
    //   bank refund = 135
    //   inventory restored = +3
    //
    // EXPECTED FINAL BALANCES:
    //   Stock = 79
    //   Cash wallet   = 400 + 225 - 135 = 490
    //   Online wallet = 500
    //   Bank wallet   = 1000 + 225 - 135 = 1090
    //   Total Wallets = 490 + 500 + 1090 = 2080
    // =========================================================================

    final db = createDb();
    seedEcosystem(db);

    final invRepo = InventoryRepository(db);
    final walletRepo = WalletRepository(db);
    final salesRepo = SalesRepository(db: db, inventoryRepo: invRepo, walletRepo: walletRepo);

    final engine = UniversalPosEngine(
      salesRepo: salesRepo,
      inventoryRepo: invRepo,
      walletRepo: walletRepo,
      stockPolicy: NegativeStockPolicy.block,
    );

    final now = DateTime.now().toUtc();
    const curr = Currency.pkr;

    // 1. Setup Wallets: CASH, BANK, ONLINE
    walletRepo.createWallet(WalletEntity(
      id: 'wal_cash_01',
      name: 'Counter Cash Drawer',
      type: 'CASH',
      currency: curr,
      balance: Money.zero(curr),
      createdAt: now,
      updatedAt: now,
    ));
    walletRepo.createWallet(WalletEntity(
      id: 'wal_online_01',
      name: 'JazzCash / EasyPaisa',
      type: 'ONLINE',
      currency: curr,
      balance: Money.zero(curr),
      createdAt: now,
      updatedAt: now,
    ));
    walletRepo.createWallet(WalletEntity(
      id: 'wal_bank_01',
      name: 'HBL Corporate Account',
      type: 'BANK',
      currency: curr,
      balance: Money.zero(curr),
      createdAt: now,
      updatedAt: now,
    ));

    // 2. Setup Item: Price 100, Initial Stock 100
    final itemPrice = Money.fromMinorUnits(10000, curr); // 100.00
    final itemCost = Money.fromMinorUnits(5000, curr);   // 50.00
    const itemId = 'itm_golden_100';

    invRepo.createItem(InventoryItemEntity(
      id: itemId,
      sku: 'SKU-GOLDEN-100',
      name: 'Universal Golden Polo',
      costPrice: itemCost,
      sellingPrice: itemPrice,
      createdAt: now,
      updatedAt: now,
    ));

    // Initial stock receipt of 100 units
    invRepo.recordMovement(
      itemId: itemId,
      type: 'PURCHASE',
      quantity: 100,
      costPrice: itemCost,
      referenceId: 'po_golden_initial',
      actorId: 'usr_owner_01',
      deviceId: 'dev_counter_01',
    );
    expect(invRepo.getStockBalance(itemId), 100);

    // -------------------------------------------------------------------------
    // SALE 1: 4 cash (4 * 100 = 400)
    // -------------------------------------------------------------------------
    final cart1 = PosCart.empty(curr).addItem(CartLineItem(
      itemId: itemId,
      itemName: 'Universal Golden Polo',
      quantity: 4,
      unitPrice: itemPrice,
      costPrice: itemCost,
      itemDiscount: Money.zero(curr),
    ));

    final sale1 = engine.checkout(
      cart: cart1,
      invoiceNumber: 'INV-100-01',
      paymentAllocations: [
        PaymentAllocation(walletId: 'wal_cash_01', amount: Money.fromMinorUnits(40000, curr)),
      ],
      actorId: 'usr_owner_01',
      deviceId: 'dev_counter_01',
    );
    expect(sale1.grandTotal.minorUnits, 40000);
    expect(invRepo.getStockBalance(itemId), 96);
    expect(walletRepo.getWalletBalance('wal_cash_01', curr).minorUnits, 40000);

    // -------------------------------------------------------------------------
    // SALE 2: 5 online (5 * 100 = 500)
    // -------------------------------------------------------------------------
    final cart2 = PosCart.empty(curr).addItem(CartLineItem(
      itemId: itemId,
      itemName: 'Universal Golden Polo',
      quantity: 5,
      unitPrice: itemPrice,
      costPrice: itemCost,
      itemDiscount: Money.zero(curr),
    ));

    final sale2 = engine.checkout(
      cart: cart2,
      invoiceNumber: 'INV-100-02',
      paymentAllocations: [
        PaymentAllocation(walletId: 'wal_online_01', amount: Money.fromMinorUnits(50000, curr)),
      ],
      actorId: 'usr_owner_01',
      deviceId: 'dev_counter_01',
    );
    expect(sale2.grandTotal.minorUnits, 50000);
    expect(invRepo.getStockBalance(itemId), 91);
    expect(walletRepo.getWalletBalance('wal_online_01', curr).minorUnits, 50000);

    // -------------------------------------------------------------------------
    // SALE 3: 10 bank (10 * 100 = 1000)
    // -------------------------------------------------------------------------
    final cart3 = PosCart.empty(curr).addItem(CartLineItem(
      itemId: itemId,
      itemName: 'Universal Golden Polo',
      quantity: 10,
      unitPrice: itemPrice,
      costPrice: itemCost,
      itemDiscount: Money.zero(curr),
    ));

    final sale3 = engine.checkout(
      cart: cart3,
      invoiceNumber: 'INV-100-03',
      paymentAllocations: [
        PaymentAllocation(walletId: 'wal_bank_01', amount: Money.fromMinorUnits(100000, curr)),
      ],
      actorId: 'usr_owner_01',
      deviceId: 'dev_counter_01',
    );
    expect(sale3.grandTotal.minorUnits, 100000);
    expect(invRepo.getStockBalance(itemId), 81);
    expect(walletRepo.getWalletBalance('wal_bank_01', curr).minorUnits, 100000);

    // -------------------------------------------------------------------------
    // SALE 4 (Discounted split sale):
    // 5 items, gross = 500, discount = 50, net = 450
    // Split: 225 cash / 225 bank
    // -------------------------------------------------------------------------
    final cart4 = PosCart.empty(curr)
        .addItem(CartLineItem(
          itemId: itemId,
          itemName: 'Universal Golden Polo',
          quantity: 5,
          unitPrice: itemPrice,
          costPrice: itemCost,
          itemDiscount: Money.zero(curr),
        ))
        .withCartDiscount(Money.fromMinorUnits(5000, curr)); // 50 PKR discount

    expect(cart4.subtotal.minorUnits, 50000);
    expect(cart4.grandTotal.minorUnits, 45000);

    final sale4 = engine.checkout(
      cart: cart4,
      invoiceNumber: 'INV-100-04',
      paymentAllocations: [
        PaymentAllocation(walletId: 'wal_cash_01', amount: Money.fromMinorUnits(22500, curr)),
        PaymentAllocation(walletId: 'wal_bank_01', amount: Money.fromMinorUnits(22500, curr)),
      ],
      actorId: 'usr_owner_01',
      deviceId: 'dev_counter_01',
    );
    expect(sale4.grandTotal.minorUnits, 45000);
    expect(invRepo.getStockBalance(itemId), 76);
    expect(walletRepo.getWalletBalance('wal_cash_01', curr).minorUnits, 62500); // 400 + 225 = 625
    expect(walletRepo.getWalletBalance('wal_bank_01', curr).minorUnits, 122500); // 1000 + 225 = 1225

    // -------------------------------------------------------------------------
    // RETURN:
    // 3 items returned from Sale 4
    // Refund = 270 (3 * net 90 per item)
    // Cash refund = 135
    // Bank refund = 135
    // Inventory restored = +3
    // -------------------------------------------------------------------------
    final ret = engine.processReturn(
      saleId: sale4.id,
      returnNumber: 'RET-100-01',
      itemsToReturn: [
        const ReturnItemRequest(itemId: itemId, quantity: 3),
      ],
      refundAllocations: [
        PaymentAllocation(walletId: 'wal_cash_01', amount: Money.fromMinorUnits(13500, curr)), // 135
        PaymentAllocation(walletId: 'wal_bank_01', amount: Money.fromMinorUnits(13500, curr)), // 135
      ],
      reason: 'Customer requested size change',
      actorId: 'usr_owner_01',
      deviceId: 'dev_counter_01',
    );
    expect(ret.totalRefund.minorUnits, 27000); // 270.00 refund

    // =========================================================================
    // FINAL AUTHORITATIVE LEDGER RECONCILIATION VERIFICATION (Rule 100)
    // =========================================================================

    // 1. Authoritative derived stock balance strictly derived from movement events
    final finalStock = invRepo.getStockBalance(itemId);
    expect(finalStock, 79);

    // 2. Authoritative wallet balances strictly derived from immutable transaction ledger
    final cashBalance = walletRepo.getWalletBalance('wal_cash_01', curr);
    final onlineBalance = walletRepo.getWalletBalance('wal_online_01', curr);
    final bankBalance = walletRepo.getWalletBalance('wal_bank_01', curr);

    expect(cashBalance.minorUnits, 49000);     // 400 + 225 - 135 = 490 PKR
    expect(onlineBalance.minorUnits, 50000);   // 500 PKR
    expect(bankBalance.minorUnits, 109000);    // 1000 + 225 - 135 = 1090 PKR

    // Total money in the ecosystem: 490 + 500 + 1090 = 2080 PKR
    final totalMoney = cashBalance + onlineBalance + bankBalance;
    expect(totalMoney.minorUnits, 208000);

    // 3. Verify SQLite Tables: sale_payments, returns, return_items, return_payments
    final spRows = db.connection.select('SELECT * FROM sale_payments;');
    // Sale 1: 1 alloc, Sale 2: 1 alloc, Sale 3: 1 alloc, Sale 4: 2 allocs = 5 total
    expect(spRows.length, 5);

    final retRows = db.connection.select('SELECT * FROM returns WHERE return_number = ?', ['RET-100-01']);
    expect(retRows.length, 1);
    expect(retRows.first['total_refund_minor'], 27000);

    final rtiRows = db.connection.select('SELECT * FROM return_items WHERE return_id = ?', [ret.id]);
    expect(rtiRows.length, 1);
    expect(rtiRows.first['quantity'], 3);
    expect(rtiRows.first['refund_amount_minor'], 27000);

    final rpmRows = db.connection.select('SELECT * FROM return_payments WHERE return_id = ?', [ret.id]);
    expect(rpmRows.length, 2);

    // 4. Verify durable sync outbox contains all transactions
    final outboxSales = db.connection.select("SELECT COUNT(*) AS c FROM sync_outbox WHERE entity_table = 'sales';");
    expect(outboxSales.first['c'], 4);

    final outboxReturns = db.connection.select("SELECT COUNT(*) AS c FROM sync_outbox WHERE entity_table = 'returns';");
    expect(outboxReturns.first['c'], 1);

    // 5. Verify cryptographic chained audit trail
    final auditRows = db.connection.select('SELECT COUNT(*) AS c FROM audit_logs;');
    expect(auditRows.first['c'], 5); // 4 sales + 1 return

    db.close();
  });

  // ignore: avoid_print
  print('\nPOS tests summary: $passed passed, $failed failed.');
  if (failed > 0) {
    throw AssertionError('$failed POS tests failed');
  }
}
