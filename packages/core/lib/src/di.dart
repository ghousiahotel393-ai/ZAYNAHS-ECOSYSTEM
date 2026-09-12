/// Deterministic Service Locator and Dependency Injection Container.
/// Supports layered bootstrap lifecycle (Foundation -> Adapters -> Domain -> Presentation).
library di;

typedef FactoryFunc<T> = T Function();

enum DiLifecycleTier {
  foundation, // Config, Logger, Crypto
  adapters,   // Platform hardware, Storage, Network
  domain,     // Repositories, UseCases, Ledgers
  presentation // State managers, ViewModels, Controllers
}

class ServiceLocator {
  static final ServiceLocator _instance = ServiceLocator._internal();
  factory ServiceLocator() => _instance;
  ServiceLocator._internal();

  final Map<Type, dynamic> _singletons = {};
  final Map<Type, FactoryFunc<dynamic>> _lazySingletons = {};
  final Map<Type, FactoryFunc<dynamic>> _factories = {};
  final Map<Type, DiLifecycleTier> _tiers = {};

  DiLifecycleTier _currentTier = DiLifecycleTier.foundation;
  DiLifecycleTier get currentTier => _currentTier;

  /// Sets the active registration lifecycle tier.
  void setTier(DiLifecycleTier tier) {
    _currentTier = tier;
  }

  /// Registers an already instantiated singleton.
  void registerSingleton<T extends Object>(T instance, {DiLifecycleTier? tier}) {
    final type = T;
    if (_isRegistered(type)) {
      throw StateError('Service $type is already registered.');
    }
    _singletons[type] = instance;
    _tiers[type] = tier ?? _currentTier;
  }

  /// Registers a lazy singleton created on first retrieval.
  void registerLazySingleton<T extends Object>(FactoryFunc<T> factory, {DiLifecycleTier? tier}) {
    final type = T;
    if (_isRegistered(type)) {
      throw StateError('Service $type is already registered.');
    }
    _lazySingletons[type] = factory;
    _tiers[type] = tier ?? _currentTier;
  }

  /// Registers a factory that provides a new instance on each call.
  void registerFactory<T extends Object>(FactoryFunc<T> factory, {DiLifecycleTier? tier}) {
    final type = T;
    if (_isRegistered(type)) {
      throw StateError('Service $type is already registered.');
    }
    _factories[type] = factory;
    _tiers[type] = tier ?? _currentTier;
  }

  /// Checks whether a type is registered.
  bool isRegistered<T extends Object>() => _isRegistered(T);

  bool _isRegistered(Type type) =>
      _singletons.containsKey(type) ||
      _lazySingletons.containsKey(type) ||
      _factories.containsKey(type);

  /// Retrieves an instance of type [T]. Throws StateError if not found.
  T get<T extends Object>() {
    final type = T;

    if (_singletons.containsKey(type)) {
      return _singletons[type] as T;
    }

    if (_lazySingletons.containsKey(type)) {
      final factory = _lazySingletons.remove(type)!;
      final instance = factory() as T;
      _singletons[type] = instance;
      return instance;
    }

    if (_factories.containsKey(type)) {
      return _factories[type]!() as T;
    }

    throw StateError('No registration found for service type: $T');
  }

  /// Tries to retrieve an instance of type [T], or null if not registered.
  T? tryGet<T extends Object>() {
    try {
      if (isRegistered<T>()) {
        return get<T>();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Unregisters a specific service type.
  void unregister<T extends Object>() {
    final type = T;
    _singletons.remove(type);
    _lazySingletons.remove(type);
    _factories.remove(type);
    _tiers.remove(type);
  }

  /// Resets the entire DI container (strictly for unit tests).
  void reset() {
    _singletons.clear();
    _lazySingletons.clear();
    _factories.clear();
    _tiers.clear();
    _currentTier = DiLifecycleTier.foundation;
  }

  /// Returns registration summary for debugging.
  Map<String, String> getRegisteredServices() {
    final map = <String, String>{};
    for (final type in _singletons.keys) {
      map[type.toString()] = 'Singleton (${_tiers[type]?.name})';
    }
    for (final type in _lazySingletons.keys) {
      map[type.toString()] = 'LazySingleton (${_tiers[type]?.name})';
    }
    for (final type in _factories.keys) {
      map[type.toString()] = 'Factory (${_tiers[type]?.name})';
    }
    return map;
  }
}

/// Global convenience accessor.
final sl = ServiceLocator();
