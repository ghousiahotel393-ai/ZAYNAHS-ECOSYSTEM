import 'dart:convert';
import 'dart:io';
import 'package:backup/backup.dart';
import 'package:cctv/cctv.dart';
import 'package:core/core.dart';
import 'package:database/database.dart';
import 'package:pos/pos.dart';
import 'package:storage/storage.dart';
import 'package:sync/sync.dart';

void main(List<String> args) async {
  final port = int.tryParse(Platform.environment['PORT'] ?? '') ?? 8080;
  final host = '127.0.0.1';

  // Ensure data directories exist
  final dataDir = Directory('data');
  if (!dataDir.existsSync()) dataDir.createSync(recursive: true);

  final storageDir = Directory('data/storage');
  if (!storageDir.existsSync()) storageDir.createSync(recursive: true);

  final dbPath = 'data/ecosystem.db';
  final db = AppDatabase.openFile(dbPath);
  db.initialize();

  final storageService = FileStorageService(storageDir.path);
  final invRepo = InventoryRepository(db);
  final walletRepo = WalletRepository(db);
  final salesRepo = SalesRepository(db: db, inventoryRepo: invRepo, walletRepo: walletRepo);
  final posEngine = UniversalPosEngine(
    salesRepo: salesRepo,
    inventoryRepo: invRepo,
    walletRepo: walletRepo,
  );
  final reportingEngine = ReportingEngine(
    db: db,
    inventoryRepo: invRepo,
    walletRepo: walletRepo,
    salesRepo: salesRepo,
  );
  final syncQueue = SyncOutboxQueue(db);
  final backupWriter = BackupWriter(db: db, storageService: storageService);
  final cctvDiscovery = CameraDiscoveryService(db: db);

  // Seed baseline demo data if not already present
  _seedBaselineData(db, invRepo, walletRepo, cctvDiscovery);

  // Start HTTP Server for Web POS & Local Dashboard
  final server = await HttpServer.bind(host, port);

  // ignore: avoid_print
  print('================================================================');
  // ignore: avoid_print
  print('  🚀 ZAYNAHS ECOSYSTEM — LOCAL APPLICATION RUNNER IS ACTIVE');
  // ignore: avoid_print
  print('================================================================');
  // ignore: avoid_print
  print('  Database File : $dbPath (SQLite WAL Mode, Schema v8)');
  // ignore: avoid_print
  print('  Architecture  : STRICTLY ONE ECOSYSTEM — ZERO BRANCHES');
  // ignore: avoid_print
  print('  Web Dashboard : http://$host:$port/');
  // ignore: avoid_print
  print('  REST API      : http://$host:$port/api/status');
  // ignore: avoid_print
  print('================================================================');
  // ignore: avoid_print
  print('  Open http://$host:$port/ in your browser to test.');
  // ignore: avoid_print
  print('  Press Ctrl+C to stop the local server.\n');

  await for (HttpRequest req in server) {
    try {
      final path = req.uri.path;
      final method = req.method;

      // Enable CORS for testing
      req.response.headers.add('Access-Control-Allow-Origin', '*');
      req.response.headers.add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
      req.response.headers.add('Access-Control-Allow-Headers', 'Content-Type');

      if (method == 'OPTIONS') {
        req.response.statusCode = HttpStatus.ok;
        await req.response.close();
        continue;
      }

      if (path == '/' || path == '/index.html') {
        req.response.headers.contentType = ContentType.html;
        req.response.write(_renderHtmlDashboard());
        await req.response.close();
        continue;
      }

      if (path == '/api/status' && method == 'GET') {
        _jsonResponse(req, {
          'status': 'ONLINE',
          'ecosystem': 'Zaynahs Master Enterprise',
          'architecture': 'ONE_ECOSYSTEM_ZERO_BRANCH',
          'schema_version': 8,
          'device_id': 'dev_local_pos',
          'device_trust': 'TRUSTED',
          'wallets_count': walletRepo.listActiveWallets().length,
          'items_count': invRepo.listActiveItems().length,
          'pending_sync_events': syncQueue.getPendingCount(),
          'timestamp': DateTime.now().toUtc().toIso8601String(),
        });
        continue;
      }

      if (path == '/api/inventory' && method == 'GET') {
        final items = invRepo.listActiveItems();
        final list = items.map((it) {
          final balance = invRepo.getStockBalance(it.id);
          return {
            'id': it.id,
            'sku': it.sku,
            'name': it.name,
            'cost_price': it.costPrice.minorUnits,
            'selling_price': it.sellingPrice.minorUnits,
            'stock': balance,
          };
        }).toList();
        _jsonResponse(req, {'items': list});
        continue;
      }

      if (path == '/api/wallets' && method == 'GET') {
        final wallets = walletRepo.listActiveWallets();
        final list = wallets.map((w) {
          final balance = walletRepo.getWalletBalance(w.id);
          return {
            'id': w.id,
            'name': w.name,
            'type': w.type,
            'currency': w.currency.code,
            'balance': balance.minorUnits,
          };
        }).toList();
        _jsonResponse(req, {'wallets': list});
        continue;
      }

      if (path == '/api/pos/checkout' && method == 'POST') {
        final bodyStr = await utf8.decodeStream(req);
        final body = jsonDecode(bodyStr) as Map<String, dynamic>;

        final itemsJson = (body['items'] as List).cast<Map<String, dynamic>>();
        final paymentsJson = (body['payments'] as List).cast<Map<String, dynamic>>();
        final curr = Currency.pkr;

        final cartItems = itemsJson.map((it) {
          return CartLineItem(
            itemId: it['item_id'] as String,
            itemName: it['item_name'] as String,
            quantity: it['quantity'] as int,
            unitPrice: Money.fromMinorUnits(it['unit_price'] as int, curr),
            costPrice: Money.fromMinorUnits(it['cost_price'] as int, curr),
            itemDiscount: Money.zero(curr),
          );
        }).toList();

        final payments = paymentsJson.map((p) {
          return PaymentAllocation(
            walletId: p['wallet_id'] as String,
            amount: Money.fromMinorUnits(p['amount'] as int, curr),
          );
        }).toList();

        final invoiceNum = 'INV-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

        final cart = PosCart(
          items: cartItems,
          cartDiscount: Money.zero(curr),
          tax: Money.zero(curr),
        );

        final sale = posEngine.checkout(
          cart: cart,
          invoiceNumber: invoiceNum,
          paymentAllocations: payments,
          actorId: 'usr_cashier_01',
          deviceId: 'dev_local_pos',
        );

        _jsonResponse(req, {
          'success': true,
          'sale_id': sale.id,
          'invoice_number': sale.invoiceNumber,
          'total_amount': sale.grandTotal.minorUnits,
        });
        continue;
      }

      if (path == '/api/inventory/stock_in' && method == 'POST') {
        final bodyStr = await utf8.decodeStream(req);
        final body = jsonDecode(bodyStr) as Map<String, dynamic>;
        final itemId = body['item_id'] as String;
        final qty = body['quantity'] as int;
        final costMinor = body['cost_price'] as int? ?? 50000;
        final curr = Currency.pkr;

        final mEntity = invRepo.recordMovement(
          itemId: itemId,
          type: 'PURCHASE',
          quantity: qty,
          costPrice: Money.fromMinorUnits(costMinor, curr),
          referenceId: 'PO-${DateTime.now().millisecondsSinceEpoch}',
          actorId: 'usr_admin_01',
          deviceId: 'dev_local_pos',
        );

        final newBal = invRepo.getStockBalance(itemId);
        _jsonResponse(req, {
          'success': true,
          'movement_id': mEntity.id,
          'item_id': itemId,
          'new_stock': newBal,
        });
        continue;
      }

      if (path == '/api/wallets/transfer' && method == 'POST') {
        final bodyStr = await utf8.decodeStream(req);
        final body = jsonDecode(bodyStr) as Map<String, dynamic>;
        final fromId = body['from_wallet_id'] as String;
        final toId = body['to_wallet_id'] as String;
        final amountMinor = body['amount'] as int;
        final curr = Currency.pkr;

        walletRepo.transferBetweenWallets(
          fromWalletId: fromId,
          toWalletId: toId,
          amount: Money.fromMinorUnits(amountMinor, curr),
          actorId: 'usr_admin_01',
          deviceId: 'dev_local_pos',
          notes: body['notes'] as String?,
        );

        _jsonResponse(req, {
          'success': true,
          'from_balance': walletRepo.getWalletBalance(fromId).minorUnits,
          'to_balance': walletRepo.getWalletBalance(toId).minorUnits,
        });
        continue;
      }

      if (path == '/api/reports/pnl' && method == 'GET') {
        final now = DateTime.now().toUtc();
        final start = now.subtract(const Duration(days: 30));
        final pnl = reportingEngine.generateProfitAndLoss(startDate: start, endDate: now);
        _jsonResponse(req, {
          'gross_revenue': pnl.grossRevenue.minorUnits,
          'returns_amount': pnl.returnsTotal.minorUnits,
          'net_revenue': pnl.netRevenue.minorUnits,
          'cogs': pnl.costOfGoodsSold.minorUnits,
          'gross_profit': pnl.grossProfit.minorUnits,
          'net_profit': pnl.netProfit.minorUnits,
        });
        continue;
      }

      if (path == '/api/backup/create' && method == 'POST') {
        final res = await backupWriter.createBackup(
          type: BackupType.manual,
          actorId: 'usr_admin_01',
          deviceId: 'dev_local_pos',
        );
        _jsonResponse(req, {
          'success': true,
          'backup_id': res.id,
          'file_size_bytes': res.fileSizeBytes,
          'sha256': res.sha256Checksum,
          'created_at': res.createdAt.toIso8601String(),
        });
        continue;
      }

      if (path == '/api/cctv/cameras' && method == 'GET') {
        final cameras = cctvDiscovery.listCameras();
        _jsonResponse(req, {
          'cameras': cameras.map((c) => {
            'id': c.id,
            'name': c.name,
            'type': c.type.name,
            'url': c.sourceUrl,
            'is_recording': c.state == CameraConnectionState.recording,
          }).toList(),
        });
        continue;
      }

      req.response.statusCode = HttpStatus.notFound;
      _jsonResponse(req, {'error': 'Not Found', 'path': path});
    } catch (e, st) {
      req.response.statusCode = HttpStatus.internalServerError;
      _jsonResponse(req, {'error': e.toString(), 'stack': st.toString()});
    }
  }
}

