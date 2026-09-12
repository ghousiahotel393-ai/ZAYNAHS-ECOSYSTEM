/// Repository for Multi-Wallet management and immutable financial transactions.
/// Enforces Rule 27-36: Balances are strictly derived from the immutable ledger.
library wallet_repository;

import 'package:core/core.dart';
import '../app_database.dart';

class WalletEntity {
  final String id;
  final String name;
  final String type; // CASH, BANK, ONLINE
  final Currency currency;
  final Money balance;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const WalletEntity({
    required this.id,
    required this.name,
    required this.type,
    required this.currency,
    required this.balance,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });
}

class WalletTransactionEntity {
  final String id;
  final String walletId;
  final String type; // DEPOSIT, WITHDRAWAL, TRANSFER_IN, TRANSFER_OUT, SALE_PAYMENT, REFUND, EXPENSE
  final Money amount;
  final Money previousBalance;
  final Money newBalance;
  final String referenceId;
  final String actorId;
  final String deviceId;
  final String? notes;
  final DateTime createdAt;

  const WalletTransactionEntity({
    required this.id,
    required this.walletId,
    required this.type,
    required this.amount,
    required this.previousBalance,
    required this.newBalance,
    required this.referenceId,
    required this.actorId,
    required this.deviceId,
    this.notes,
    required this.createdAt,
  });
}

class WalletRepository {
  final AppDatabase db;

  WalletRepository(this.db);

  /// Creates a new physical or digital wallet account.
  void createWallet(WalletEntity wallet) {
    db.connection.execute(
      '''
      INSERT INTO wallets (
        id, name, type, currency, balance_minor, is_active, created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        wallet.id,
        wallet.name,
        wallet.type,
        wallet.currency.code,
        wallet.balance.minorUnits,
        wallet.isActive ? 1 : 0,
        wallet.createdAt.toIso8601String(),
        wallet.updatedAt.toIso8601String(),
      ],
    );
  }

  /// Appends an immutable financial transaction and updates wallet projection.
  WalletTransactionEntity recordTransaction({
    required String walletId,
    required String type,
    required Money amount,
    required String referenceId,
    required String actorId,
    required String deviceId,
    String? notes,
  }) {
    if (amount.minorUnits <= 0) {
      throw ArgumentError('Transaction amount must be strictly positive');
    }

    return db.transaction(() {
      final currentBalance = getWalletBalance(walletId, amount.currency);
      final isCredit = (type == 'DEPOSIT' || type == 'TRANSFER_IN' || type == 'SALE_PAYMENT');
      final newBalance = isCredit ? currentBalance + amount : currentBalance - amount;

      final txId = TransactionId.generate().value;
      final now = DateTime.now().toUtc();

      // 1. Insert immutable transaction entry
      db.connection.execute(
        '''
        INSERT INTO wallet_transactions (
          id, wallet_id, type, amount_minor, previous_balance,
          new_balance, reference_id, actor_id, device_id, notes, created_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''',
        [
          txId,
          walletId,
          type,
          amount.minorUnits,
          currentBalance.minorUnits,
          newBalance.minorUnits,
          referenceId,
          actorId,
          deviceId,
          notes,
          now.toIso8601String(),
        ],
      );

      // 2. Update cached balance projection in wallets table
      db.connection.execute(
        '''
        UPDATE wallets SET balance_minor = ?, updated_at = ? WHERE id = ?
        ''',
        [newBalance.minorUnits, now.toIso8601String(), walletId],
      );

      return WalletTransactionEntity(
        id: txId,
        walletId: walletId,
        type: type,
        amount: amount,
        previousBalance: currentBalance,
        newBalance: newBalance,
        referenceId: referenceId,
        actorId: actorId,
        deviceId: deviceId,
        notes: notes,
        createdAt: now,
      );
    });
  }

  /// Atomic wallet transfer between two accounts.
  void transferBetweenWallets({
    required String fromWalletId,
    required String toWalletId,
    required Money amount,
    required String actorId,
    required String deviceId,
    String? notes,
  }) {
    if (fromWalletId == toWalletId) {
      throw ArgumentError('Source and destination wallet cannot be identical');
    }

    db.transaction(() {
      final transferRef = 'trf_${DateTime.now().millisecondsSinceEpoch}';

      recordTransaction(
        walletId: fromWalletId,
        type: 'TRANSFER_OUT',
        amount: amount,
        referenceId: transferRef,
        actorId: actorId,
        deviceId: deviceId,
        notes: 'Transfer to $toWalletId: ${notes ?? ""}',
      );

      recordTransaction(
        walletId: toWalletId,
        type: 'TRANSFER_IN',
        amount: amount,
        referenceId: transferRef,
        actorId: actorId,
        deviceId: deviceId,
        notes: 'Transfer from $fromWalletId: ${notes ?? ""}',
      );
    });
  }

  /// Derives authoritative balance strictly from sum of immutable transactions.
  Money getWalletBalance(String walletId, [Currency currency = Currency.pkr]) {
    final rs = db.connection.select(
      '''
      SELECT COALESCE(SUM(
        CASE
          WHEN type IN ('DEPOSIT', 'TRANSFER_IN', 'SALE_PAYMENT') THEN amount_minor
          ELSE -amount_minor
        END
      ), 0) AS calculated_balance
      FROM wallet_transactions
      WHERE wallet_id = ?
      ''',
      [walletId],
    );

    final balanceUnits = rs.isNotEmpty ? (rs.first['calculated_balance'] as int? ?? 0) : 0;
    return Money.fromMinorUnits(balanceUnits, currency);
  }

  /// Lists all active wallets.
  List<WalletEntity> listActiveWallets() {
    final rs = db.connection.select(
      'SELECT * FROM wallets WHERE is_active = 1 ORDER BY name ASC',
    );
    return rs.map((row) {
      final curr = Currency.fromCode(row['currency'] as String);
      return WalletEntity(
        id: row['id'] as String,
        name: row['name'] as String,
        type: row['type'] as String,
        currency: curr,
        balance: Money.fromMinorUnits(row['balance_minor'] as int, curr),
        isActive: (row['is_active'] as int) == 1,
        createdAt: DateTime.parse(row['created_at'] as String),
        updatedAt: DateTime.parse(row['updated_at'] as String),
      );
    }).toList();
  }
}
