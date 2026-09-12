/// Unified configuration management for Zaynahs Ecosystem.
/// Safely loads and validates environment settings across all deployment targets.
library config;

class AppConfig {
  final String environment;
  final String appVersion;
  final String ecosystemName;
  final String supabaseUrl;
  final String supabaseAnonKey;
  final String cloudflareAccountId;
  final String cloudflareApiToken;
  final String cloudflareSignalingUrl;
  final String storageBasePath;
  final int localP2pPort;
  final bool enableDebugLogs;

  const AppConfig({
    required this.environment,
    required this.appVersion,
    required this.ecosystemName,
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.cloudflareAccountId,
    required this.cloudflareApiToken,
    required this.cloudflareSignalingUrl,
    required this.storageBasePath,
    this.localP2pPort = 53317,
    this.enableDebugLogs = true,
  });

  bool get isProduction => environment.toLowerCase() == 'production';
  bool get isDevelopment => !isProduction;

  /// Creates AppConfig from a key-value environment map.
  factory AppConfig.fromMap(Map<String, String> env) {
    return AppConfig(
      environment: env['ENVIRONMENT'] ?? 'development',
      appVersion: env['APP_VERSION'] ?? '1.0.0',
      ecosystemName: env['ECOSYSTEM_NAME'] ?? 'Zaynahs Ecosystem',
      supabaseUrl: env['SUPABASE_URL'] ?? '',
      supabaseAnonKey: env['SUPABASE_ANON_KEY'] ?? '',
      cloudflareAccountId: env['CLOUDFLARE_ACCOUNT_ID'] ?? '',
      cloudflareApiToken: env['CLOUDFLARE_API_TOKEN'] ?? '',
      cloudflareSignalingUrl: env['CLOUDFLARE_SIGNALING_URL'] ??
          'wss://zaynahs-signaling.ghousiahotel393.workers.dev/ws',
      storageBasePath: env['STORAGE_BASE_PATH'] ?? './data',
      localP2pPort: int.tryParse(env['LOCAL_P2P_PORT'] ?? '53317') ?? 53317,
      enableDebugLogs: (env['ENABLE_DEBUG_LOGS'] ?? 'true').toLowerCase() == 'true',
    );
  }

  /// Parses a raw `.env` or `.env.local` file content string into key-value map.
  static Map<String, String> parseEnvString(String content) {
    final result = <String, String>{};
    final lines = content.split('\n');

    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty || line.startsWith('#')) continue;

      final eqIdx = line.indexOf('=');
      if (eqIdx <= 0) continue;

      final key = line.substring(0, eqIdx).trim();
      var val = line.substring(eqIdx + 1).trim();

      // Strip matching single/double quotes if present
      if ((val.startsWith('"') && val.endsWith('"')) ||
          (val.startsWith("'") && val.endsWith("'"))) {
        if (val.length >= 2) {
          val = val.substring(1, val.length - 1);
        }
      }

      result[key] = val;
    }
    return result;
  }

  /// Validates that critical configuration items are present.
  List<String> validate() {
    final errors = <String>[];
    if (ecosystemName.isEmpty) {
      errors.add('ECOSYSTEM_NAME cannot be empty');
    }
    if (isProduction) {
      if (supabaseUrl.isEmpty) {
        errors.add('SUPABASE_URL is required in production');
      }
      if (supabaseAnonKey.isEmpty) {
        errors.add('SUPABASE_ANON_KEY is required in production');
      }
      if (cloudflareAccountId.isEmpty) {
        errors.add('CLOUDFLARE_ACCOUNT_ID is required in production');
      }
    }
    return errors;
  }

  @override
  String toString() =>
      'AppConfig(env: $environment, version: $appVersion, ecosystem: $ecosystemName, p2pPort: $localP2pPort)';
}
