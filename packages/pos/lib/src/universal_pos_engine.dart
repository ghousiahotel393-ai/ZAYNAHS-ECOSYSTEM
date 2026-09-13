/// Authoritative Universal POS Engine for Zaynahs Ecosystem.
/// Enforces Rule 23-36: ONE universal POS engine, immutable ledgers, multi-wallet split payments,
/// atomic 8-way checkout, and authoritative returns/replacements.
library universal_pos_engine;

import 'package:core/core.dart';
import 'package:database/database.dart';
import 'negative_stock_policy.dart';
import 'pos_cart.dart';

class ReturnItemRequest {
  final String itemId;
  final int quantity;
  final Money? customRefundPerUnit;

  const ReturnItemRequest({
    required this.itemId,
    required this.quantity,
    this.customRefundPerUnit,
  });
}

class UniversalPosEngine {
  final SalesRepository salesRepo;
  final InventoryRepository inventoryRepo;
  final WalletRepository walletRepo;
  final NegativeStockPolicy stockPolicy;

  UniversalPosEngine({
    required this.salesRepo,
    required this.inventoryRepo,
    required this.walletRepo,
    this.stockPolicy = NegativeStockPolicy.block,
  });

  /// Validates available inventory before sale checkout.
  void validateStock(PosCart cart) {
    for (final it in cart.items) {
      final available = inventoryRepo.getStockBalance(it.itemId);
      if (available < it.quantity) {
        if (stockPolicy.isBlock) {
          throw ValidationException.invalidValue(
            it.itemId,
            'Insufficient stock for "${it.itemName}". Available: $available, requested: ${it.quantity}.',
          );
        }
      }
    }
  }

  /// Executes an atomic POS Checkout with split payment support.
  /// Enforces Rule 30: 8-way atomic transaction.
  SaleEntity checkout({
    required PosCart cart,
    required String invoiceNumber,
    required List<PaymentAllocation> paymentAllocations,
    String? customerId,
    required String actorId,
    required String deviceId,
    String? idempotencyKey,
  }) {
    if (cart.items.isEmpty) {
      throw ValidationException.invalidValue('cart', 'Cart must contain at least one item');
    }

    // 1. Validate Stock
    validateStock(cart);

    // 2. Sum Payment Allocations
    final currency = cart.currency;
    var paidAmount = Money.zero(currency);
    for (final alloc in paymentAllocations) {
      paidAmount = paidAmount + alloc.amount;
    }

    // 3. Map Cart Items to SaleItemInput with snapshotted attributes
    final saleItemInputs = cart.items.map((it) {
      return SaleItemInput(
        itemId: it.itemId,
        itemName: it.itemName,
        quantity: it.quantity,
        unitPrice: it.unitPrice,
        costPrice: it.costPrice,
        attributes: it.attributes,
      );
    }).toList();

    // 4. Delegate to Atomic Database Transaction in SalesRepository
    return salesRepo.processSaleCheckout(
      invoiceNumber: invoiceNumber,
      items: saleItemInputs,
      discount: cart.totalDiscount,
      tax: cart.tax,
      paidAmount: paidAmount,
      paymentAllocations: paymentAllocations,
      customerId: customerId,
      actorId: actorId,
      deviceId: deviceId,
    );
  }

  /// Executes an Authoritative Return against a completed Sale.
  /// Enforces Rule 31 & Rule 100: Retains net proportional price (accounting for discounts),
  /// restores inventory, and debits refund across split wallets without modifying historical sale.
  ReturnEntity processReturn({
    required String saleId,
    required String returnNumber,
    required List<ReturnItemRequest> itemsToReturn,
    required List<PaymentAllocation> refundAllocations,
    String? reason,
    required String actorId,
    required String deviceId,
  }) {
    final sale = salesRepo.getSaleById(saleId);
    if (sale == null) {
      throw ValidationException.invalidValue('saleId', 'Sale with ID $saleId does not exist.');
    }

    // Query historical sale_items to accurately snapshot unit cost and net price
    final saleItemsRows = salesRepo.db.connection.select(
      'SELECT * FROM sale_items WHERE sale_id = ?',
      [saleId],
    );
    if (saleItemsRows.isEmpty) {
      throw ValidationException.invalidValue('saleId', 'Sale $saleId has no associated line items.');
    }

    final currency = sale.grandTotal.currency;
    final returnInputs = <ReturnItemInput>[];

    for (final req in itemsToReturn) {
      final matchingItem = saleItemsRows.firstWhere(
        (r) => r['item_id'] == req.itemId,
        orElse: () => throw ValidationException.invalidValue(
          'itemId',
          'Item ${req.itemId} was not part of sale $saleId.',
        ),
      );

      final originalQty = matchingItem['quantity'] as int;
      final unitPriceMinor = matchingItem['unit_price_minor'] as int;
      final costPriceMinor = matchingItem['cost_price_snapshot_minor'] as int;

      if (req.quantity > originalQty) {
        throw ValidationException.invalidValue(
          'quantity',
          'Cannot return ${req.quantity} units; only $originalQty were purchased in sale $saleId.',
        );
      }

      Money lineRefund;
      if (req.customRefundPerUnit != null) {
        lineRefund = req.customRefundPerUnit! * req.quantity;
      } else {
        // Calculate proportional discount:
        // netUnitPrice = (originalSubtotal - discount) / totalQuantity
        if (sale.discount.isPositive && sale.subtotal.isPositive) {
          final discountRatio = 1.0 - (sale.discount.minorUnits / sale.subtotal.minorUnits);
          final netUnitMinor = (unitPriceMinor * discountRatio).round();
          lineRefund = Money.fromMinorUnits(netUnitMinor * req.quantity, currency);
        } else {
          lineRefund = Money.fromMinorUnits(unitPriceMinor * req.quantity, currency);
        }
      }

      returnInputs.add(
        ReturnItemInput(
          itemId: req.itemId,
          quantity: req.quantity,
          refundAmount: lineRefund,
          costPrice: Money.fromMinorUnits(costPriceMinor, currency),
        ),
      );
    }

    return salesRepo.processReturn(
      saleId: saleId,
      returnNumber: returnNumber,
      items: returnInputs,
      refundAllocations: refundAllocations,
      reason: reason,
      actorId: actorId,
      deviceId: deviceId,
    );
  }
}
