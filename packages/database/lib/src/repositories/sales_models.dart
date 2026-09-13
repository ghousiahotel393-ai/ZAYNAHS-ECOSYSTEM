/// Models for Universal POS Sales, Payments, and Returns.
/// Enforces Rule 20, 23-36: Typed entities, immutable ledgers, and exact money representation.
library sales_models;

import 'package:core/core.dart';

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