void _jsonResponse(HttpRequest req, Map<String, dynamic> data) {
  req.response.headers.contentType = ContentType.json;
  req.response.write(jsonEncode(data));
  req.response.close();
}

void _seedBaselineData(
  AppDatabase db,
  InventoryRepository invRepo,
  WalletRepository walletRepo,
  CameraDiscoveryService cctvDiscovery,
) {
  final now = DateTime.now().toUtc();
  final curr = Currency.pkr;

  // 1. Ecosystem
  db.connection.execute(
    '''
    INSERT OR IGNORE INTO ecosystems (id, name, created_at, updated_at, settings_json)
    VALUES ('eco_default', 'Zaynahs Master Enterprise', ?, ?, '{}');
    ''',
    [now.toIso8601String(), now.toIso8601String()],
  );

  // 2. Trusted Device
  db.connection.execute(
    '''
    INSERT OR IGNORE INTO devices (id, name, trust_status, public_key, paired_at, last_seen_at, device_type)
    VALUES ('dev_local_pos', 'Primary POS Station', 'TRUSTED', 'pub_key_master_station', ?, ?, 'terminal');
    ''',
    [now.toIso8601String(), now.toIso8601String()],
  );

  // 3. Users: Admin & Cashier
  db.connection.execute(
    '''
    INSERT OR IGNORE INTO users (id, name, email, role, password_hash, pin_hash, is_active, created_at, updated_at)
    VALUES 
      ('usr_admin_01', 'System Owner', 'owner@zaynahs.com', 'Owner', 'hash_admin', 'hash_pin', 1, ?, ?),
      ('usr_cashier_01', 'Counter Cashier', 'cashier@zaynahs.com', 'Cashier', 'hash_cashier', 'hash_pin', 1, ?, ?);
    ''',
    [now.toIso8601String(), now.toIso8601String(), now.toIso8601String(), now.toIso8601String()],
  );

  // 4. Wallets: Cash, Bank, Online
  final existingWallets = walletRepo.listActiveWallets();
  if (existingWallets.isEmpty) {
    final cashInit = Money.fromMinorUnits(5000000, curr);
    walletRepo.createWallet(WalletEntity(
      id: 'wal_cash',
      name: 'Main Cash Drawer',
      type: 'CASH',
      currency: curr,
      balance: cashInit,
      createdAt: now,
      updatedAt: now,
    ));
    walletRepo.recordTransaction(
      walletId: 'wal_cash',
      type: 'DEPOSIT',
      amount: cashInit,
      referenceId: 'OPENING-CASH',
      actorId: 'usr_admin_01',
      deviceId: 'dev_local_pos',
      notes: 'Initial cash drawer float',
    );

    final bankInit = Money.fromMinorUnits(20000000, curr);
    walletRepo.createWallet(WalletEntity(
      id: 'wal_bank',
      name: 'HBL Business Account',
      type: 'BANK',
      currency: curr,
      balance: bankInit,
      createdAt: now,
      updatedAt: now,
    ));
    walletRepo.recordTransaction(
      walletId: 'wal_bank',
      type: 'DEPOSIT',
      amount: bankInit,
      referenceId: 'OPENING-BANK',
      actorId: 'usr_admin_01',
      deviceId: 'dev_local_pos',
      notes: 'Opening bank account balance',
    );

    final onlineInit = Money.fromMinorUnits(3500000, curr);
    walletRepo.createWallet(WalletEntity(
      id: 'wal_online',
      name: 'Easypaisa / Raast Online',
      type: 'ONLINE',
      currency: curr,
      balance: onlineInit,
      createdAt: now,
      updatedAt: now,
    ));
    walletRepo.recordTransaction(
      walletId: 'wal_online',
      type: 'DEPOSIT',
      amount: onlineInit,
      referenceId: 'OPENING-ONLINE',
      actorId: 'usr_admin_01',
      deviceId: 'dev_local_pos',
      notes: 'Opening online account balance',
    );
  }

  // 5. Items & Movements
  final existingItems = invRepo.listActiveItems();
  if (existingItems.isEmpty) {
    final catalog = [
      {'id': 'itm_01', 'sku': 'SHIRT-POLO-01', 'name': 'Classic Pique Polo Shirt', 'cost': 120000, 'price': 250000, 'stock': 50},
      {'id': 'itm_02', 'sku': 'JEANS-DENIM-02', 'name': 'Slim Fit Stretch Jeans', 'cost': 220000, 'price': 450000, 'stock': 35},
      {'id': 'itm_03', 'sku': 'HOODIE-FLEECE-03', 'name': 'Premium Fleece Hoodie', 'cost': 280000, 'price': 550000, 'stock': 20},
      {'id': 'itm_04', 'sku': 'ACC-LEATHER-04', 'name': 'Genuine Leather Bifold Wallet', 'cost': 90000, 'price': 180000, 'stock': 40},
      {'id': 'itm_05', 'sku': 'CAP-SNAPBACK-05', 'name': 'Embroidered Snapback Cap', 'cost': 60000, 'price': 120000, 'stock': 60},
    ];

    for (final item in catalog) {
      final iId = item['id'] as String;
      invRepo.createItem(InventoryItemEntity(
        id: iId,
        sku: item['sku'] as String,
        name: item['name'] as String,
        costPrice: Money.fromMinorUnits(item['cost'] as int, curr),
        sellingPrice: Money.fromMinorUnits(item['price'] as int, curr),
        createdAt: now,
        updatedAt: now,
      ));

      invRepo.recordMovement(
        itemId: iId,
        type: 'PURCHASE',
        quantity: item['stock'] as int,
        costPrice: Money.fromMinorUnits(item['cost'] as int, curr),
        referenceId: 'PO-INITIAL-${item['sku']}',
        actorId: 'usr_admin_01',
        deviceId: 'dev_local_pos',
      );
    }
  }

  // 6. Cameras
  final existingCams = cctvDiscovery.listCameras();
  if (existingCams.isEmpty) {
    cctvDiscovery.registerCamera(
      name: 'Counter & Register 01 (HD)',
      type: CameraSourceType.rtsp,
      sourceUrl: 'rtsp://192.168.1.120:554/live/ch0',
      deviceId: 'dev_local_pos',
    );
    cctvDiscovery.registerCamera(
      name: 'Entrance & Customer Area (HD)',
      type: CameraSourceType.rtsp,
      sourceUrl: 'rtsp://192.168.1.121:554/live/ch0',
      deviceId: 'dev_local_pos',
    );
  }
}

