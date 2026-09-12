/// Platform System & Hardware Information Abstraction Interface and Test Mock.
/// Complies with Rule 99-105 (Performance & Resource limits).
library system_info_adapter;

enum OperatingSystemType { macOS, windows, linux, android, iOS, web, unknown }

class SystemInfo {
  final OperatingSystemType osType;
  final String osVersion;
  final String deviceModel;
  final int cpuCores;
  final int totalMemoryMb;
  final int freeDiskSpaceMb;

  const SystemInfo({
    required this.osType,
    required this.osVersion,
    required this.deviceModel,
    required this.cpuCores,
    required this.totalMemoryMb,
    required this.freeDiskSpaceMb,
  });

  Map<String, dynamic> toJson() => {
        'osType': osType.name,
        'osVersion': osVersion,
        'deviceModel': deviceModel,
        'cpuCores': cpuCores,
        'totalMemoryMb': totalMemoryMb,
        'freeDiskSpaceMb': freeDiskSpaceMb,
      };
}

abstract class SystemInfoAdapter {
  /// Retrieves host system and hardware specifications.
  Future<SystemInfo> getSystemInfo();

  /// Gets free disk space in megabytes for storage volume.
  Future<int> getFreeDiskSpaceMb(String directoryPath);
}

/// Mock System Info Adapter for Testing.
class MockSystemInfoAdapter implements SystemInfoAdapter {
  SystemInfo _mockInfo = const SystemInfo(
    osType: OperatingSystemType.macOS,
    osVersion: 'macOS 13.6',
    deviceModel: 'MacBook Pro (x86_64)',
    cpuCores: 8,
    totalMemoryMb: 16384,
    freeDiskSpaceMb: 128000,
  );

  void setSystemInfo(SystemInfo info) {
    _mockInfo = info;
  }

  @override
  Future<SystemInfo> getSystemInfo() async => _mockInfo;

  @override
  Future<int> getFreeDiskSpaceMb(String directoryPath) async =>
      _mockInfo.freeDiskSpaceMb;
}
