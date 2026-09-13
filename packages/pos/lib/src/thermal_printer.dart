/// Thermal ESC/POS receipt layout and binary command builder.
/// Enforces Rule 95, Section 03: 58mm (32 cols) and 80mm (48 cols) layout rendering,
/// paper cut commands, and cash drawer kick pulse.
library thermal_printer;

import 'dart:convert';
import 'package:database/database.dart';

enum PaperWidth {
  width58mm(32),
  width80mm(48);

  final int columns;
  const PaperWidth(this.columns);
}

class EscPosBuilder {
  final PaperWidth paperWidth;
  final List<int> _bytes = [];

  EscPosBuilder({this.paperWidth = PaperWidth.width80mm}) {
    // ESC @: Initialize printer
    _bytes.addAll([0x1B, 0x40]);
  }

  List<int> toBytes() => List.unmodifiable(_bytes);

  EscPosBuilder alignLeft() {
    _bytes.addAll([0x1B, 0x61, 0x00]);
    return this;
  }

  EscPosBuilder alignCenter() {
    _bytes.addAll([0x1B, 0x61, 0x01]);
    return this;
  }

  EscPosBuilder alignRight() {
    _bytes.addAll([0x1B, 0x61, 0x02]);
    return this;
  }

  EscPosBuilder setBold(bool enable) {
    _bytes.addAll([0x1B, 0x45, enable ? 0x01 : 0x00]);
    return this;
  }

  EscPosBuilder setDoubleSize(bool enable) {
    _bytes.addAll([0x1D, 0x21, enable ? 0x11 : 0x00]);
    return this;
  }

  EscPosBuilder text(String text) {
    _bytes.addAll(utf8.encode(text));
    return this;
  }

  EscPosBuilder textLine(String text) {
    _bytes.addAll(utf8.encode('$text\n'));
    return this;
  }

  EscPosBuilder feed(int lines) {
    for (var i = 0; i < lines; i++) {
      _bytes.add(0x0A);
    }
    return this;
  }

  EscPosBuilder separator() {
    final sep = '-' * paperWidth.columns;
    textLine(sep);
    return this;
  }

  EscPosBuilder row(String left, String right) {
    final available = paperWidth.columns;
    if (left.length + right.length >= available) {
      // Truncate left if necessary to fit right
      final maxLeft = available - right.length - 1;
      final safeLeft = left.length > maxLeft ? left.substring(0, maxLeft) : left;
      final spaces = ' ' * (available - safeLeft.length - right.length);
      textLine('$safeLeft$spaces$right');
    } else {
      final spaces = ' ' * (available - left.length - right.length);
      textLine('$left$spaces$right');
    }
    return this;
  }

  /// Triggers cash drawer solenoid kick pulse: ESC p 0 25 250
  EscPosBuilder kickCashDrawer() {
    _bytes.addAll([0x1B, 0x70, 0x00, 0x19, 0xFA]);
    return this;
  }

  /// Feeds paper and executes paper cut: GS V 66 0
  EscPosBuilder cutPaper() {
    feed(3);
    _bytes.addAll([0x1D, 0x56, 0x42, 0x00]);
    return this;
  }

  /// Builds a complete ESC/POS receipt for a completed sale.
  static List<int> renderSaleReceipt({
    required SaleEntity sale,
    required String storeName,
    required List<Map<String, dynamic>> items,
    PaperWidth width = PaperWidth.width80mm,
    bool kickDrawer = true,
  }) {
    final builder = EscPosBuilder(paperWidth: width);

    if (kickDrawer) {
      builder.kickCashDrawer();
    }

    // Header
    builder
        .alignCenter()
        .setDoubleSize(true)
        .setBold(true)
        .textLine(storeName)
        .setDoubleSize(false)
        .setBold(false)
        .textLine('Official Sales Receipt')
        .textLine('Inv: ${sale.invoiceNumber}')
        .textLine('Date: ${sale.createdAt.toIso8601String().substring(0, 19)}')
        .separator()
        .alignLeft();

    // Table Header
    builder.row('Item / Qty', 'Amount').separator();

    // Items
    for (final it in items) {
      final name = it['name'] as String;
      final qty = it['qty'] as int;
      final price = it['price'] as String;
      builder.row('$name x$qty', price);
    }

    builder.separator();

    // Financial Totals
    builder
        .row('Subtotal:', sale.subtotal.format())
        .row('Discount:', sale.discount.format())
        .row('Tax:', sale.tax.format())
        .separator()
        .setBold(true)
        .row('GRAND TOTAL:', sale.grandTotal.format())
        .row('Paid Amount:', sale.paidAmount.format())
        .row('Due / Change:', sale.dueAmount.format())
        .setBold(false)
        .separator()
        .alignCenter()
        .textLine('Payment: ${sale.paymentStatus}')
        .textLine('Thank you for your business!')
        .cutPaper();

    return builder.toBytes();
  }
}