String _renderHtmlDashboard() {
  return '''<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Zaynahs Ecosystem — Local POS & Management Console</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Outfit:wght@300;400;500;600;700&family=JetBrains+Mono:wght@400;500;700&display=swap" rel="stylesheet">
  <style>
    :root {
      --bg-base: #0B0F19;
      --bg-surface: #121826;
      --bg-card: rgba(26, 34, 52, 0.7);
      --bg-card-hover: rgba(36, 47, 72, 0.85);
      --border-color: rgba(255, 255, 255, 0.08);
      --border-accent: rgba(99, 102, 241, 0.3);
      --text-primary: #F8FAFC;
      --text-secondary: #94A3B8;
      --text-muted: #64748B;
      --accent-indigo: #6366F1;
      --accent-emerald: #10B981;
      --accent-amber: #F59E0B;
      --accent-rose: #F43F5E;
      --accent-cyan: #06B6D4;
      --font-main: 'Outfit', -apple-system, BlinkMacSystemFont, sans-serif;
      --font-mono: 'JetBrains Mono', monospace;
    }

    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      background-color: var(--bg-base);
      color: var(--text-primary);
      font-family: var(--font-main);
      min-height: 100vh;
      display: flex;
      flex-direction: column;
      overflow-x: hidden;
    }

    header {
      background: rgba(18, 24, 38, 0.85);
      backdrop-filter: blur(12px);
      border-bottom: 1px solid var(--border-color);
      padding: 1rem 2rem;
      display: flex;
      justify-content: space-between;
      align-items: center;
      position: sticky;
      top: 0;
      z-index: 100;
    }
    .logo-badge {
      display: flex;
      align-items: center;
      gap: 0.75rem;
    }
    .logo-icon {
      width: 40px;
      height: 40px;
      border-radius: 10px;
      background: linear-gradient(135deg, var(--accent-indigo), var(--accent-cyan));
      display: flex;
      align-items: center;
      justify-content: center;
      font-weight: 700;
      font-size: 1.25rem;
      color: white;
      box-shadow: 0 4px 15px rgba(99, 102, 241, 0.35);
    }
    .logo-text h1 { font-size: 1.15rem; font-weight: 700; letter-spacing: -0.02em; }
    .logo-text p { font-size: 0.75rem; color: var(--accent-emerald); font-family: var(--font-mono); }

    .header-badges {
      display: flex;
      gap: 0.75rem;
      align-items: center;
    }
    .pill {
      background: rgba(255, 255, 255, 0.05);
      border: 1px solid var(--border-color);
      padding: 0.35rem 0.75rem;
      border-radius: 9999px;
      font-size: 0.75rem;
      font-family: var(--font-mono);
      display: flex;
      align-items: center;
      gap: 0.4rem;
    }
    .dot-green { width: 7px; height: 7px; border-radius: 50%; background: var(--accent-emerald); box-shadow: 0 0 8px var(--accent-emerald); }

    .tabs-bar {
      display: flex;
      gap: 0.5rem;
      background: var(--bg-surface);
      padding: 0.75rem 2rem;
      border-bottom: 1px solid var(--border-color);
    }
    .tab-btn {
      background: transparent;
      border: none;
      color: var(--text-secondary);
      padding: 0.6rem 1.2rem;
      border-radius: 8px;
      font-family: var(--font-main);
      font-size: 0.9rem;
      font-weight: 500;
      cursor: pointer;
      transition: all 0.2s ease;
      display: flex;
      align-items: center;
      gap: 0.5rem;
    }
    .tab-btn:hover { background: rgba(255, 255, 255, 0.05); color: var(--text-primary); }
    .tab-btn.active { background: var(--accent-indigo); color: white; box-shadow: 0 4px 12px rgba(99, 102, 241, 0.3); }

    main { flex: 1; padding: 2rem; max-width: 1400px; margin: 0 auto; width: 100%; }

    .tab-content { display: none; }
    .tab-content.active { display: block; animation: fadeIn 0.25s ease-out; }

    @keyframes fadeIn { from { opacity: 0; transform: translateY(6px); } to { opacity: 1; transform: translateY(0); } }

    .pos-grid {
      display: grid;
      grid-template-columns: 1fr 420px;
      gap: 2rem;
    }
    @media (max-width: 1024px) {
      .pos-grid { grid-template-columns: 1fr; }
    }

    .catalog-header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 1.25rem;
    }
    .catalog-cards {
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(220px, 1fr));
      gap: 1.25rem;
    }
    .product-card {
      background: var(--bg-card);
      border: 1px solid var(--border-color);
      border-radius: 12px;
      padding: 1.25rem;
      display: flex;
      flex-direction: column;
      justify-content: space-between;
      cursor: pointer;
      transition: all 0.2s ease;
      backdrop-filter: blur(8px);
    }
    .product-card:hover {
      background: var(--bg-card-hover);
      border-color: var(--border-accent);
      transform: translateY(-2px);
      box-shadow: 0 8px 24px rgba(0, 0, 0, 0.3);
    }
    .sku-badge { font-size: 0.7rem; color: var(--accent-cyan); font-family: var(--font-mono); margin-bottom: 0.4rem; }
    .product-title { font-weight: 600; font-size: 1rem; line-height: 1.3; margin-bottom: 0.75rem; color: var(--text-primary); }
    .product-meta { display: flex; justify-content: space-between; align-items: flex-end; margin-top: auto; }
    .price-tag { font-size: 1.15rem; font-weight: 700; color: var(--accent-emerald); }
    .stock-tag { font-size: 0.75rem; padding: 0.2rem 0.5rem; border-radius: 4px; background: rgba(255, 255, 255, 0.05); color: var(--text-secondary); font-family: var(--font-mono); }

    .cart-panel {
      background: var(--bg-surface);
      border: 1px solid var(--border-color);
      border-radius: 16px;
      padding: 1.5rem;
      display: flex;
      flex-direction: column;
      height: fit-content;
      position: sticky;
      top: 5rem;
    }
    .cart-title { font-size: 1.1rem; font-weight: 700; margin-bottom: 1rem; display: flex; justify-content: space-between; align-items: center; }
    .cart-items {
      max-height: 320px;
      overflow-y: auto;
      margin-bottom: 1rem;
      display: flex;
      flex-direction: column;
      gap: 0.75rem;
    }
    .cart-item {
      display: flex;
      justify-content: space-between;
      align-items: center;
      background: rgba(255, 255, 255, 0.03);
      padding: 0.75rem 1rem;
      border-radius: 8px;
      border: 1px solid var(--border-color);
    }
    .cart-item-name { font-size: 0.85rem; font-weight: 500; }
    .cart-item-qty { display: flex; align-items: center; gap: 0.5rem; font-family: var(--font-mono); font-size: 0.85rem; }
    .qty-btn {
      width: 24px;
      height: 24px;
      border-radius: 4px;
      background: rgba(255, 255, 255, 0.1);
      border: none;
      color: white;
      cursor: pointer;
      display: flex;
      align-items: center;
      justify-content: center;
    }
    .qty-btn:hover { background: var(--accent-indigo); }
    .cart-summary {
      border-top: 1px solid var(--border-color);
      padding-top: 1rem;
      display: flex;
      flex-direction: column;
      gap: 0.5rem;
      font-size: 0.9rem;
      color: var(--text-secondary);
    }
    .summary-row { display: flex; justify-content: space-between; }
    .summary-row.total {
      font-size: 1.25rem;
      font-weight: 700;
      color: var(--text-primary);
      margin-top: 0.5rem;
      padding-top: 0.5rem;
      border-top: 1px dashed var(--border-color);
    }

    .payment-selection {
      margin-top: 1.25rem;
      display: flex;
      flex-direction: column;
      gap: 0.6rem;
    }
    .payment-title { font-size: 0.8rem; font-weight: 600; color: var(--text-muted); text-transform: uppercase; letter-spacing: 0.05em; }
    .wallet-radios { display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 0.5rem; }
    .wallet-opt {
      background: rgba(255, 255, 255, 0.04);
      border: 1px solid var(--border-color);
      border-radius: 8px;
      padding: 0.6rem 0.4rem;
      text-align: center;
      font-size: 0.75rem;
      cursor: pointer;
      transition: all 0.2s;
    }
    .wallet-opt:hover { background: rgba(255, 255, 255, 0.08); }
    .wallet-opt.selected {
      background: rgba(99, 102, 241, 0.2);
      border-color: var(--accent-indigo);
      color: var(--accent-indigo);
      font-weight: 600;
    }

    .btn-checkout {
      margin-top: 1.25rem;
      background: linear-gradient(135deg, var(--accent-emerald), #059669);
      color: white;
      border: none;
      padding: 0.9rem;
      border-radius: 10px;
      font-weight: 600;
      font-size: 1rem;
      cursor: pointer;
      box-shadow: 0 4px 15px rgba(16, 185, 129, 0.35);
      transition: all 0.2s ease;
      display: flex;
      justify-content: center;
      align-items: center;
      gap: 0.5rem;
    }
    .btn-checkout:hover { transform: translateY(-1px); box-shadow: 0 6px 20px rgba(16, 185, 129, 0.5); }
    .btn-checkout:disabled { background: #334155; color: #64748B; cursor: not-allowed; box-shadow: none; transform: none; }

    .section-card {
      background: var(--bg-surface);
      border: 1px solid var(--border-color);
      border-radius: 16px;
      padding: 1.5rem;
      margin-bottom: 2rem;
    }
    .section-title { font-size: 1.15rem; font-weight: 700; margin-bottom: 1.25rem; display: flex; justify-content: space-between; align-items: center; }
    
    table { width: 100%; border-collapse: collapse; font-size: 0.85rem; }
    th { text-align: left; padding: 0.75rem 1rem; color: var(--text-muted); font-weight: 600; border-bottom: 1px solid var(--border-color); }
    td { padding: 0.75rem 1rem; border-bottom: 1px solid rgba(255, 255, 255, 0.04); font-family: var(--font-mono); }
    tr:hover td { background: rgba(255, 255, 255, 0.02); }

    .wallets-cards {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
      gap: 1.5rem;
    }
    .wallet-card {
      background: linear-gradient(135deg, rgba(30, 41, 59, 0.8), rgba(15, 23, 42, 0.9));
      border: 1px solid var(--border-color);
      border-radius: 14px;
      padding: 1.5rem;
      position: relative;
      overflow: hidden;
    }
    .wallet-card::after {
      content: '';
      position: absolute;
      top: -30px;
      right: -30px;
      width: 100px;
      height: 100px;
      border-radius: 50%;
      background: radial-gradient(circle, var(--border-accent), transparent 70%);
    }
    .wallet-card-title { font-size: 0.85rem; color: var(--text-secondary); text-transform: uppercase; letter-spacing: 0.05em; margin-bottom: 0.5rem; }
    .wallet-balance { font-size: 1.75rem; font-weight: 700; font-family: var(--font-mono); color: var(--text-primary); }
    .wallet-type-tag { font-size: 0.7rem; color: var(--accent-cyan); margin-top: 0.5rem; display: inline-block; background: rgba(6, 182, 212, 0.1); padding: 0.2rem 0.5rem; border-radius: 4px; }

    #toast {
      position: fixed;
      bottom: 2rem;
      right: 2rem;
      background: #1E293B;
      border: 1px solid var(--accent-emerald);
      color: white;
      padding: 1rem 1.5rem;
      border-radius: 10px;
      box-shadow: 0 10px 25px rgba(0,0,0,0.5);
      display: none;
      z-index: 1000;
      animation: slideIn 0.2s ease-out;
      font-size: 0.9rem;
    }
    @keyframes slideIn { from { transform: translateY(20px); opacity: 0; } to { transform: translateY(0); opacity: 1; } }
  </style>
</head>
<body>

  <header>
    <div class="logo-badge">
      <div class="logo-icon">Z</div>
      <div class="logo-text">
        <h1>ZAYNAHS ECOSYSTEM</h1>
        <p>● ONE ECOSYSTEM — ZERO BRANCHES (LOCAL ACTIVE)</p>
      </div>
    </div>
    <div class="header-badges">
      <div class="pill"><span class="dot-green"></span> DB: WAL ACTIVE (v8)</div>
      <div class="pill">DEVICE: TRUSTED</div>
      <div class="pill">CURRENCY: PKR (Rs)</div>
    </div>
  </header>

  <nav class="tabs-bar">
    <button class="tab-btn active" onclick="switchTab('pos')">🛒 POS Checkout</button>
    <button class="tab-btn" onclick="switchTab('inventory')">📦 Inventory & Stock</button>
    <button class="tab-btn" onclick="switchTab('wallets')">💰 Wallets & Cashier</button>
    <button class="tab-btn" onclick="switchTab('pnl')">📊 Financial P&L</button>
    <button class="tab-btn" onclick="switchTab('cctv')">📹 CCTV Surveillance</button>
    <button class="tab-btn" onclick="switchTab('backup')">🛡️ Backup Archive (.zynb)</button>
  </nav>

  <main>
    <!-- TAB 1: POS -->
    <div id="tab-pos" class="tab-content active">
      <div class="pos-grid">
        <div>
          <div class="catalog-header">
            <h2>Product Catalog</h2>
            <span id="catalog-count" class="pill">Loading...</span>
          </div>
          <div id="catalog-cards" class="catalog-cards">
          </div>
        </div>

        <div class="cart-panel">
          <div class="cart-title">
            <span>Active Cart</span>
            <button onclick="clearCart()" style="background:none; border:none; color:var(--accent-rose); cursor:pointer; font-size:0.75rem;">Clear All</button>
          </div>
          <div id="cart-items" class="cart-items">
            <p style="color:var(--text-muted); font-size:0.85rem; text-align:center; padding:2rem 0;">Cart is empty. Click a product to add.</p>
          </div>
          <div class="cart-summary">
            <div class="summary-row">
              <span>Subtotal</span>
              <span id="cart-subtotal" style="font-family:var(--font-mono);">Rs 0.00</span>
            </div>
            <div class="summary-row">
              <span>Tax (0% Inclusive)</span>
              <span style="font-family:var(--font-mono);">Rs 0.00</span>
            </div>
            <div class="summary-row total">
              <span>Total Amount</span>
              <span id="cart-total" style="font-family:var(--font-mono); color:var(--accent-emerald);">Rs 0.00</span>
            </div>
          </div>

          <div class="payment-selection">
            <div class="payment-title">Payment Account</div>
            <div class="wallet-radios" id="wallet-radios">
              <div class="wallet-opt selected" onclick="selectPayment('wal_cash', this)">Cash Drawer</div>
              <div class="wallet-opt" onclick="selectPayment('wal_bank', this)">HBL Bank</div>
              <div class="wallet-opt" onclick="selectPayment('wal_online', this)">Easypaisa</div>
            </div>
          </div>

          <button id="btn-checkout" class="btn-checkout" onclick="executeCheckout()" disabled>
            Complete Checkout (Rs 0)
          </button>
        </div>
      </div>
    </div>

    <!-- TAB 2: INVENTORY -->
    <div id="tab-inventory" class="tab-content">
      <div class="section-card">
        <div class="section-title">
          <span>Immutable Inventory Stock Ledger</span>
          <button onclick="loadInventory()" class="pill" style="cursor:pointer;">Refresh Stock</button>
        </div>
        <table>
          <thead>
            <tr>
              <th>SKU</th>
              <th>Product Name</th>
              <th>Cost Price</th>
              <th>Selling Price</th>
              <th>Stock On Hand</th>
              <th>Action</th>
            </tr>
          </thead>
          <tbody id="inventory-tbody">
          </tbody>
        </table>
      </div>
    </div>

    <!-- TAB 3: WALLETS -->
    <div id="tab-wallets" class="tab-content">
      <div class="section-card">
        <div class="section-title">
          <span>Authoritative Wallet Balances</span>
          <button onclick="loadWallets()" class="pill" style="cursor:pointer;">Refresh Balances</button>
        </div>
        <div id="wallets-cards" class="wallets-cards">
        </div>
      </div>
    </div>

    <!-- TAB 4: FINANCIAL P&L -->
    <div id="tab-pnl" class="tab-content">
      <div class="section-card">
        <div class="section-title">
          <span>Ledger-Derived Profit & Loss (Last 30 Days)</span>
          <button onclick="loadPnL()" class="pill" style="cursor:pointer;">Re-derive P&L</button>
        </div>
        <div class="wallets-cards" style="margin-top:1rem;">
          <div class="wallet-card">
            <div class="wallet-card-title">Gross Revenue</div>
            <div id="pnl-gross" class="wallet-balance" style="color:var(--accent-emerald);">Rs 0</div>
          </div>
          <div class="wallet-card">
            <div class="wallet-card-title">Cost of Goods Sold (COGS)</div>
            <div id="pnl-cogs" class="wallet-balance" style="color:var(--accent-rose);">Rs 0</div>
          </div>
          <div class="wallet-card">
            <div class="wallet-card-title">Net Operating Profit</div>
            <div id="pnl-net" class="wallet-balance" style="color:var(--accent-cyan);">Rs 0</div>
          </div>
        </div>
      </div>
    </div>

    <!-- TAB 5: CCTV -->
    <div id="tab-cctv" class="tab-content">
      <div class="section-card">
        <div class="section-title">
          <span>CCTV Surveillance Channels & Pipeline</span>
        </div>
        <table>
          <thead>
            <tr>
              <th>Channel Name</th>
              <th>Source Type</th>
              <th>RTSP Stream URI</th>
              <th>Recording Status</th>
            </tr>
          </thead>
          <tbody id="cctv-tbody">
          </tbody>
        </table>
      </div>
    </div>

    <!-- TAB 6: BACKUP -->
    <div id="tab-backup" class="tab-content">
      <div class="section-card">
        <div class="section-title">
          <span>Disaster Recovery & Encrypted Archive (.zynb)</span>
        </div>
        <p style="color:var(--text-secondary); margin-bottom:1.5rem; font-size:0.9rem;">
          Generates an atomic, portable `.zynb` binary archive containing database snapshot and file storage with cryptographic SHA-256 seal.
        </p>
        <button class="btn-checkout" style="width:260px;" onclick="triggerBackup()">Generate Full Backup (.zynb)</button>
        <div id="backup-result" style="margin-top:1.5rem; display:none;" class="pill"></div>
      </div>
    </div>
  </main>

  <div id="toast"></div>

  <script>
    let inventory = [];
    let wallets = [];
    let cart = {};
    let selectedWalletId = 'wal_cash';

    function formatMoney(minor) {
      return 'Rs ' + (minor / 100).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
    }

    function showToast(msg) {
      const t = document.getElementById('toast');
      t.innerText = msg;
      t.style.display = 'block';
      setTimeout(() => { t.style.display = 'none'; }, 3000);
    }

    function switchTab(tabId) {
      document.querySelectorAll('.tab-btn').forEach(b => b.classList.remove('active'));
      document.querySelectorAll('.tab-content').forEach(c => c.classList.remove('active'));
      event.currentTarget.classList.add('active');
      document.getElementById('tab-' + tabId).classList.add('active');

      if (tabId === 'inventory') loadInventory();
      if (tabId === 'wallets') loadWallets();
      if (tabId === 'pnl') loadPnL();
      if (tabId === 'cctv') loadCctv();
    }

    async function loadInventory() {
      const res = await fetch('/api/inventory');
      const data = await res.json();
      inventory = data.items;
      document.getElementById('catalog-count').innerText = inventory.length + ' Items in Catalog';

      const container = document.getElementById('catalog-cards');
      container.innerHTML = '';
      inventory.forEach(it => {
        const card = document.createElement('div');
        card.className = 'product-card';
        card.onclick = () => addToCart(it.id);
        card.innerHTML = `
          <div>
            <div class="sku-badge">\${it.sku}</div>
            <div class="product-title">\${it.name}</div>
          </div>
          <div class="product-meta">
            <div class="price-tag">\${formatMoney(it.selling_price)}</div>
            <div class="stock-tag">Stock: \${it.stock}</div>
          </div>
        `;
        container.appendChild(card);
      });

      const tbody = document.getElementById('inventory-tbody');
      tbody.innerHTML = '';
      inventory.forEach(it => {
        const tr = document.createElement('tr');
        tr.innerHTML = `
          <td style="color:var(--accent-cyan)">\${it.sku}</td>
          <td>\${it.name}</td>
          <td>\${formatMoney(it.cost_price)}</td>
          <td style="color:var(--accent-emerald)">\${formatMoney(it.selling_price)}</td>
          <td style="font-weight:700;">\${it.stock} units</td>
          <td><button onclick="stockIn('\${it.id}', 10)" class="qty-btn" style="width:auto; padding:0.2rem 0.6rem; font-size:0.75rem;">+ Restock 10</button></td>
        `;
        tbody.appendChild(tr);
      });
    }

    async function loadWallets() {
      const res = await fetch('/api/wallets');
      const data = await res.json();
      wallets = data.wallets;
      const container = document.getElementById('wallets-cards');
      container.innerHTML = '';
      wallets.forEach(w => {
        const card = document.createElement('div');
        card.className = 'wallet-card';
        card.innerHTML = `
          <div class="wallet-card-title">\${w.name}</div>
          <div class="wallet-balance">\${formatMoney(w.balance)}</div>
          <div class="wallet-type-tag">\${w.type} WALLET</div>
        `;
        container.appendChild(card);
      });
    }

    async function loadPnL() {
      const res = await fetch('/api/reports/pnl');
      const d = await res.json();
      document.getElementById('pnl-gross').innerText = formatMoney(d.gross_revenue);
      document.getElementById('pnl-cogs').innerText = formatMoney(d.cogs);
      document.getElementById('pnl-net').innerText = formatMoney(d.net_profit);
    }

    async function loadCctv() {
      const res = await fetch('/api/cctv/cameras');
      const d = await res.json();
      const tbody = document.getElementById('cctv-tbody');
      tbody.innerHTML = '';
      d.cameras.forEach(c => {
        const tr = document.createElement('tr');
        tr.innerHTML = `
          <td style="font-weight:600; color:var(--text-primary);">\${c.name}</td>
          <td style="color:var(--accent-cyan);">\${c.type.toUpperCase()}</td>
          <td style="font-family:var(--font-mono); font-size:0.75rem; color:var(--text-muted);">\${c.url}</td>
          <td><span class="pill" style="color:var(--accent-emerald);">● ACTIVE MONITOR</span></td>
        `;
        tbody.appendChild(tr);
      });
    }

    function addToCart(itemId) {
      const it = inventory.find(i => i.id === itemId);
      if (!it) return;
      if (cart[itemId]) {
        if (cart[itemId].qty < it.stock) {
          cart[itemId].qty++;
        } else {
          showToast('Insufficient stock available for ' + it.name);
          return;
        }
      } else {
        if (it.stock < 1) {
          showToast('Item is out of stock!');
          return;
        }
        cart[itemId] = { ...it, qty: 1 };
      }
      renderCart();
    }

    function changeQty(itemId, delta) {
      if (!cart[itemId]) return;
      cart[itemId].qty += delta;
      if (cart[itemId].qty <= 0) {
        delete cart[itemId];
      }
      renderCart();
    }

    function clearCart() {
      cart = {};
      renderCart();
    }

    function renderCart() {
      const container = document.getElementById('cart-items');
      const keys = Object.keys(cart);
      if (keys.length === 0) {
        container.innerHTML = '<p style="color:var(--text-muted); font-size:0.85rem; text-align:center; padding:2rem 0;">Cart is empty. Click a product to add.</p>';
        document.getElementById('cart-subtotal').innerText = 'Rs 0.00';
        document.getElementById('cart-total').innerText = 'Rs 0.00';
        document.getElementById('btn-checkout').disabled = true;
        document.getElementById('btn-checkout').innerText = 'Complete Checkout (Rs 0)';
        return;
      }

      container.innerHTML = '';
      let totalMinor = 0;

      keys.forEach(k => {
        const it = cart[k];
        const lineTotal = it.selling_price * it.qty;
        totalMinor += lineTotal;

        const row = document.createElement('div');
        row.className = 'cart-item';
        row.innerHTML = `
          <div>
            <div class="cart-item-name">\${it.name}</div>
            <div style="font-size:0.75rem; color:var(--accent-emerald); font-family:var(--font-mono);">\${formatMoney(lineTotal)}</div>
          </div>
          <div class="cart-item-qty">
            <button class="qty-btn" onclick="changeQty('\${k}', -1)">-</button>
            <span>\${it.qty}</span>
            <button class="qty-btn" onclick="changeQty('\${k}', 1)">+</button>
          </div>
        `;
        container.appendChild(row);
      });

      document.getElementById('cart-subtotal').innerText = formatMoney(totalMinor);
      document.getElementById('cart-total').innerText = formatMoney(totalMinor);
      document.getElementById('btn-checkout').disabled = false;
      document.getElementById('btn-checkout').innerText = 'Complete Checkout (' + formatMoney(totalMinor) + ')';
    }

    function selectPayment(walletId, el) {
      selectedWalletId = walletId;
      document.querySelectorAll('.wallet-opt').forEach(o => o.classList.remove('selected'));
      el.classList.add('selected');
    }

    async function executeCheckout() {
      const keys = Object.keys(cart);
      if (keys.length === 0) return;

      const items = keys.map(k => ({
        item_id: cart[k].id,
        item_name: cart[k].name,
        quantity: cart[k].qty,
        unit_price: cart[k].selling_price,
        cost_price: cart[k].cost_price
      }));

      let totalMinor = 0;
      items.forEach(i => { totalMinor += i.quantity * i.unit_price; });

      const payload = {
        items: items,
        payments: [{
          wallet_id: selectedWalletId,
          amount: totalMinor
        }],
        notes: 'Walk-in POS Sale'
      };

      try {
        const res = await fetch('/api/pos/checkout', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(payload)
        });
        const d = await res.json();
        if (d.success) {
          showToast('Sale Completed! Invoice: ' + d.invoice_number);
          cart = {};
          renderCart();
          await loadInventory();
          await loadWallets();
        } else {
          showToast('Error: ' + d.error);
        }
      } catch (err) {
        showToast('Checkout failed: ' + err);
      }
    }

    async function stockIn(itemId, qty) {
      try {
        const res = await fetch('/api/inventory/stock_in', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ item_id: itemId, quantity: qty })
        });
        const d = await res.json();
        if (d.success) {
          showToast('Restocked ' + qty + ' units. New Balance: ' + d.new_stock);
          await loadInventory();
        }
      } catch (e) {
        showToast('Restock failed: ' + e);
      }
    }

    async function triggerBackup() {
      const box = document.getElementById('backup-result');
      box.style.display = 'block';
      box.innerText = 'Creating binary archive (.zynb)...';
      try {
        const res = await fetch('/api/backup/create', { method: 'POST' });
        const d = await res.json();
        if (d.success) {
          box.innerHTML = '✓ Backup Created: <b>' + d.backup_id + '.zynb</b> (' + d.file_size_bytes + ' bytes)<br><span style="font-size:0.7rem; color:var(--accent-cyan);">SHA-256: ' + d.sha256 + '</span>';
          showToast('Backup archive created successfully!');
        }
      } catch (e) {
        box.innerText = 'Backup failed: ' + e;
      }
    }

    // Initial load
    loadInventory();
    loadWallets();
  </script>
</body>
</html>''';
}
