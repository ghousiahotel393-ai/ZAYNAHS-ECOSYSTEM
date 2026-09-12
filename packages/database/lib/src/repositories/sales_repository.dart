/// Repository for Universal POS Sales with atomic ledger checkout.
/// Enforces Rule 23-26, Rule 82: Sale + Items + Stock OUT + Wallet IN + Outbox + Audit in 1 atomic transaction.
library sales_repository;

import 'dart:convert';
import 'package:core/core.dart';
import '../app_database.dart';
import 'inventory_repository.dart';
import 'wallet_repository.dart';

class SaleItemInput {
  final String itemId;
  final String itemName;
  final int quantity;
  final Money unitPrice;
  final Money costPrice;

  const SaleItemInput({
    required this.itemId,
    required this.itemName,
    required this.quantity,
    required this.unitPrice,
    required this.costPrice,
  });

  Money get totalPrice => unitPrice * quantity;
}

class SaleEntity {
  final String id;
  final String invoiceNumber;
  final Money subtotal;
  final Money discount;
  final Money tax;
  final Money grandTotal;
  final Money paidAmount;
  final Money dueAmount;
  final String paymentStatus; // PAID, PARTIAL, UNPAID
  final String? customerId;
  final String actorId;
  final String deviceId;
  final DateTime createdAt;

  const SaleEntity({
    required this.id,
    required this.invoiceNumber,
    required this.subtotal,
    required this.discount,
    required this.tax,
    required this.grandTotal,
    required this.paidAmount,
    required this.dueAmount,
    required this.paymentStatus,
    this.customerId,
    required this.actorId,
    required this.deviceId,
    required this.createdAt,
  });
}

class SalesRepository {
  final AppDatabase db;
  final InventoryRepository inventoryRepo;
  final WalletRepository walletRepo;

  SalesRepository({
    required this.db,
    required this.inventoryRepo,
    required this.walletRepo,
  });

