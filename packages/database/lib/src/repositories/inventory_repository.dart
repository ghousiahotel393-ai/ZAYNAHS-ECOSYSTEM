/// Repository for master inventory items and immutable stock movements.
/// Enforces Rule 23-26: Stock balance is strictly derived from the sum of movements.
library inventory_repository;

import 'package:core/core.dart';
import '../app_database.dart';

class InventoryItemEntity {
  final String id;
  final String sku;
  final String? barcode;
  final String name;
  final String category;
  final String unit;
  final Money costPrice;
  final Money sellingPrice;
  final int minStockAlert;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const InventoryItemEntity({
    required this.id,
    required this.sku,
    this.barcode,
    required this.name,
    this.category = 'General',
    this.unit = 'pcs',
    required this.costPrice,
    required this.sellingPrice,
    this.minStockAlert = 5,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });
}

class InventoryMovementEntity {
  final String id;
  final String itemId;
  final String type; // PURCHASE, SALE, RETURN, ADJUSTMENT, COUNT
  final int quantity;
  final Money costPrice;
  final int previousBalance;
  final int newBalance;
  final String referenceId;
  final String actorId;
  final String deviceId;
  final String? notes;
  final DateTime createdAt;

  const InventoryMovementEntity({
    required this.id,
    required this.itemId,
    required this.type,
    required this.quantity,
    required this.costPrice,
    required this.previousBalance,
    required this.newBalance,
    required this.referenceId,
    required this.actorId,
    required this.deviceId,
    this.notes,
    required this.createdAt,
  });
}

class InventoryRepository {
  final AppDatabase db;

  InventoryRepository(this.db);

  /// Inserts a new inventory item.
  void createItem(InventoryItemEntity item) {
    db.connection.execute(
      '''
      INSERT INTO inventory_items (
        id, sku, barcode, name, category, unit,
        cost_price_minor, selling_price_minor, min_stock_alert, is_active,
        created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        item.id,
        item.sku,
        item.barcode,
        item.name,
        item.category,
        item.unit,
        item.costPrice.minorUnits,
        item.sellingPrice.minorUnits,
        item.minStockAlert,
        item.isActive ? 1 : 0,
        item.createdAt.toIso8601String(),
        item.updatedAt.toIso8601String(),
      ],
    );
  }

  /// Appends an immutable stock movement and calculates new balance.
  InventoryMovementEntity recordMovement({
    required String itemId,
    required String type,
    required int quantity,
    required Money costPrice,
    required String referenceId,
    required String actorId,
    required String deviceId,
    String? notes,
  }) {
    if (quantity == 0) {
      throw ArgumentError('Movement quantity cannot be 0');
    }

    return db.transaction(() {
      final currentBalance = getStockBalance(itemId);
      final newBalance = currentBalance + quantity;

      final movementId = MovementId.generate().value;
      final now = DateTime.now().toUtc();

      db.connection.execute(
        '''
        INSERT INTO inventory_movements (
          id, item_id, type, quantity, cost_price_minor,
          previous_balance, new_balance, reference_id,
          actor_id, device_id, notes, created_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''',
        [
          movementId,
          itemId,
          type,
          quantity,
          costPrice.minorUnits,
          currentBalance,
          newBalance,
          referenceId,
          actorId,
          deviceId,
          notes,
          now.toIso8601String(),
        ],
      );

      return InventoryMovementEntity(
        id: movementId,
        itemId: itemId,
        type: type,
        quantity: quantity,
        costPrice: costPrice,
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

  /// Calculates authoritative stock balance derived strictly from sum of movements.
  int getStockBalance(String itemId) {
    final rs = db.connection.select(
      'SELECT COALESCE(SUM(quantity), 0) AS balance FROM inventory_movements WHERE item_id = ?',
      [itemId],
    );
    if (rs.isEmpty) return 0;
    return rs.first['balance'] as int? ?? 0;
  }

  /// Finds item by ID.
  InventoryItemEntity? getItemById(String itemId) {
    final rs = db.connection.select(
      'SELECT * FROM inventory_items WHERE id = ?',
      [itemId],
    );
    if (rs.isEmpty) return null;
    final row = rs.first;
    return InventoryItemEntity(
      id: row['id'] as String,
      sku: row['sku'] as String,
      barcode: row['barcode'] as String?,
      name: row['name'] as String,
      category: row['category'] as String,
      unit: row['unit'] as String,
      costPrice: Money.fromMinorUnits(row['cost_price_minor'] as int, Currency.pkr),
      sellingPrice: Money.fromMinorUnits(row['selling_price_minor'] as int, Currency.pkr),
      minStockAlert: row['min_stock_alert'] as int,
      isActive: (row['is_active'] as int) == 1,
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
    );
  }

  /// Lists all active items.
  List<InventoryItemEntity> listActiveItems() {
    final rs = db.connection.select(
      'SELECT * FROM inventory_items WHERE is_active = 1 ORDER BY name ASC',
    );
    return rs.map((row) => InventoryItemEntity(
      id: row['id'] as String,
      sku: row['sku'] as String,
      barcode: row['barcode'] as String?,
      name: row['name'] as String,
      category: row['category'] as String,
      unit: row['unit'] as String,
      costPrice: Money.fromMinorUnits(row['cost_price_minor'] as int, Currency.pkr),
      sellingPrice: Money.fromMinorUnits(row['selling_price_minor'] as int, Currency.pkr),
      minStockAlert: row['min_stock_alert'] as int,
      isActive: (row['is_active'] as int) == 1,
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
    )).toList();
  }
}
