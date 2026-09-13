/// Procurement and Supplier Payables Ledger Service.
/// Enforces Rule 53, Section 04: Restock movements (Stock IN), purchase orders,
/// and supplier balance derivation (Purchases - Payments).
library procurement_service;

import 'dart:convert';
import 'package:core/core.dart';
import 'package:database/database.dart';

class PurchaseOrderItemInput {
  final String itemId;
  final int quantity;
  final Money unitCost;

  const PurchaseOrderItemInput({
    required this.itemId,
    required this.quantity,
    required this.unitCost,
  });

  Money get lineTotal => unitCost * quantity;
}

class PurchaseOrderResult {
  final String id;
  final String poNumber;
  final String supplierId;
  final Money totalAmount;
  final Money paidAmount;
  final Money dueToSupplier;
  final String status;
  final DateTime createdAt;

  const PurchaseOrderResult({
    required this.id,
    required this.poNumber,
    required this.supplierId,
    required this.totalAmount,
    required this.paidAmount,
    required this.dueToSupplier,
    required this.status,
    required this.createdAt,
  });
}

class ProcurementService {
  final AppDatabase db;
  final InventoryRepository inventoryRepo;
  final WalletRepository walletRepo;

  ProcurementService({
    required this.db,
    required this.inventoryRepo,
    required this.walletRepo,
  });

  /// Registers a new vendor/supplier.
  void createSupplier({
    required String id,
    required String name,
    String? phone,
    String? email,
    String? company,
  }) {
    final now = DateTime.now().toUtc();
    db.connection.execute(
      '''
      INSERT INTO suppliers (id, name, phone, email, company, balance_minor, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, 0, ?, ?)
      ''',
      [id, name, phone, email, company, now.toIso8601String(), now.toIso8601String()],
    );
  }

  /// Receives goods from supplier, logs Stock IN movements, updates supplier payable, and disburses payment.
  PurchaseOrderResult receivePurchaseOrder({
    required String poNumber,
    required String supplierId,
    required List<PurchaseOrderItemInput> items,
    required Money paidAmount,
    String? walletId,
    required String actorId,
    required String deviceId,
  }) {
    if (items.isEmpty) {
      throw ValidationException.invalidValue('items', 'Purchase order must have at least one line item.');
    }

    final currency = items.first.unitCost.currency;
    var totalAmount = Money.zero(currency);
    for (final it in items) {
      totalAmount = totalAmount + it.lineTotal;
    }

    final dueToSupplier = totalAmount > paidAmount ? totalAmount - paidAmount : Money.zero(currency);

    return db.transaction(() {
      final poId = 'po_${EntityId.generateUuidV4()}';
      final now = DateTime.now().toUtc();

      // 1. Insert Purchase Order
      db.connection.execute(
        '''
        INSERT INTO purchase_orders (
          id, po_number, supplier_id, total_minor, paid_minor, status,
          actor_id, device_id, created_at
        ) VALUES (?, ?, ?, ?, ?, 'RECEIVED', ?, ?, ?)
        ''',
        [
          poId,
          poNumber,
          supplierId,
          totalAmount.minorUnits,
          paidAmount.minorUnits,
          actorId,
          deviceId,
          now.toIso8601String(),
        ],
      );

      // 2. Insert PO Items and record Stock IN inventory movements
      for (final it in items) {
        final poiId = 'poi_${EntityId.generateUuidV4()}';
        db.connection.execute(
          '''
          INSERT INTO purchase_order_items (id, po_id, item_id, quantity, unit_cost_minor)
          VALUES (?, ?, ?, ?, ?)
          ''',
          [poiId, poId, it.itemId, it.quantity, it.unitCost.minorUnits],
        );

        inventoryRepo.recordMovement(
          itemId: it.itemId,
          type: 'PURCHASE',
          quantity: it.quantity, // Positive = Stock IN
          costPrice: it.unitCost,
          referenceId: poId,
          actorId: actorId,
          deviceId: deviceId,
          notes: 'Restock via PO #$poNumber',
        );
      }

      // 3. Update Supplier Payable Balance (Rule 53)
      if (dueToSupplier.isPositive) {
        db.connection.execute(
          '''
          UPDATE suppliers
          SET balance_minor = balance_minor + ?, updated_at = ?
          WHERE id = ?
          ''',
          [dueToSupplier.minorUnits, now.toIso8601String(), supplierId],
        );
      }

      // 4. Wallet Outflow if paid on receipt
      if (paidAmount.isPositive && walletId != null) {
        walletRepo.recordTransaction(
          walletId: walletId,
          type: 'EXPENSE',
          amount: paidAmount,
          referenceId: poId,
          actorId: actorId,
          deviceId: deviceId,
          notes: 'Supplier Payment for PO #$poNumber',
        );
      }

      // 5. Audit Log
      final auditId = 'aud_${EntityId.generateUuidV4()}';
      final auditDetails = jsonEncode({
        'poNumber': poNumber,
        'supplierId': supplierId,
        'totalAmount': totalAmount.format(),
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
          'PO_RECEIVED',
          actorId,
          deviceId,
          'purchase_order',
          poId,
          auditDetails,
          '',
          'hash_$poId',
        ],
      );

      // 6. Sync Outbox
      final eventId = EventId.generate().value;
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
          'purchase_orders',
          poId,
          jsonEncode({
            'poId': poId,
            'poNumber': poNumber,
            'totalMinor': totalAmount.minorUnits,
          }),
          deviceId,
          'PENDING',
          0,
          now.toIso8601String(),
        ],
      );

      return PurchaseOrderResult(
        id: poId,
        poNumber: poNumber,
        supplierId: supplierId,
        totalAmount: totalAmount,
        paidAmount: paidAmount,
        dueToSupplier: dueToSupplier,
        status: 'RECEIVED',
        createdAt: now,
      );
    });
  }

  /// Derives authoritative supplier payable balance.
  Money getSupplierPayable(String supplierId, [Currency currency = Currency.pkr]) {
    final rs = db.connection.select(
      'SELECT balance_minor FROM suppliers WHERE id = ?',
      [supplierId],
    );
    if (rs.isEmpty) return Money.zero(currency);
    final balanceMinor = rs.first['balance_minor'] as int? ?? 0;
    return Money.fromMinorUnits(balanceMinor, currency);
  }
}
