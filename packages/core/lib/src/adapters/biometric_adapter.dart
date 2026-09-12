/// Platform Biometric Authentication Abstraction Interface and Test Mock.
/// Complies with Rule 69-78 (Role-based access & rapid manager authorization).
library biometric_adapter;

enum BiometricType { fingerprint, face, iris }

abstract class BiometricAdapter {
  /// Checks if hardware biometrics are supported and enrolled on this device.
  Future<bool> canAuthenticateWithBiometrics();

  /// Lists available biometric hardware types.
  Future<List<BiometricType>> getAvailableBiometrics();

  /// Prompts the user to authenticate with biometrics.
  Future<bool> authenticate({
    required String localizedReason,
    bool fallbackToPin = true,
  });
}

/// Headless Mock Biometric Adapter for Testing.
class MockBiometricAdapter implements BiometricAdapter {
  bool _canAuthenticate = true;
  bool _authenticationSuccess = true;
  List<BiometricType> _availableBiometrics = [BiometricType.fingerprint, BiometricType.face];

  void configure({
    bool? canAuthenticate,
    bool? authenticationSuccess,
    List<BiometricType>? availableBiometrics,
  }) {
    if (canAuthenticate != null) _canAuthenticate = canAuthenticate;
    if (authenticationSuccess != null) _authenticationSuccess = authenticationSuccess;
    if (availableBiometrics != null) _availableBiometrics = availableBiometrics;
  }

  @override
  Future<bool> canAuthenticateWithBiometrics() async => _canAuthenticate;

  @override
  Future<List<BiometricType>> getAvailableBiometrics() async =>
      List.unmodifiable(_availableBiometrics);

  @override
  Future<bool> authenticate({
    required String localizedReason,
    bool fallbackToPin = true,
  }) async => _authenticationSuccess;
}