  /// Executes an atomic POS checkout.
  /// Guarantees all-or-nothing consistency across Sale, Items, Inventory, Wallet, Sync, and Audit.
  SaleEntity processSaleCheckout({
    required String invoiceNumber,
    required List<SaleItemInput> items,
    required Money discount,
    required Money tax,
    required Money paidAmount,
    required String walletId,
    String? customerId,
    required String actorId,
    required String deviceId,
  }) {
    if (items.isEmpty) {
      throw ArgumentError('Sale must contain at least one item');
    }

    return db.transaction(() {
      final saleId = SaleId.generate().value;
      final now = DateTime.now().toUtc();
      final currency = discount.currency;

      // 1. Calculate subtotal & grand total
      var subtotal = Money.zero(currency);
      for (final item in items) {
        subtotal = subtotal + item.totalPrice;
      }
      final grandTotal = (subtotal - discount) + tax;
      final dueAmount = grandTotal > paidAmount ? grandTotal - paidAmount : Money.zero(currency);

      final paymentStatus = paidAmount >= grandTotal
          ? 'PAID'
          : (paidAmount.isPositive ? 'PARTIAL' : 'UNPAID');

      // 2. Insert Sale record
      db.connection.execute(
        '''
        INSERT INTO sales (
          id, invoice_number, subtotal_minor, discount_minor, tax_minor,
          grand_total_minor, paid_amount_minor, due_amount_minor,
          payment_status, customer_id, actor_id, device_id, created_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''',
        [
          saleId,
          invoiceNumber,
          subtotal.minorUnits,
          discount.minorUnits,
          tax.minorUnits,
          grandTotal.minorUnits,
          paidAmount.minorUnits,
          dueAmount.minorUnits,
          paymentStatus,
          customerId,
          actorId,
          deviceId,
          now.toIso8601String(),
        ],
      );

      // 3. Insert Sale Items & Record Stock OUT movements
      for (final item in items) {
        final lineId = 'sli_${EntityId.generateUuidV4()}';
        db.connection.execute(
          '''
          INSERT INTO sale_items (
            id, sale_id, item_id, item_name_snapshot, quantity,
            unit_price_minor, cost_price_snapshot_minor, total_price_minor
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
          ''',
          [
            lineId,
            saleId,
            item.itemId,
            item.itemName,
            item.quantity,
            item.unitPrice.minorUnits,
            item.costPrice.minorUnits,
            item.totalPrice.minorUnits,
          ],
        );

        // Deduct inventory via immutable movement (Negative quantity = Stock OUT)
        inventoryRepo.recordMovement(
          itemId: item.itemId,
          type: 'SALE',
          quantity: -item.quantity,
          costPrice: item.costPrice,
          referenceId: saleId,
          actorId: actorId,
          deviceId: deviceId,
          notes: 'POS Sale #$invoiceNumber',
        );
      }

      // 4. Record Wallet transaction if paidAmount > 0
      if (paidAmount.isPositive) {
        walletRepo.recordTransaction(
          walletId: walletId,
          type: 'SALE_PAYMENT',
          amount: paidAmount,
          referenceId: saleId,
          actorId: actorId,
          deviceId: deviceId,
          notes: 'Payment for Sale #$invoiceNumber',
        );
      }

      // 5. Enqueue durable sync event into sync_outbox
      final eventId = EventId.generate().value;
      final payload = jsonEncode({
        'saleId': saleId,
        'invoiceNumber': invoiceNumber,
        'grandTotalMinor': grandTotal.minorUnits,
        'paidAmountMinor': paidAmount.minorUnits,
        'actorId': actorId,
        'deviceId': deviceId,
        'timestamp': now.toIso8601String(),
      });

      db.connection.execute(
        '''
        INSERT INTO sync_outbox (
          id, event_type, entity_table, entity_id, payload_json,
          device_id, status, retry_count, created_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''',
        [
          eventId,
          'INSERT',
          'sales',
          saleId,
          payload,
          deviceId,
          'PENDING',
          0,
          now.toIso8601String(),
        ],
      );

      // 6. Record Audit Log
      final auditId = 'aud_${EntityId.generateUuidV4()}';
      final auditDetails = jsonEncode({
        'invoiceNumber': invoiceNumber,
        'total': grandTotal.format(),
        'itemsCount': items.length,
      });

      db.connection.execute(
        '''
        INSERT INTO audit_logs (
          id, timestamp, level, action, actor_id, device_id,
          entity_type, entity_id, details_json, previous_hash, entry_hash
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''',
        [
          auditId,
          now.toIso8601String(),
          'AUDIT',
          'SALE_CREATED',
          actorId,
          deviceId,
          'sale',
          saleId,
          auditDetails,
          '',
          'hash_$saleId',
        ],
      );

      return SaleEntity(
        id: saleId,
        invoiceNumber: invoiceNumber,
        subtotal: subtotal,
        discount: discount,
        tax: tax,
        grandTotal: grandTotal,
        paidAmount: paidAmount,
        dueAmount: dueAmount,
        paymentStatus: paymentStatus,
        customerId: customerId,
        actorId: actorId,
        deviceId: deviceId,
        createdAt: now,
      );
    });
  }

  /// Retrieves a sale by ID.
  SaleEntity? getSaleById(String saleId) {
    final rs = db.connection.select('SELECT * FROM sales WHERE id = ?', [saleId]);
    if (rs.isEmpty) return null;
    final row = rs.first;
    const curr = Currency.pkr;
    return SaleEntity(
      id: row['id'] as String,
      invoiceNumber: row['invoice_number'] as String,
      subtotal: Money.fromMinorUnits(row['subtotal_minor'] as int, curr),
      discount: Money.fromMinorUnits(row['discount_minor'] as int, curr),
      tax: Money.fromMinorUnits(row['tax_minor'] as int, curr),
      grandTotal: Money.fromMinorUnits(row['grand_total_minor'] as int, curr),
      paidAmount: Money.fromMinorUnits(row['paid_amount_minor'] as int, curr),
      dueAmount: Money.fromMinorUnits(row['due_amount_minor'] as int, curr),
      paymentStatus: row['payment_status'] as String,
      customerId: row['customer_id'] as String?,
      actorId: row['actor_id'] as String,
      deviceId: row['device_id'] as String,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }
}
