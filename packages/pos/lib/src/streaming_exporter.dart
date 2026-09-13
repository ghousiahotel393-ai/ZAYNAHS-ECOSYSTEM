/// Memory-safe streaming CSV exporter for the Zaynahs Ecosystem.
/// Enforces Rule 99, 105: Streams data row-by-row in bounded batches without
/// buffering hundreds of thousands of records into RAM.
library streaming_exporter;

import 'package:database/database.dart';

class StreamingExporter {
  final AppDatabase db;

  StreamingExporter({required this.db});

  /// Properly quotes and escapes a single CSV field value.
  static String escapeCsv(dynamic value) {
    if (value == null) return '';
    final str = value.toString();
    if (str.contains(',') || str.contains('"') || str.contains('\n') || str.contains('\r')) {
      return '"${str.replaceAll('"', '""')}"';
    }
    return str;
  }

  /// Streams sales ledger rows in memory-bounded batches.
  Stream<String> streamSalesCsv({int batchSize = 100}) async* {
    // 1. Yield Header
    yield 'ID,InvoiceNumber,SubtotalMinor,DiscountMinor,TaxMinor,GrandTotalMinor,PaidMinor,DueMinor,Status,CreatedAt\n';

    var offset = 0;
    while (true) {
      final rows = db.connection.select(
        '''
        SELECT id, invoice_number, subtotal_minor, discount_minor, tax_minor,
               grand_total_minor, paid_amount_minor, due_amount_minor, payment_status, created_at
        FROM sales
        ORDER BY created_at ASC
        LIMIT ? OFFSET ?
        ''',
        [batchSize, offset],
      );

      if (rows.isEmpty) break;

      final buffer = StringBuffer();
      for (final r in rows) {
        buffer.write('${escapeCsv(r['id'])},'
            '${escapeCsv(r['invoice_number'])},'
            '${r['subtotal_minor']},'
            '${r['discount_minor']},'
            '${r['tax_minor']},'
            '${r['grand_total_minor']},'
            '${r['paid_amount_minor']},'
            '${r['due_amount_minor']},'
            '${escapeCsv(r['payment_status'])},'
            '${escapeCsv(r['created_at'])}\n');
      }

      yield buffer.toString();
      offset += rows.length;

      if (rows.length < batchSize) break;
    }
  }

  /// Streams immutable inventory movements in memory-bounded batches.
  Stream<String> streamInventoryMovementsCsv({int batchSize = 100}) async* {
    yield 'ID,ItemId,Type,Quantity,CostMinor,PreviousBalance,NewBalance,ReferenceId,ActorId,DeviceId,CreatedAt\n';

    var offset = 0;
    while (true) {
      final rows = db.connection.select(
        '''
        SELECT id, item_id, type, quantity, cost_price_minor,
               previous_balance, new_balance, reference_id, actor_id, device_id, created_at
        FROM inventory_movements
        ORDER BY created_at ASC
        LIMIT ? OFFSET ?
        ''',
        [batchSize, offset],
      );

      if (rows.isEmpty) break;

      final buffer = StringBuffer();
      for (final r in rows) {
        buffer.write('${escapeCsv(r['id'])},'
            '${escapeCsv(r['item_id'])},'
            '${escapeCsv(r['type'])},'
            '${r['quantity']},'
            '${r['cost_price_minor']},'
            '${r['previous_balance']},'
            '${r['new_balance']},'
            '${escapeCsv(r['reference_id'])},'
            '${escapeCsv(r['actor_id'])},'
            '${escapeCsv(r['device_id'])},'
            '${escapeCsv(r['created_at'])}\n');
      }

      yield buffer.toString();
      offset += rows.length;

      if (rows.length < batchSize) break;
    }
  }

  /// Streams immutable wallet transactions in memory-bounded batches.
  Stream<String> streamWalletTransactionsCsv({int batchSize = 100}) async* {
    yield 'ID,WalletId,Type,AmountMinor,PreviousBalance,NewBalance,ReferenceId,ActorId,DeviceId,CreatedAt\n';

    var offset = 0;
    while (true) {
      final rows = db.connection.select(
        '''
        SELECT id, wallet_id, type, amount_minor, previous_balance,
               new_balance, reference_id, actor_id, device_id, created_at
        FROM wallet_transactions
        ORDER BY created_at ASC
        LIMIT ? OFFSET ?
        ''',
        [batchSize, offset],
      );

      if (rows.isEmpty) break;

      final buffer = StringBuffer();
      for (final r in rows) {
        buffer.write('${escapeCsv(r['id'])},'
            '${escapeCsv(r['wallet_id'])},'
            '${escapeCsv(r['type'])},'
            '${r['amount_minor']},'
            '${r['previous_balance']},'
            '${r['new_balance']},'
            '${escapeCsv(r['reference_id'])},'
            '${escapeCsv(r['actor_id'])},'
            '${escapeCsv(r['device_id'])},'
            '${escapeCsv(r['created_at'])}\n');
      }

      yield buffer.toString();
      offset += rows.length;

      if (rows.length < batchSize) break;
    }
  }
}
