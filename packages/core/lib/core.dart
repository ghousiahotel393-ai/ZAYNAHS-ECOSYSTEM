/// Zaynahs Ecosystem — Core Architecture Base Library
/// Exporting all domain primitives, functional result types, error hierarchy,
/// configuration, secret-redacted logging, DI container, and platform hardware adapters.
library core;

export 'src/result.dart';
export 'src/exceptions.dart';
export 'src/identifiers.dart';
export 'src/money.dart';
export 'src/config.dart';
export 'src/logger.dart';
export 'src/di.dart';

// Platform Adapters
export 'src/adapters/camera_adapter.dart';
export 'src/adapters/printer_adapter.dart';
export 'src/adapters/location_adapter.dart';
export 'src/adapters/screen_adapter.dart';
export 'src/adapters/biometric_adapter.dart';
export 'src/adapters/secure_storage_adapter.dart';
export 'src/adapters/network_adapter.dart';
export 'src/adapters/system_info_adapter.dart';
