/// Cryptographic utilities for password hashing, salted PINs, and constant-time checks.
/// Enforces Rule 79-80 (Secure credential protection, timing-attack resistance).
library crypto_utils;

import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

class CryptoUtils {
  static final Random _secureRandom = Random.secure();

  /// Generates a hex-encoded cryptographically secure salt.
  static String generateSalt([int length = 16]) {
    final bytes = List<int>.generate(length, (_) => _secureRandom.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Hashes a password using PBKDF2-HMAC-SHA256 simulation with 10,000 rounds.
  /// Result format: `pbkdf2$iterations$salt$hash`
  static String hashPassword(String password, {String? salt, int iterations = 10000}) {
    final effectiveSalt = salt ?? generateSalt(16);
    var key = utf8.encode(password);
    var current = Hmac(sha256, key).convert(utf8.encode(effectiveSalt)).bytes;

    for (int i = 1; i < iterations; i++) {
      current = Hmac(sha256, key).convert(current).bytes;
    }

    final hashHex = current.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return 'pbkdf2\$$iterations\$$effectiveSalt\$$hashHex';
  }

  /// Verifies a plain password against a stored `pbkdf2$...` hash in constant time.
  static bool verifyPassword(String password, String storedHash) {
    final parts = storedHash.split('\$');
    if (parts.length != 4 || parts[0] != 'pbkdf2') {
      return false;
    }

    final iterations = int.tryParse(parts[1]) ?? 10000;
    final salt = parts[2];
    final expectedHash = parts[3];

    final calculated = hashPassword(password, salt: salt, iterations: iterations);
    final calculatedParts = calculated.split('\$');
    if (calculatedParts.length != 4) return false;

    return constantTimeEquals(calculatedParts[3], expectedHash);
  }

  /// Hashes a fast unlock numeric PIN (4-6 digits) with a random salt.
  /// Result format: `pin$salt$hash`
  static String hashPin(String pin, {String? salt}) {
    final effectiveSalt = salt ?? generateSalt(16);
    final bytes = utf8.encode('$effectiveSalt:$pin');
    final digest = sha256.convert(bytes);
    return 'pin\$$effectiveSalt\$$digest';
  }

  /// Verifies a numeric PIN against a stored `pin$...` hash in constant time.
  static bool verifyPin(String pin, String storedHash) {
    final parts = storedHash.split('\$');
    if (parts.length != 3 || parts[0] != 'pin') {
      return false;
    }

    final salt = parts[1];
    final expectedHash = parts[2];

    final calculated = hashPin(pin, salt: salt);
    final calculatedParts = calculated.split('\$');
    if (calculatedParts.length != 3) return false;

    return constantTimeEquals(calculatedParts[2], expectedHash);
  }

  /// Constant-time string equality check to eliminate timing side-channel attacks.
  static bool constantTimeEquals(String a, String b) {
    if (a.length != b.length) {
      return false;
    }

    int result = 0;
    for (int i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
  }

  /// Computes SHA-256 fingerprint of a public key or device payload.
  static String fingerprint(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Generates a random 6-digit numeric pairing challenge code.
  static String generatePairingCode() {
    final code = _secureRandom.nextInt(900000) + 100000;
    return code.toString();
  }

  /// Generates a pseudo-random Ed25519-format public/private keypair token for peer authentication.
  static Map<String, String> generateDeviceKeypair() {
    final privSalt = generateSalt(32);
    final privKey = 'priv_ed25519_$privSalt';
    final pubKey = 'pub_ed25519_${fingerprint(privKey).substring(0, 44)}';
    return {
      'publicKey': pubKey,
      'privateKey': privKey,
    };
  }
}
