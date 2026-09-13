/// Cash Register Shift Management and Day-End Closeout (Z-Reports).
/// Enforces Rule 94, Section 03: Opening float tracking, shift cash reconciliations,
/// variance calculations, and thermal Z-Report printout layouts.
library shift_manager;

import 'dart:convert';
import 'package:core/core.dart';
import 'package:database/database.dart';
import 'thermal_printer.dart';

class ShiftSummary {
  final String id;
  final String shiftNumber;
  final String cashierId;
  final String deviceId;
  final Money openingFloat;
  final Money cashSales;
  final Money cashRefunds;
  final Money cashExpenses;
  final Money expectedCash;
  final DateTime openedAt;

  const ShiftSummary({
    required this.id,
    required this.shiftNumber,
    required this.cashierId,
    required this.deviceId,
    required this.openingFloat,
    required this.cashSales,
    required this.cashRefunds,
    required this.cashExpenses,
    required this.expectedCash,
    required this.openedAt,
  });
}

class ShiftCloseoutResult {
  final ShiftSummary summary;
  final Money countedCash;
  final Money variance;
  final DateTime closedAt;
  final List<int> zReportReceiptBytes;

  const ShiftCloseoutResult({
    required this.summary,
    required this.countedCash,
    required this.variance,
    required this.closedAt,
    required this.zReportReceiptBytes,
  });
}

class ShiftManager {
  final AppDatabase db;

  ShiftManager({required this.db});

  /// Opens a new register shift with an opening cash float.
  String openShift({
    required String shiftNumber,
    required String cashierId,
    required String deviceId,
    required Money openingFloat,
    String? notes,
  }) {
    // Check if an active open shift exists on this device
    final openShifts = db.connection.select(
      "SELECT id FROM register_shifts WHERE device_id = ? AND status = 'OPEN'",
      [deviceId],
    );
    if (openShifts.isNotEmpty) {
      throw ValidationException.invalidValue(
        'deviceId',
        'Device already has an active OPEN shift (${openShifts.first['id']}). Close it before opening a new shift.',
      );
    }

    final shiftId = 'shf_${EntityId.generateUuidV4()}';
    final now = DateTime.now().toUtc();

    db.connection.execute(
      '''
      INSERT INTO register_shifts (
        id, shift_number, cashier_id, device_id, opening_float_minor,
        expected_cash_minor, cash_variance_minor, total_sales_minor,
        status, opened_at, notes
      ) VALUES (?, ?, ?, ?, ?, ?, 0, 0, 'OPEN', ?, ?)
      ''',
      [
        shiftId,
        shiftNumber,
        cashierId,
        deviceId,
        openingFloat.minorUnits,
        openingFloat.minorUnits,
        now.toIso8601String(),
        notes,
      ],
    );

    return shiftId;
  }

  /// Calculates authoritative shift summary and expected cash from immutable ledgers.
  ShiftSummary getShiftSummary(String shiftId, [Currency currency = Currency.pkr]) {
    final rs = db.connection.select(
      'SELECT * FROM register_shifts WHERE id = ?',
      [shiftId],
    );
    if (rs.isEmpty) {
      throw ValidationException.invalidValue('shiftId', 'Shift $shiftId not found.');
    }

    final row = rs.first;
    final shiftNumber = row['shift_number'] as String;
    final cashierId = row['cashier_id'] as String;
    final deviceId = row['device_id'] as String;
    final openingMinor = row['opening_float_minor'] as int;
    final openedAt = DateTime.parse(row['opened_at'] as String);
    final closedAtStr = row['closed_at'] as String?;
    final untilTime = closedAtStr != null ? DateTime.parse(closedAtStr) : DateTime.now().toUtc();

    // 1. Cash Sales during shift: sum of sale_payments into CASH wallets
    final salesRs = db.connection.select(
      '''
      SELECT COALESCE(SUM(sp.amount_minor), 0) AS cash_sales
      FROM sale_payments sp
      JOIN wallets w ON sp.wallet_id = w.id
      JOIN sales s ON sp.sale_id = s.id
      WHERE w.type = 'CASH'
        AND s.device_id = ?
        AND s.created_at >= ?
        AND s.created_at <= ?
      ''',
      [deviceId, openedAt.toIso8601String(), untilTime.toIso8601String()],
    );
    final cashSalesMinor = salesRs.first['cash_sales'] as int? ?? 0;

    // 2. Cash Refunds during shift: sum of return_payments from CASH wallets
    final refundsRs = db.connection.select(
      '''
      SELECT COALESCE(SUM(rp.amount_minor), 0) AS cash_refunds
      FROM return_payments rp
      JOIN wallets w ON rp.wallet_id = w.id
      JOIN returns r ON rp.return_id = r.id
      WHERE w.type = 'CASH'
        AND r.device_id = ?
        AND r.created_at >= ?
        AND r.created_at <= ?
      ''',
      [deviceId, openedAt.toIso8601String(), untilTime.toIso8601String()],
    );
    final cashRefundsMinor = refundsRs.first['cash_refunds'] as int? ?? 0;

    // 3. Cash Expenses during shift: sum of wallet_transactions EXPENSE on CASH wallets
    final expRs = db.connection.select(
      '''
      SELECT COALESCE(SUM(wt.amount_minor), 0) AS cash_expenses
      FROM wallet_transactions wt
      JOIN wallets w ON wt.wallet_id = w.id
      WHERE w.type = 'CASH'
        AND wt.type = 'EXPENSE'
        AND wt.device_id = ?
        AND wt.created_at >= ?
        AND wt.created_at <= ?
      ''',
      [deviceId, openedAt.toIso8601String(), untilTime.toIso8601String()],
    );
    final cashExpensesMinor = expRs.first['cash_expenses'] as int? ?? 0;

    // Expected Cash Formula: Opening Float + Cash Sales - Cash Refunds - Cash Expenses
    final expectedMinor = openingMinor + cashSalesMinor - cashRefundsMinor - cashExpensesMinor;

    return ShiftSummary(
      id: shiftId,
      shiftNumber: shiftNumber,
      cashierId: cashierId,
      deviceId: deviceId,
      openingFloat: Money.fromMinorUnits(openingMinor, currency),
      cashSales: Money.fromMinorUnits(cashSalesMinor, currency),
      cashRefunds: Money.fromMinorUnits(cashRefundsMinor, currency),
      cashExpenses: Money.fromMinorUnits(cashExpensesMinor, currency),
      expectedCash: Money.fromMinorUnits(expectedMinor, currency),
      openedAt: openedAt,
    );
  }

