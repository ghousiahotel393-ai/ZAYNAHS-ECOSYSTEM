/// Repository for Universal POS Sales with atomic ledger checkout.
/// Enforces Rule 23-26, Rule 82: Sale + Items + Stock OUT + Wallet IN + Outbox + Audit in 1 atomic transaction.
/// Supports Rule 27-32: Multi-wallet split payments, returns, and historical price snapshots.
library sales_repository;

import 'dart:convert';
import 'package:core/core.dart';
import '../app_database.dart';
import 'inventory_repository.dart';
import 'wallet_repository.dart';

class PaymentAllocation {
  final String walletId;
  final Money amount;

  const PaymentAllocation({
    required this.walletId,
    required this.amount,
  });
}

class SaleItemInput {
  final String itemId;
  final String itemName;
  final int quantity;
  final Money unitPrice;
  final Money costPrice;
  final Map<String, dynamic> attributes;

  const SaleItemInput({
    required this.itemId,
    required this.itemName,
    required this.quantity,
    required this.unitPrice,
    required this.costPrice,
    this.attributes = const {},
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

class ReturnItemInput {
  final String itemId;
  final int quantity;
  final Money refundAmount;
  final Money costPrice;

  const ReturnItemInput({
    required this.itemId,
    required this.quantity,
    required this.refundAmount,
    required this.costPrice,
  });
}

class ReturnEntity {
  final String id;
  final String returnNumber;
  final String saleId;
  final Money totalRefund;
  final String? reason;
  final String actorId;
  final String deviceId;
  final DateTime createdAt;

  const ReturnEntity({
    required this.id,
    required this.returnNumber,
    required this.saleId,
    required this.totalRefund,
    this.reason,
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
  /// Guarantees all-or-nothing consistency across Sale, Items, Payments, Inventory, Wallet, Sync, and Audit.
  SaleEntity processSaleCheckout({
    required String invoiceNumber,
    required List<SaleItemInput> items,
    required Money discount,
    required Money tax,
    required Money paidAmount,
    String? walletId,
    List<PaymentAllocation>? paymentAllocations,
    String? customerId,
    required String actorId,
    required String deviceId,
  }) {
    if (items.isEmpty) {
      throw ArgumentError('Sale must contain at least one item');
    }

    final currency = discount.currency;

    // Normalize payment allocations
    final List<PaymentAllocation> allocations = [];
    if (paymentAllocations != null && paymentAllocations.isNotEmpty) {
      allocations.addAll(paymentAllocations);
    } else if (walletId != null && paidAmount.isPositive) {
      allocations.add(PaymentAllocation(walletId: walletId, amount: paidAmount));
    }

    // Verify split payment allocation invariant: sum(allocations) == paidAmount
    if (paidAmount.isPositive) {
      var allocatedTotal = Money.zero(currency);
      for (final a in allocations) {
        allocatedTotal = allocatedTotal + a.amount;
      }
      if (allocatedTotal.minorUnits != paidAmount.minorUnits) {
        throw ArgumentError(
          'Split payment allocation total (${allocatedTotal.format()}) must strictly equal paid amount (${paidAmount.format()})',
        );
      }
    }

    return db.transaction(() {
      final saleId = SaleId.generate().value;
      final now = DateTime.now().toUtc();

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
            unit_price_minor, cost_price_snapshot_minor, total_price_minor, attributes_json
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
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
            jsonEncode(item.attributes),
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

      // 4. Record Split Payments and Wallet Transactions
      for (final alloc in allocations) {
        final paymentId = 'spm_${EntityId.generateUuidV4()}';
        db.connection.execute(
          '''
          INSERT INTO sale_payments (id, sale_id, wallet_id, amount_minor, created_at)
          VALUES (?, ?, ?, ?, ?)
          ''',
          [paymentId, saleId, alloc.walletId, alloc.amount.minorUnits, now.toIso8601String()],
        );

        walletRepo.recordTransaction(
          walletId: alloc.walletId,
          type: 'SALE_PAYMENT',
          amount: alloc.amount,
          referenceId: saleId,
          actorId: actorId,
          deviceId: deviceId,
          notes: 'Payment for Sale #$invoiceNumber',
        );
      }

      // 5. Customer Ledger Update if due exists
      if (customerId != null && dueAmount.isPositive) {
        db.connection.execute(
          '''
          UPDATE customers SET balance_minor = balance_minor + ?, updated_at = ? WHERE id = ?
          ''',
          [dueAmount.minorUnits, now.toIso8601String(), customerId],
        );
      }

      // 6. Enqueue durable sync event into sync_outbox
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

      // 7. Record Audit Log
      final auditId = 'aud_${EntityId.generateUuidV4()}';
      final auditDetails = jsonEncode({
        'invoiceNumber': invoiceNumber,
        'total': grandTotal.format(),
        'itemsCount': items.length,
        'allocations': allocations.length,
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

  /// Processes an authoritative return against an existing sale.
  /// Atomically inserts return, return_items, return_payments, restores inventory (Stock IN),
  /// debits wallets (REFUND), and records audit and sync events.
  ReturnEntity processReturn({
    required String saleId,
    required String returnNumber,
    required List<ReturnItemInput> items,
    required List<PaymentAllocation> refundAllocations,
    String? reason,
    required String actorId,
    required String deviceId,
  }) {
    if (items.isEmpty) {
      throw ArgumentError('Return must contain at least one item');
    }

    final currency = items.first.refundAmount.currency;
    var totalRefund = Money.zero(currency);
    for (final it in items) {
      totalRefund = totalRefund + it.refundAmount;
    }

    // Verify refund allocation invariant
    var totalAllocatedRefund = Money.zero(currency);
    for (final a in refundAllocations) {
      totalAllocatedRefund = totalAllocatedRefund + a.amount;
    }

    if (totalAllocatedRefund.minorUnits != totalRefund.minorUnits) {
      throw ArgumentError(
        'Refund allocation total (${totalAllocatedRefund.format()}) must match total items refund (${totalRefund.format()})',
      );
    }

    return db.transaction(() {
      final returnId = 'ret_${EntityId.generateUuidV4()}';
      final now = DateTime.now().toUtc();

      // 1. Insert Return record
      db.connection.execute(
        '''
        INSERT INTO returns (
          id, return_number, sale_id, total_refund_minor, reason,
          actor_id, device_id, created_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ''',
        [
          returnId,
          returnNumber,
          saleId,
          totalRefund.minorUnits,
          reason,
          actorId,
          deviceId,
          now.toIso8601String(),
        ],
      );

      // 2. Insert Return Items & Stock IN inventory movements
      for (final it in items) {
        final rtiId = 'rti_${EntityId.generateUuidV4()}';
        db.connection.execute(
          '''
          INSERT INTO return_items (id, return_id, item_id, quantity, refund_amount_minor)
          VALUES (?, ?, ?, ?, ?)
          ''',
          [rtiId, returnId, it.itemId, it.quantity, it.refundAmount.minorUnits],
        );

        // Positive movement = Stock IN (inventory restored)
        inventoryRepo.recordMovement(
          itemId: it.itemId,
          type: 'RETURN',
          quantity: it.quantity,
          costPrice: it.costPrice,
          referenceId: returnId,
          actorId: actorId,
          deviceId: deviceId,
          notes: 'Return #$returnNumber for Sale #$saleId',
        );
      }

      // 3. Record Refund payment allocations & Wallet REFUND transactions
      for (final a in refundAllocations) {
        final rpmId = 'rpm_${EntityId.generateUuidV4()}';
        db.connection.execute(
          '''
          INSERT INTO return_payments (id, return_id, wallet_id, amount_minor, created_at)
          VALUES (?, ?, ?, ?, ?)
          ''',
          [rpmId, returnId, a.walletId, a.amount.minorUnits, now.toIso8601String()],
        );

        // Wallet REFUND = Money OUT from the respective wallet
        walletRepo.recordTransaction(
          walletId: a.walletId,
          type: 'REFUND',
          amount: a.amount,
          referenceId: returnId,
          actorId: actorId,
          deviceId: deviceId,
          notes: 'Refund for Return #$returnNumber',
        );
      }

      // 4. Audit Log
      final auditId = 'aud_${EntityId.generateUuidV4()}';
      final auditDetails = jsonEncode({
        'returnNumber': returnNumber,
        'saleId': saleId,
        'refundAmount': totalRefund.format(),
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
          'RETURN_PROCESSED',
          actorId,
          deviceId,
          'return',
          returnId,
          auditDetails,
          '',
          'hash_$returnId',
        ],
      );

      // 5. Sync Outbox Event
      final eventId = EventId.generate().value;
      final payload = jsonEncode({
        'returnId': returnId,
        'returnNumber': returnNumber,
        'saleId': saleId,
        'totalRefundMinor': totalRefund.minorUnits,
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
          'returns',
          returnId,
          payload,
          deviceId,
          'PENDING',
          0,
          now.toIso8601String(),
        ],
      );

      return ReturnEntity(
        id: returnId,
        returnNumber: returnNumber,
        saleId: saleId,
        totalRefund: totalRefund,
        reason: reason,
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

  /// Retrieves a return by ID.
  ReturnEntity? getReturnById(String returnId) {
    final rs = db.connection.select('SELECT * FROM returns WHERE id = ?', [returnId]);
    if (rs.isEmpty) return null;
    final row = rs.first;
    const curr = Currency.pkr;
    return ReturnEntity(
      id: row['id'] as String,
      returnNumber: row['return_number'] as String,
      saleId: row['sale_id'] as String,
      totalRefund: Money.fromMinorUnits(row['total_refund_minor'] as int, curr),
      reason: row['reason'] as String?,
      actorId: row['actor_id'] as String,
      deviceId: row['device_id'] as String,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }
}
