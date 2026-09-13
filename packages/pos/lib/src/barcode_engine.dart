/// Barcode and QR Code Engine for Zaynahs Ecosystem.
/// Enforces Rule 96, Section 02: Modulo-10 checksum validation for EAN-13 and UPC-A,
/// Code 128 format validation, and QR Code receipt payload generation.
library barcode_engine;

import 'dart:convert';
import 'package:crypto/crypto.dart';

enum BarcodeFormat {
  ean13,
  upcA,
  code128,
  qrCode,
  unknown,
}

class BarcodeEngine {
  /// Computes Modulo-10 check digit for an EAN-13 barcode (first 12 digits input).
  static int calculateEan13CheckDigit(String first12Digits) {
    if (first12Digits.length != 12 || !RegExp(r'^\d{12}$').hasMatch(first12Digits)) {
      throw ArgumentError('Input must be exactly 12 digits for EAN-13 check digit calculation.');
    }

    var sum = 0;
    for (var i = 0; i < 12; i++) {
      final digit = int.parse(first12Digits[i]);
      // Odd position (0, 2, 4... in 0-indexed) weight 1, Even position weight 3
      sum += (i % 2 == 0) ? digit : digit * 3;
    }

    final mod = sum % 10;
    return mod == 0 ? 0 : 10 - mod;
  }

  /// Verifies a complete 13-digit EAN-13 barcode against its Modulo-10 check digit.
  static bool isValidEan13(String barcode) {
    if (barcode.length != 13 || !RegExp(r'^\d{13}$').hasMatch(barcode)) {
      return false;
    }
    final first12 = barcode.substring(0, 12);
    final expectedCheckDigit = calculateEan13CheckDigit(first12);
    final actualCheckDigit = int.parse(barcode[12]);
    return expectedCheckDigit == actualCheckDigit;
  }

  /// Computes Modulo-10 check digit for a UPC-A barcode (first 11 digits input).
  static int calculateUpcACheckDigit(String first11Digits) {
    if (first11Digits.length != 11 || !RegExp(r'^\d{11}$').hasMatch(first11Digits)) {
      throw ArgumentError('Input must be exactly 11 digits for UPC-A check digit calculation.');
    }

    var sum = 0;
    for (var i = 0; i < 11; i++) {
      final digit = int.parse(first11Digits[i]);
      // Odd position (0, 2, 4... in 0-indexed) weight 3, Even position weight 1
      sum += (i % 2 == 0) ? digit * 3 : digit;
    }

    final mod = sum % 10;
    return mod == 0 ? 0 : 10 - mod;
  }

  /// Verifies a complete 12-digit UPC-A barcode against its Modulo-10 check digit.
  static bool isValidUpcA(String barcode) {
    if (barcode.length != 12 || !RegExp(r'^\d{12}$').hasMatch(barcode)) {
      return false;
    }
    final first11 = barcode.substring(0, 11);
    final expectedCheckDigit = calculateUpcACheckDigit(first11);
    final actualCheckDigit = int.parse(barcode[11]);
    return expectedCheckDigit == actualCheckDigit;
  }

  /// Validates standard Code 128 characters (ASCII 32 to 126).
  static bool isValidCode128(String barcode) {
    if (barcode.isEmpty) return false;
    for (var i = 0; i < barcode.length; i++) {
      final code = barcode.codeUnitAt(i);
      if (code < 32 || code > 126) return false;
    }
    return true;
  }

  /// Detects the barcode format and validates its integrity.
  static BarcodeFormat detectAndValidate(String code) {
    if (isValidEan13(code)) return BarcodeFormat.ean13;
    if (isValidUpcA(code)) return BarcodeFormat.upcA;
    if (isValidCode128(code)) return BarcodeFormat.code128;
    return BarcodeFormat.unknown;
  }

  /// Generates a standardized, compact QR payload for receipt verification.
  static String generateReceiptQrPayload({
    required String invoiceNumber,
    required int totalMinor,
    required String currency,
    required DateTime timestamp,
    required String deviceId,
  }) {
    final rawData = '$invoiceNumber|$totalMinor|$currency|${timestamp.toIso8601String()}|$deviceId';
    final signatureHash = sha256.convert(utf8.encode(rawData)).toString().substring(0, 16);
    return 'ZYN:$rawData|$signatureHash';
  }
}
