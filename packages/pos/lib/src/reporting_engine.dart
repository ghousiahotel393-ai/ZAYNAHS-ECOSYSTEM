/// Authoritative Financial Reports and Analytics Engine for Zaynahs Ecosystem.
/// Enforces Rule 92-93, Section 01-02: Reports derive strictly from immutable ledgers,
/// NEVER from UI counters or stale cache projections.
library reporting_engine;

import 'package:core/core.dart';
import 'package:database/database.dart';

class ProfitAndLossReport {
  final Money grossRevenue;
  final Money returnsTotal;
  final Money netRevenue;
  final Money costOfGoodsSold;
  final Money grossProfit;
  final Money operatingExpenses;
  final Money netProfit;
  final DateTime generatedAt;

  const ProfitAndLossReport({
    required this.grossRevenue,
    required this.returnsTotal,
    required this.netRevenue,
    required this.costOfGoodsSold,
    required this.grossProfit,
    required this.operatingExpenses,
    required this.netProfit,
    required this.generatedAt,
  });
}

class InventoryValuationReport {
  final int totalItemCount;
  final int totalStockUnits;
  final Money valuationAtCost;
  final Money valuationAtRetail;
  final Money potentialMargin;
  final DateTime generatedAt;

  const InventoryValuationReport({
    required this.totalItemCount,
    required this.totalStockUnits,
    required this.valuationAtCost,
    required this.valuationAtRetail,
    required this.potentialMargin,
    required this.generatedAt,
  });
}

class PaymentBreakdownReport {
  final Money cashTotal;
  final Money bankTotal;
  final Money onlineTotal;
  final Money totalCollected;
  final DateTime generatedAt;

  const PaymentBreakdownReport({
    required this.cashTotal,
    required this.bankTotal,
    required this.onlineTotal,
    required this.totalCollected,
    required this.generatedAt,
  });
}

class ReportingEngine {
  final AppDatabase db;
  final InventoryRepository inventoryRepo;
  final WalletRepository walletRepo;
  final SalesRepository salesRepo;

  ReportingEngine({
    required this.db,
    required this.inventoryRepo,
    required this.walletRepo,
    required this.salesRepo,
  });

  /// Derives authoritative Profit & Loss statement from sales, returns, and expense ledgers.
  ProfitAndLossReport generateProfitAndLoss({
    DateTime? startDate,
    DateTime? endDate,
    Currency currency = Currency.pkr,
  }) {
    final now = DateTime.now().toUtc();

    // 1. Gross Revenue: Sum of grand_total_minor from completed sales
    var salesSql = 'SELECT COALESCE(SUM(grand_total_minor), 0) AS total FROM sales';
    final salesParams = <dynamic>[];
    if (startDate != null && endDate != null) {
      salesSql += ' WHERE created_at >= ? AND created_at <= ?';
      salesParams.addAll([startDate.toIso8601String(), endDate.toIso8601String()]);
    }
    final salesRs = db.connection.select(salesSql, salesParams);
    final grossMinor = salesRs.first['total'] as int? ?? 0;
    final grossRevenue = Money.fromMinorUnits(grossMinor, currency);

    // 2. Returns Total: Sum of total_refund_minor from returns
    var returnsSql = 'SELECT COALESCE(SUM(total_refund_minor), 0) AS total FROM returns';
    final returnsParams = <dynamic>[];
    if (startDate != null && endDate != null) {
      returnsSql += ' WHERE created_at >= ? AND created_at <= ?';
      returnsParams.addAll([startDate.toIso8601String(), endDate.toIso8601String()]);
    }
    final returnsRs = db.connection.select(returnsSql, returnsParams);
    final returnsMinor = returnsRs.first['total'] as int? ?? 0;
    final returnsTotal = Money.fromMinorUnits(returnsMinor, currency);

    // Net Revenue = Gross - Returns
    final netRevenue = grossRevenue - returnsTotal;

    // 3. COGS: Sum of (quantity * cost_price_snapshot_minor) from sale_items
    var cogsSql = '''
      SELECT COALESCE(SUM(si.quantity * si.cost_price_snapshot_minor), 0) AS total_cost
      FROM sale_items si
      JOIN sales s ON si.sale_id = s.id
    ''';
    final cogsParams = <dynamic>[];
    if (startDate != null && endDate != null) {
      cogsSql += ' WHERE s.created_at >= ? AND s.created_at <= ?';
      cogsParams.addAll([startDate.toIso8601String(), endDate.toIso8601String()]);
    }
    final cogsRs = db.connection.select(cogsSql, cogsParams);
    final cogsGrossMinor = cogsRs.first['total_cost'] as int? ?? 0;

    // Deduct returned items cost from COGS
    var retCogsSql = '''
      SELECT COALESCE(SUM(ri.quantity * ii.cost_price_minor), 0) AS ret_cost
      FROM return_items ri
      JOIN returns r ON ri.return_id = r.id
      JOIN inventory_items ii ON ri.item_id = ii.id
    ''';
    final retCogsParams = <dynamic>[];
    if (startDate != null && endDate != null) {
      retCogsSql += ' WHERE r.created_at >= ? AND r.created_at <= ?';
      retCogsParams.addAll([startDate.toIso8601String(), endDate.toIso8601String()]);
    }
    final retCogsRs = db.connection.select(retCogsSql, retCogsParams);
    final retCostMinor = retCogsRs.first['ret_cost'] as int? ?? 0;

    final netCogsMinor = cogsGrossMinor > retCostMinor ? cogsGrossMinor - retCostMinor : 0;
    final costOfGoodsSold = Money.fromMinorUnits(netCogsMinor, currency);

    // Gross Profit = Net Revenue - COGS
    final grossProfit = netRevenue - costOfGoodsSold;

    // 4. Operating Expenses: Sum of wallet_transactions where type = 'EXPENSE'
    var expSql = "SELECT COALESCE(SUM(amount_minor), 0) AS total_exp FROM wallet_transactions WHERE type = 'EXPENSE'";
    final expParams = <dynamic>[];
    if (startDate != null && endDate != null) {
      expSql += ' AND created_at >= ? AND created_at <= ?';
      expParams.addAll([startDate.toIso8601String(), endDate.toIso8601String()]);
    }
    final expRs = db.connection.select(expSql, expParams);
    final expMinor = expRs.first['total_exp'] as int? ?? 0;
    final operatingExpenses = Money.fromMinorUnits(expMinor, currency);

    // Net Profit = Gross Profit - Operating Expenses
    final netProfit = grossProfit - operatingExpenses;

    return ProfitAndLossReport(
      grossRevenue: grossRevenue,
      returnsTotal: returnsTotal,
      netRevenue: netRevenue,
      costOfGoodsSold: costOfGoodsSold,
      grossProfit: grossProfit,
      operatingExpenses: operatingExpenses,
      netProfit: netProfit,
      generatedAt: now,
    );
  }

