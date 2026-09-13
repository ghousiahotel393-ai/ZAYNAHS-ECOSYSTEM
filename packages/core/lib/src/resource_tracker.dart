/// Resource Tracker for Memory and Resource Leak Profiling.
/// Enforces Rule 99-105: All streams, DB connections, sockets, and controllers
/// must be properly tracked and disposed without memory leaks.
library resource_tracker;


class TrackedResource {
  final String id;
  final String category;
  final DateTime allocatedAt;
  final StackTrace? stackTrace;
  bool isDisposed = false;

  TrackedResource({
    required this.id,
    required this.category,
    required this.allocatedAt,
    this.stackTrace,
  });
}

class ResourceTracker {
  static final ResourceTracker _instance = ResourceTracker._internal();
  factory ResourceTracker() => _instance;
  ResourceTracker._internal();

  final Map<String, TrackedResource> _activeResources = {};

  /// Registers an allocated resource.
  void track(String id, String category) {
    _activeResources[id] = TrackedResource(
      id: id,
      category: category,
      allocatedAt: DateTime.now().toUtc(),
      stackTrace: StackTrace.current,
    );
  }

  /// Marks a resource as safely disposed.
  void untrack(String id) {
    final res = _activeResources[id];
    if (res != null) {
      res.isDisposed = true;
      _activeResources.remove(id);
    }
  }

  /// Number of currently open resources.
  int get activeCount => _activeResources.length;

  /// Returns unclosed resources by category.
  List<TrackedResource> getUnreleasedResources([String? category]) {
    if (category == null) {
      return _activeResources.values.toList();
    }
    return _activeResources.values.where((r) => r.category == category).toList();
  }

  /// Asserts that all resources in a category have been released.
  /// Throws StateError if any dangling resources remain.
  void assertAllReleased([String? category]) {
    final unreleased = getUnreleasedResources(category);
    if (unreleased.isNotEmpty) {
      final ids = unreleased.map((r) => '${r.category}:${r.id}').join(', ');
      throw StateError(
        'Resource leak detected: ${unreleased.length} resources not disposed: $ids',
      );
    }
  }

  /// Clears tracker state (for test isolation).
  void reset() {
    _activeResources.clear();
  }
}
