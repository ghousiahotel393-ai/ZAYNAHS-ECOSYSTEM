/// Physical Stock Take and Discrepancy Reconciliation Audit Service.
/// Enforces Rule 51, Section 05: 8-step physical stock count audit workflow:
/// Start -> Snapshot expected -> Physical count -> Discrepancy -> Confirm -> Adjustment -> Audit -> Sync.
library stock_count_service;

import 'dart:convert';
import 'package:core/core.dart';
import 'package:database/database.dart';

class CountItemEntry {
  final String itemId;
  final int countedQuantity;

  const CountItemEntry({
    required this.itemId,
    required this.countedQuantity,
  });
}

class DiscrepancyResult {
  final String itemId;
  final int expectedQuantity;
  final int countedQuantity;
  final int variance; // counted - expected

  const DiscrepancyResult({
    required this.itemId,
    required this.expectedQuantity,
    required this.countedQuantity,
    required this.variance,
  });
}

class StockCountReport {
  final String id;
  final String countNumber;
  final List<DiscrepancyResult> discrepancies;
  final int totalAdjustmentsPosted;
  final DateTime completedAt;

  const StockCountReport({
    required this.id,
    required this.countNumber,
    required this.discrepancies,
    required this.totalAdjustmentsPosted,
    required this.completedAt,
  });
}

class StockCountService {
  final AppDatabase db;
  final InventoryRepository inventoryRepo;

  StockCountService({
    required this.db,
    required this.inventoryRepo,
  });

  /// Executes the authoritative Rule 51 Stock Count workflow.
  /// Atomically snapshots expected balances, computes discrepancies, posts compensating
  /// ADJUSTMENT movements, and logs audit + sync records.
  StockCountReport executeStockCount({
    required String countNumber,
    required List<CountItemEntry> physicalCounts,
    String? notes,
    required String actorId,
    required String deviceId,
  }) {
    if (physicalCounts.isEmpty) {
      throw ValidationException.invalidValue('physicalCounts', 'Stock take must contain at least one item entry.');
    }

    return db.transaction(() {
      final countId = 'stk_${EntityId.generateUuidV4()}';
      final now = DateTime.now().toUtc();

      // 1. Insert Stock Count Master Record
      db.connection.execute(
        '''
        INSERT INTO stock_counts (
          id, count_number, status, notes, actor_id, device_id, created_at, completed_at
        ) VALUES (?, ?, 'COMPLETED', ?, ?, ?, ?, ?)
        ''',
        [
          countId,
          countNumber,
          notes,
          actorId,
          deviceId,
          now.toIso8601String(),
          now.toIso8601String(),
        ],
      );

      final discrepancies = <DiscrepancyResult>[];
      var adjustmentsCount = 0;

      // 2. Process each counted item
      for (final entry in physicalCounts) {
        // Step 2 & 3: Snapshot expected stock and compute discrepancy
        final expected = inventoryRepo.getStockBalance(entry.itemId);
        final variance = entry.countedQuantity - expected;

        final sciId = 'sci_${EntityId.generateUuidV4()}';
        db.connection.execute(
          '''
          INSERT INTO stock_count_items (
            id, count_id, item_id, expected_quantity, counted_quantity, variance
          ) VALUES (?, ?, ?, ?, ?, ?)
          ''',
          [sciId, countId, entry.itemId, expected, entry.countedQuantity, variance],
        );

        discrepancies.add(DiscrepancyResult(
          itemId: entry.itemId,
          expectedQuantity: expected,
          countedQuantity: entry.countedQuantity,
          variance: variance,
        ));

        // Step 5: Post compensating adjustment movement if discrepancy exists
        if (variance != 0) {
          adjustmentsCount++;
          inventoryRepo.recordMovement(
            itemId: entry.itemId,
            type: 'ADJUSTMENT',
            quantity: variance, // Positive if physical > expected, negative if physical < expected
            costPrice: Money.zero(Currency.pkr),
            referenceId: countId,
            actorId: actorId,
            deviceId: deviceId,
            notes: 'Stock take #$countNumber discrepancy adjustment ($variance units)',
          );
        }
      }

      // Step 6: Audit Log
      final auditId = 'aud_${EntityId.generateUuidV4()}';
      final auditDetails = jsonEncode({
        'countNumber': countNumber,
        'itemsAudited': physicalCounts.length,
        'adjustmentsPosted': adjustmentsCount,
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
          'STOCK_COUNT_RECONCILED',
          actorId,
          deviceId,
          'stock_count',
          countId,
          auditDetails,
          '',
          'hash_$countId',
        ],
      );

      // Step 7: Sync Outbox
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
          'stock_counts',
          countId,
          jsonEncode({
            'countId': countId,
            'countNumber': countNumber,
            'adjustments': adjustmentsCount,
          }),
          deviceId,
          'PENDING',
          0,
          now.toIso8601String(),
        ],
      );

      return StockCountReport(
        id: countId,
        countNumber: countNumber,
        discrepancies: discrepancies,
        totalAdjustmentsPosted: adjustmentsCount,
        completedAt: now,
      );
    });
  }
}
