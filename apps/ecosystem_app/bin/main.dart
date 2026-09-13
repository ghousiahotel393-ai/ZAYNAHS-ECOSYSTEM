import 'dart:convert';
import 'dart:io';
import 'package:backup/backup.dart';
import 'package:cctv/cctv.dart';
import 'package:core/core.dart';
import 'package:database/database.dart';
import 'package:pos/pos.dart';
import 'package:storage/storage.dart';
import 'package:sync/sync.dart';

import '../lib/src/dashboard_html.dart';
import '../lib/src/seed_data.dart';

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

  // Seed baseline demo enterprise data if not already present
  seedBaselineData(db, invRepo, walletRepo, cctvDiscovery);

  // Start HTTP Server for Web POS & Local Dashboard
  final server = await HttpServer.bind(host, port);

  // ignore: avoid_print
  print('\n   ▲ ZAYNAHS ECOSYSTEM 1.0.0 (Local Dev Server)');
  // ignore: avoid_print
  print('   - Local:        http://localhost:$port/');
  // ignore: avoid_print
  print('   - Network:      http://$host:$port/');
  // ignore: avoid_print
  print('   - Database:     $dbPath (SQLite WAL, Schema v8)');
  // ignore: avoid_print
  print('   - Architecture: Strictly ONE ECOSYSTEM — ZERO BRANCHES');
  // ignore: avoid_print
  print('\n   ✓ Server ready. Open http://localhost:$port/ in your browser.');
  // ignore: avoid_print
  print('   ✓ Press Ctrl+C to stop.\n');

  await for (HttpRequest req in server) {
    final sw = Stopwatch()..start();
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
        req.response.write(renderHtmlDashboard());
        await req.response.close();
        // ignore: avoid_print
        print('   GET $path 200 in ${sw.elapsedMilliseconds}ms');
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
        // ignore: avoid_print
        print('   GET $path 200 in ${sw.elapsedMilliseconds}ms');
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
