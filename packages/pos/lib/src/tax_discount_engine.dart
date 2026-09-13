/// Multi-tier Tax & Discount Engine for Zaynahs Ecosystem.
/// Enforces Rule 23, Section 01: Multi-tier taxes (inclusive, exclusive, exempt)
/// and cashier discount limits with manager PIN authorization.
library tax_discount_engine;

import 'package:core/core.dart';

enum TaxType {
  /// Tax is calculated and added on top of item price.
  exclusive,

  /// Tax is already embedded within the retail price.
  inclusive,

  /// Zero-rated or tax-exempt.
  exempt,
}

class TaxRate {
  final String id;
  final String name;
  final double ratePercent;
  final TaxType type;

  const TaxRate({
    required this.id,
    required this.name,
    required this.ratePercent,
    this.type = TaxType.exclusive,
  });

  /// Computes tax amount for a given base amount with exact integer arithmetic.
  Money calculateTax(Money baseAmount) {
    if (type == TaxType.exempt || ratePercent <= 0.0) {
      return Money.zero(baseAmount.currency);
    }

    if (type == TaxType.exclusive) {
      final taxMinor = (baseAmount.minorUnits * (ratePercent / 100.0)).round();
      return Money.fromMinorUnits(taxMinor, baseAmount.currency);
    } else {
      // Inclusive: tax = gross - (gross / (1 + rate))
      final baseMinor = (baseAmount.minorUnits / (1.0 + (ratePercent / 100.0))).round();
      final taxMinor = baseAmount.minorUnits - baseMinor;
      return Money.fromMinorUnits(taxMinor, baseAmount.currency);
    }
  }

  static const standardGst18 = TaxRate(
    id: 'tax_gst_18',
    name: 'GST (18%)',
    ratePercent: 18.0,
    type: TaxType.exclusive,
  );

  static const standardVat5 = TaxRate(
    id: 'tax_vat_5',
    name: 'VAT (5%)',
    ratePercent: 5.0,
    type: TaxType.exclusive,
  );

  static const inclusiveVat15 = TaxRate(
    id: 'tax_inc_vat_15',
    name: 'Inclusive VAT (15%)',
    ratePercent: 15.0,
    type: TaxType.inclusive,
  );

  static const zeroRated = TaxRate(
    id: 'tax_zero',
    name: 'Zero-Rated / Exempt',
    ratePercent: 0.0,
    type: TaxType.exempt,
  );
}

class DiscountAuthorization {
  /// Maximum discount percentage a standard Cashier can apply without manager approval.
  final double maxCashierPercent;

  const DiscountAuthorization({this.maxCashierPercent = 10.0});

  /// Validates whether the given discount is authorized for the user role.
  /// Throws PermissionDeniedException if cashier exceeds max percent without manager approval.
  void validateDiscount({
    required Money subtotal,
    required Money discountAmount,
    required String userRole,
    bool isManagerOverrideApproved = false,
  }) {
    if (subtotal.minorUnits <= 0 || discountAmount.minorUnits <= 0) return;

    final discountPercent = (discountAmount.minorUnits / subtotal.minorUnits) * 100.0;

    final isElevatedRole = userRole == 'Owner' || userRole == 'Admin' || userRole == 'Manager';

    if (discountPercent > maxCashierPercent) {
      if (!isElevatedRole && !isManagerOverrideApproved) {
        throw PermissionDeniedException(
          requiredPermission: 'DISCOUNT_OVERRIDE',
          userRole: userRole,
          message: 'Discount of ${discountPercent.toStringAsFixed(1)}% exceeds Cashier threshold (${maxCashierPercent.toStringAsFixed(1)}%). Manager PIN override required.',
          details: {
            'requestedPercent': discountPercent,
            'maxCashierPercent': maxCashierPercent,
            'userRole': userRole,
          },
        );
      }
    }
  }
}
