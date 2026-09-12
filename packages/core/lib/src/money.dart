/// Precision-safe monetary value object for financial ledger operations.
/// NEVER uses floating-point types for monetary balances to prevent rounding drift.
library money;

/// Supported currency definitions.
class Currency {
  final String code;
  final String symbol;
  final int decimalDigits;
  final String displayName;

  const Currency({
    required this.code,
    required this.symbol,
    this.decimalDigits = 2,
    required this.displayName,
  });

  static const Currency pkr = Currency(
    code: 'PKR',
    symbol: 'Rs',
    decimalDigits: 2,
    displayName: 'Pakistani Rupee',
  );

  static const Currency usd = Currency(
    code: 'USD',
    symbol: r'$',
    decimalDigits: 2,
    displayName: 'US Dollar',
  );

  static const Currency eur = Currency(
    code: 'EUR',
    symbol: '€',
    decimalDigits: 2,
    displayName: 'Euro',
  );

  static const Currency gbp = Currency(
    code: 'GBP',
    symbol: '£',
    decimalDigits: 2,
    displayName: 'British Pound',
  );

  static const Currency aed = Currency(
    code: 'AED',
    symbol: 'AED',
    decimalDigits: 2,
    displayName: 'UAE Dirham',
  );

  static const Currency sar = Currency(
    code: 'SAR',
    symbol: 'SAR',
    decimalDigits: 2,
    displayName: 'Saudi Riyal',
  );

  static const Map<String, Currency> _currencies = {
    'PKR': pkr,
    'USD': usd,
    'EUR': eur,
    'GBP': gbp,
    'AED': aed,
    'SAR': sar,
  };

  static Currency fromCode(String code) {
    final upper = code.trim().toUpperCase();
    return _currencies[upper] ??
        Currency(
          code: upper,
          symbol: upper,
          decimalDigits: 2,
          displayName: upper,
        );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Currency &&
          runtimeType == other.runtimeType &&
          other.code == code);

  @override
  int get hashCode => code.hashCode;

  @override
  String toString() => code;
}

/// Immutable Money value object stored strictly as minor units (e.g., paisa or cents).
class Money implements Comparable<Money> {
  /// The amount in minor units (e.g. 1000 = 10.00).
  final int minorUnits;
  final Currency currency;

  const Money._(this.minorUnits, this.currency);

  /// Creates Money from minor units (e.g., cents or paisa).
  const factory Money.fromMinorUnits(int minorUnits, Currency currency) =
      Money._;

  /// Creates Money from decimal value string (e.g., "12.50").
  factory Money.fromDecimal(String decimalStr, Currency currency) {
    final trimmed = decimalStr.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(decimalStr, 'decimalStr', 'Amount cannot be empty');
    }

    final isNegative = trimmed.startsWith('-');
    final cleanStr = isNegative ? trimmed.substring(1) : trimmed;

    final parts = cleanStr.split('.');
    if (parts.length > 2) {
      throw ArgumentError.value(decimalStr, 'decimalStr', 'Invalid decimal format');
    }

    final whole = int.tryParse(parts[0]) ?? 0;
    int fraction = 0;

    if (parts.length == 2) {
      String fracStr = parts[1];
      if (fracStr.length > currency.decimalDigits) {
        // Truncate/round to supported digits
        fracStr = fracStr.substring(0, currency.decimalDigits);
      } else {
        fracStr = fracStr.padRight(currency.decimalDigits, '0');
      }
      fraction = int.tryParse(fracStr) ?? 0;
    }

    int multiplier = 1;
    for (int i = 0; i < currency.decimalDigits; i++) {
      multiplier *= 10;
    }

