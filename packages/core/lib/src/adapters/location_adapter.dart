/// Platform Location Abstraction Interface and Test Mock.
/// Complies with Rule 54 (Strict Location Privacy & Zero Covert Tracking).
library location_adapter;

class LocationCoordinates {
  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final DateTime timestamp;

  const LocationCoordinates({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
        'accuracyMeters': accuracyMeters,
        'timestamp': timestamp.toIso8601String(),
      };
}

abstract class LocationAdapter {
  /// Checks if location services are enabled on the operating system.
  Future<bool> isLocationServiceEnabled();

  /// Requests explicit location permission from the user.
  Future<bool> requestPermission();

  /// Checks if location permission has been explicitly granted.
  Future<bool> hasPermission();

  /// Gets the current location coordinate.
  /// Strictly requires user consent; never called covertly in background without user knowledge.
  Future<LocationCoordinates?> getCurrentLocation();
}

/// Mock Location Adapter for Testing.
class MockLocationAdapter implements LocationAdapter {
  bool _serviceEnabled = true;
  bool _permissionGranted = true;
  LocationCoordinates? _mockLocation = LocationCoordinates(
    latitude: 24.8607,
    longitude: 67.0011, // Karachi, Pakistan
    accuracyMeters: 5.0,
    timestamp: DateTime.now(),
  );

  void configure({bool? serviceEnabled, bool? permissionGranted, LocationCoordinates? location}) {
    if (serviceEnabled != null) _serviceEnabled = serviceEnabled;
    if (permissionGranted != null) _permissionGranted = permissionGranted;
    if (location != null) _mockLocation = location;
  }

  @override
  Future<bool> isLocationServiceEnabled() async => _serviceEnabled;

  @override
  Future<bool> requestPermission() async => _permissionGranted;

  @override
  Future<bool> hasPermission() async => _permissionGranted;

  @override
  Future<LocationCoordinates?> getCurrentLocation() async {
    if (!_serviceEnabled || !_permissionGranted) return null;
    return _mockLocation;
  }
}
