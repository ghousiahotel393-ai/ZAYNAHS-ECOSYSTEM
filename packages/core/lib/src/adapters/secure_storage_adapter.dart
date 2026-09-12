/// Platform Secure Storage Abstraction Interface and Test Mock.
/// Complies with Rule 79-80 (Hardware-backed encrypted secret storage).
library secure_storage_adapter;

abstract class SecureStorageAdapter {
  /// Reads a secure secret value by key.
  Future<String?> read(String key);

  /// Writes a secure secret key-value pair.
  Future<void> write(String key, String value);

  /// Deletes a key from secure storage.
  Future<void> delete(String key);

  /// Checks if a key exists in secure storage.
  Future<bool> containsKey(String key);

  /// Clears all keys from secure storage.
  Future<void> deleteAll();
}

/// In-memory Secure Storage Adapter for testing and fallback environments.
class InMemorySecureStorageAdapter implements SecureStorageAdapter {
  final Map<String, String> _storage = {};

  @override
  Future<String?> read(String key) async => _storage[key];

  @override
  Future<void> write(String key, String value) async {
    _storage[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _storage.remove(key);
  }

  @override
  Future<bool> containsKey(String key) async => _storage.containsKey(key);

  @override
  Future<void> deleteAll() async {
    _storage.clear();
  }
}