    final total = (whole * multiplier) + fraction;
    return Money._(isNegative ? -total : total, currency);
  }

  /// Convenience factory for zero amount.
  factory Money.zero([Currency currency = Currency.pkr]) =>
      Money._(0, currency);

  /// Double representation (for UI presentation ONLY, never calculation).
  double get toDouble {
    int divisor = 1;
    for (int i = 0; i < currency.decimalDigits; i++) {
      divisor *= 10;
    }
    return minorUnits / divisor;
  }

  /// True if amount is zero.
  bool get isZero => minorUnits == 0;

  /// True if amount is strictly positive.
  bool get isPositive => minorUnits > 0;

  /// True if amount is strictly negative.
  bool get isNegative => minorUnits < 0;

  Money operator +(Money other) {
    _assertSameCurrency(other);
    return Money._(minorUnits + other.minorUnits, currency);
  }

  Money operator -(Money other) {
    _assertSameCurrency(other);
    return Money._(minorUnits - other.minorUnits, currency);
  }

  /// Multiplies the monetary amount by an integer factor.
  Money operator *(int factor) {
    return Money._(minorUnits * factor, currency);
  }

  /// Divides monetary amount evenly among [recipients].
  /// Distributes remaining minor units one-by-one so total is strictly preserved (no loss).
  List<Money> allocate(int recipients) {
    if (recipients <= 0) {
      throw ArgumentError.value(recipients, 'recipients', 'Must be greater than 0');
    }
    final base = minorUnits ~/ recipients;
    int remainder = minorUnits.remainder(recipients);

    final result = <Money>[];
    for (int i = 0; i < recipients; i++) {
      int portion = base;
      if (remainder > 0) {
        portion += 1;
        remainder--;
      } else if (remainder < 0) {
        portion -= 1;
        remainder++;
      }
      result.add(Money._(portion, currency));
    }
    return result;
  }

  /// Negates the monetary amount.
  Money operator -() => Money._(-minorUnits, currency);

  bool operator >(Money other) {
    _assertSameCurrency(other);
    return minorUnits > other.minorUnits;
  }

  bool operator <(Money other) {
    _assertSameCurrency(other);
    return minorUnits < other.minorUnits;
  }

  bool operator >=(Money other) {
    _assertSameCurrency(other);
    return minorUnits >= other.minorUnits;
  }

  bool operator <=(Money other) {
    _assertSameCurrency(other);
    return minorUnits <= other.minorUnits;
  }

  @override
  int compareTo(Money other) {
    _assertSameCurrency(other);
    return minorUnits.compareTo(other.minorUnits);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Money &&
          runtimeType == other.runtimeType &&
          other.minorUnits == minorUnits &&
          other.currency == currency);

  @override
  int get hashCode => Object.hash(minorUnits, currency);

  /// Formats the money into readable currency string (e.g., "Rs 1,250.00").
  String format({bool includeSymbol = true}) {
    int divisor = 1;
    for (int i = 0; i < currency.decimalDigits; i++) {
      divisor *= 10;
    }

    final isNeg = minorUnits < 0;
    final absUnits = minorUnits.abs();
    final whole = absUnits ~/ divisor;
    final fraction = absUnits % divisor;

    final fractionStr = fraction.toString().padLeft(currency.decimalDigits, '0');
    final wholeFormatted = _formatWithCommas(whole);

    final sign = isNeg ? '-' : '';
    final symbolPrefix = includeSymbol ? '${currency.symbol} ' : '';

    return '$symbolPrefix$sign$wholeFormatted.$fractionStr';
  }

  String _formatWithCommas(int n) {
    final str = n.toString();
    final buffer = StringBuffer();
    final len = str.length;
    for (int i = 0; i < len; i++) {
      if (i > 0 && (len - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(str[i]);
    }
    return buffer.toString();
  }

  Map<String, dynamic> toJson() => {
        'minorUnits': minorUnits,
        'currency': currency.code,
      };

  factory Money.fromJson(Map<String, dynamic> json) {
    final units = json['minorUnits'] as int;
    final currCode = json['currency'] as String;
    return Money._(units, Currency.fromCode(currCode));
  }

  @override
  String toString() => format();

  void _assertSameCurrency(Money other) {
    if (currency != other.currency) {
      throw ArgumentError(
        'Currency mismatch: Cannot operate on ${currency.code} and ${other.currency.code}',
      );
    }
  }
}
