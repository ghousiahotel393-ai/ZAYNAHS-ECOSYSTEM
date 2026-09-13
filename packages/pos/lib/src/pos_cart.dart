/// Immutable shopping cart model for the Universal POS Engine.
/// Guarantees exact money arithmetic, item discounts, cart-level discounts,
/// and line total precision without floating-point errors.
library pos_cart;

import 'package:core/core.dart';

class CartLineItem {
  final String itemId;
  final String itemName;
  final int quantity;
  final Money unitPrice;
  final Money costPrice;
  final Money itemDiscount;
  final Map<String, dynamic> attributes;

  const CartLineItem({
    required this.itemId,
    required this.itemName,
    required this.quantity,
    required this.unitPrice,
    required this.costPrice,
    required this.itemDiscount,
    this.attributes = const {},
  });

  Money get grossTotal => unitPrice * quantity;
  Money get netTotal => grossTotal - itemDiscount;

  CartLineItem copyWith({
    int? quantity,
    Money? unitPrice,
    Money? costPrice,
    Money? itemDiscount,
    Map<String, dynamic>? attributes,
  }) {
    return CartLineItem(
      itemId: itemId,
      itemName: itemName,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      costPrice: costPrice ?? this.costPrice,
      itemDiscount: itemDiscount ?? this.itemDiscount,
      attributes: attributes ?? this.attributes,
    );
  }
}

class PosCart {
  final Currency currency;
  final List<CartLineItem> items;
  final Money cartDiscount;
  final Money tax;

  const PosCart({
    this.currency = Currency.pkr,
    this.items = const [],
    required this.cartDiscount,
    required this.tax,
  });

  factory PosCart.empty([Currency currency = Currency.pkr]) {
    return PosCart(
      currency: currency,
      items: const [],
      cartDiscount: Money.zero(currency),
      tax: Money.zero(currency),
    );
  }

  /// Calculates gross subtotal (sum of unitPrice * quantity before any discounts).
  Money get subtotal {
    var sum = Money.zero(currency);
    for (final it in items) {
      sum = sum + it.grossTotal;
    }
    return sum;
  }

  /// Calculates total item-level discounts.
  Money get itemDiscountsTotal {
    var sum = Money.zero(currency);
    for (final it in items) {
      sum = sum + it.itemDiscount;
    }
    return sum;
  }

  /// Total discount combined (line-level + cart-level).
  Money get totalDiscount => itemDiscountsTotal + cartDiscount;

  /// Authoritative Grand Total: (subtotal - totalDiscount) + tax.
  Money get grandTotal {
    final discounted = subtotal - totalDiscount;
    final nonNegative = discounted.isNegative ? Money.zero(currency) : discounted;
    return nonNegative + tax;
  }

  int get totalItemCount {
    var count = 0;
    for (final it in items) {
      count += it.quantity;
    }
    return count;
  }

  PosCart addItem(CartLineItem item) {
    final existingIndex = items.indexWhere((it) => it.itemId == item.itemId);
    if (existingIndex >= 0) {
      final existing = items[existingIndex];
      final updated = existing.copyWith(
        quantity: existing.quantity + item.quantity,
        itemDiscount: existing.itemDiscount + item.itemDiscount,
      );
      final newItems = List<CartLineItem>.from(items);
      newItems[existingIndex] = updated;
      return PosCart(
        currency: currency,
        items: newItems,
        cartDiscount: cartDiscount,
        tax: tax,
      );
    } else {
      return PosCart(
        currency: currency,
        items: [...items, item],
        cartDiscount: cartDiscount,
        tax: tax,
      );
    }
  }

  PosCart updateItemQuantity(String itemId, int newQuantity) {
    if (newQuantity <= 0) {
      return removeItem(itemId);
    }
    final newItems = items.map((it) {
      if (it.itemId == itemId) {
        return it.copyWith(quantity: newQuantity);
      }
      return it;
    }).toList();

    return PosCart(
      currency: currency,
      items: newItems,
      cartDiscount: cartDiscount,
      tax: tax,
    );
  }

  PosCart removeItem(String itemId) {
    final newItems = items.where((it) => it.itemId != itemId).toList();
    return PosCart(
      currency: currency,
      items: newItems,
      cartDiscount: cartDiscount,
      tax: tax,
    );
  }

  PosCart withCartDiscount(Money discount) {
    return PosCart(
      currency: currency,
      items: items,
      cartDiscount: discount,
      tax: tax,
    );
  }

  PosCart withTax(Money newTax) {
    return PosCart(
      currency: currency,
      items: items,
      cartDiscount: cartDiscount,
      tax: newTax,
    );
  }

  PosCart clear() => PosCart.empty(currency);
}
