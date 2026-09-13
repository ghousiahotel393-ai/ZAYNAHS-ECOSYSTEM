/// Policy controlling how the universal POS engine handles inventory when
/// a sale would cause available stock to drop below zero.
/// Enforces Rule 50: Default is strictly BLOCK. WARN and ALLOW can be configured.
library negative_stock_policy;

enum NegativeStockPolicy {
  /// Strictly blocks any sale that causes stock to drop below zero (Default).
  block,

  /// Displays warning to cashier but permits transaction.
  warn,

  /// Allows sale with negative stock balance, logging an audit alert.
  allow;

  bool get isBlock => this == NegativeStockPolicy.block;
  bool get isWarn => this == NegativeStockPolicy.warn;
  bool get isAllow => this == NegativeStockPolicy.allow;
}