  /// Calculates authoritative inventory valuation based on derived stock movements.
  InventoryValuationReport generateInventoryValuation([Currency currency = Currency.pkr]) {
    final now = DateTime.now().toUtc();
    final items = inventoryRepo.listActiveItems();

    var totalUnits = 0;
    var costMinor = 0;
    var retailMinor = 0;

    for (final it in items) {
      final stock = inventoryRepo.getStockBalance(it.id);
      if (stock > 0) {
        totalUnits += stock;
        costMinor += stock * it.costPrice.minorUnits;
        retailMinor += stock * it.sellingPrice.minorUnits;
      }
    }

    final valuationAtCost = Money.fromMinorUnits(costMinor, currency);
    final valuationAtRetail = Money.fromMinorUnits(retailMinor, currency);
    final potentialMargin = valuationAtRetail - valuationAtCost;

    return InventoryValuationReport(
      totalItemCount: items.length,
      totalStockUnits: totalUnits,
      valuationAtCost: valuationAtCost,
      valuationAtRetail: valuationAtRetail,
      potentialMargin: potentialMargin,
      generatedAt: now,
    );
  }

  /// Breaks down collected payments by wallet channel (Cash, Bank, Online).
  PaymentBreakdownReport generatePaymentBreakdown({
    DateTime? startDate,
    DateTime? endDate,
    Currency currency = Currency.pkr,
  }) {
    final now = DateTime.now().toUtc();

    var sql = '''
      SELECT w.type, COALESCE(SUM(sp.amount_minor), 0) AS total_amount
      FROM sale_payments sp
      JOIN wallets w ON sp.wallet_id = w.id
    ''';
    final params = <dynamic>[];
    if (startDate != null && endDate != null) {
      sql += ' WHERE sp.created_at >= ? AND sp.created_at <= ?';
      params.addAll([startDate.toIso8601String(), endDate.toIso8601String()]);
    }
    sql += ' GROUP BY w.type';

    final rs = db.connection.select(sql, params);

    var cashMinor = 0;
    var bankMinor = 0;
    var onlineMinor = 0;

    for (final row in rs) {
      final type = row['type'] as String;
      final amount = row['total_amount'] as int? ?? 0;
      if (type == 'CASH') cashMinor = amount;
      if (type == 'BANK') bankMinor = amount;
      if (type == 'ONLINE') onlineMinor = amount;
    }

    final cashTotal = Money.fromMinorUnits(cashMinor, currency);
    final bankTotal = Money.fromMinorUnits(bankMinor, currency);
    final onlineTotal = Money.fromMinorUnits(onlineMinor, currency);
    final totalCollected = cashTotal + bankTotal + onlineTotal;

    return PaymentBreakdownReport(
      cashTotal: cashTotal,
      bankTotal: bankTotal,
      onlineTotal: onlineTotal,
      totalCollected: totalCollected,
      generatedAt: now,
    );
  }
}