  /// Closes a register shift, computes variance (Counted - Expected), logs audit & sync events,
  /// and renders an authoritative thermal Z-Report printout.
  ShiftCloseoutResult closeShift({
    required String shiftId,
    required Money countedCash,
    String? notes,
    required String actorId,
    required String deviceId,
    String storeName = 'Zaynahs Flagship',
  }) {
    return db.transaction(() {
      final summary = getShiftSummary(shiftId, countedCash.currency);
      final variance = countedCash - summary.expectedCash;
      final now = DateTime.now().toUtc();

      // 1. Update register_shifts record
      db.connection.execute(
        '''
        UPDATE register_shifts
        SET expected_cash_minor = ?,
            counted_cash_minor = ?,
            cash_variance_minor = ?,
            total_sales_minor = ?,
            status = 'CLOSED',
            closed_at = ?,
            notes = COALESCE(?, notes)
        WHERE id = ?
        ''',
        [
          summary.expectedCash.minorUnits,
          countedCash.minorUnits,
          variance.minorUnits,
          summary.cashSales.minorUnits,
          now.toIso8601String(),
          notes,
          shiftId,
        ],
      );

      // 2. Audit Log
      final auditId = 'aud_${EntityId.generateUuidV4()}';
      final auditDetails = jsonEncode({
        'shiftNumber': summary.shiftNumber,
        'openingFloat': summary.openingFloat.format(),
        'cashSales': summary.cashSales.format(),
        'expectedCash': summary.expectedCash.format(),
        'countedCash': countedCash.format(),
        'variance': variance.format(),
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
          'REGISTER_SHIFT_CLOSED',
          actorId,
          deviceId,
          'shift',
          shiftId,
          auditDetails,
          '',
          'hash_$shiftId',
        ],
      );

      // 3. Sync Outbox
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
          'UPDATE',
          'register_shifts',
          shiftId,
          jsonEncode({
            'shiftId': shiftId,
            'status': 'CLOSED',
            'varianceMinor': variance.minorUnits,
          }),
          deviceId,
          'PENDING',
          0,
          now.toIso8601String(),
        ],
      );

      // 4. Render Thermal Z-Report Printout
      final builder = EscPosBuilder(paperWidth: PaperWidth.width80mm);
      builder
          .alignCenter()
          .setDoubleSize(true)
          .setBold(true)
          .textLine(storeName)
          .setDoubleSize(false)
          .textLine('DAILY REGISTER CLOSEOUT (Z-REPORT)')
          .setBold(false)
          .textLine('Shift: ${summary.shiftNumber}')
          .textLine('Device: ${summary.deviceId}')
          .textLine('Cashier: ${summary.cashierId}')
          .textLine('Opened: ${summary.openedAt.toIso8601String().substring(0, 19)}')
          .textLine('Closed: ${now.toIso8601String().substring(0, 19)}')
          .separator()
          .alignLeft()
          .row('Opening Cash Float:', summary.openingFloat.format())
          .row('Cash Sales (+):', summary.cashSales.format())
          .row('Cash Refunds (-):', summary.cashRefunds.format())
          .row('Cash Expenses (-):', summary.cashExpenses.format())
          .separator()
          .setBold(true)
          .row('EXPECTED CASH:', summary.expectedCash.format())
          .row('ACTUAL COUNTED:', countedCash.format())
          .row('VARIANCE:', variance.format())
          .setBold(false)
          .separator()
          .alignCenter()
          .textLine('*** OFFICIAL CLOSEOUT RECORD ***')
          .cutPaper();

      return ShiftCloseoutResult(
        summary: summary,
        countedCash: countedCash,
        variance: variance,
        closedAt: now,
        zReportReceiptBytes: builder.toBytes(),
      );
    });
  }
}
