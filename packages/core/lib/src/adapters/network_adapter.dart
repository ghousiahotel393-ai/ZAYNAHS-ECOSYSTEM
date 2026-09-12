/// Platform Network Connectivity Abstraction Interface and Test Mock.
/// Complies with Rule 47-53 (Offline-first operations & LAN/P2P architecture).
library network_adapter;

import 'dart:async';

enum NetworkType { none, wifi, ethernet, cellular }

class NetworkStatus {
  final bool isConnected;
  final NetworkType type;
  final bool isLanAvailable;
  final String? localIpAddress;

  const NetworkStatus({
    required this.isConnected,
    required this.type,
    required this.isLanAvailable,
    this.localIpAddress,
  });

  Map<String, dynamic> toJson() => {
        'isConnected': isConnected,
        'type': type.name,
        'isLanAvailable': isLanAvailable,
        if (localIpAddress != null) 'localIpAddress': localIpAddress,
      };
}

abstract class NetworkAdapter {
  /// Gets current network connectivity status.
  Future<NetworkStatus> getStatus();

  /// Stream of network status changes.
  Stream<NetworkStatus> get onStatusChanged;

  /// Checks whether a specific host and port is reachable via TCP.
  Future<bool> isHostReachable(String host, int port, {Duration timeout = const Duration(seconds: 3)});
}

/// Headless Mock Network Adapter for Testing offline/online transitions.
class MockNetworkAdapter implements NetworkAdapter {
  final StreamController<NetworkStatus> _controller = StreamController<NetworkStatus>.broadcast();
  NetworkStatus _current = const NetworkStatus(
    isConnected: true,
    type: NetworkType.wifi,
    isLanAvailable: true,
    localIpAddress: '192.168.1.100',
  );

  void setNetworkStatus(NetworkStatus status) {
    _current = status;
    _controller.add(status);
  }

  void simulateOffline() {
    setNetworkStatus(const NetworkStatus(
      isConnected: false,
      type: NetworkType.none,
      isLanAvailable: false,
    ));
  }

  void simulateOnline({bool lanOnly = false}) {
    setNetworkStatus(NetworkStatus(
      isConnected: !lanOnly,
      type: NetworkType.wifi,
      isLanAvailable: true,
      localIpAddress: '192.168.1.100',
    ));
  }

  @override
  Future<NetworkStatus> getStatus() async => _current;

  @override
  Stream<NetworkStatus> get onStatusChanged => _controller.stream;

  @override
  Future<bool> isHostReachable(String host, int port, {Duration timeout = const Duration(seconds: 3)}) async {
    return _current.isConnected || _current.isLanAvailable;
  }
}
