/// Structured logger with strict automatic secret redaction.
/// Complies with Rule 79-80 (Zero secrets in logs) and Section 54.
library logger;

enum LogLevel { debug, info, warn, error, audit }

class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final String tag;
  final String message;
  final Map<String, dynamic>? metadata;
  final Object? error;
  final StackTrace? stackTrace;

  LogEntry({
    required this.timestamp,
    required this.level,
    required this.tag,
    required this.message,
    this.metadata,
    this.error,
    this.stackTrace,
  });

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'level': level.name.toUpperCase(),
        'tag': tag,
        'message': message,
        if (metadata != null) 'metadata': metadata,
        if (error != null) 'error': error.toString(),
        if (stackTrace != null) 'stackTrace': stackTrace.toString(),
      };

  @override
  String toString() {
    final metaStr = metadata != null && metadata!.isNotEmpty ? ' $metadata' : '';
    final errStr = error != null ? '\nError: $error' : '';
    return '[${timestamp.toIso8601String()}] [${level.name.toUpperCase()}] [$tag] $message$metaStr$errStr';
  }
}

typedef LogSink = void Function(LogEntry entry);

class AppLogger {
  final String tag;
  final LogLevel minLevel;
  final List<LogSink> _sinks;

  static final List<RegExp> _sensitivePatterns = [
    // Bearer token
    RegExp(r'(bearer\s+)[a-zA-Z0-9_\-\.]+', caseSensitive: false),
    // Passwords & PINs
    RegExp(r'(["' + "'" + r']?(?:password|passwd|pin|secret|api_key|token)["' + "'" + r']?\s*[:=]\s*["' + "'" + r']?)([^"' + "'" + r'\s,]+)', caseSensitive: false),
    // Cloudflare / Supabase API tokens
    RegExp(r'cfut_[a-zA-Z0-9]+', caseSensitive: false),
    RegExp(r'eyJ[a-zA-Z0-9_\-]+\.eyJ[a-zA-Z0-9_\-]+\.[a-zA-Z0-9_\-]+', caseSensitive: false), // JWT
    // Credit card patterns
    RegExp(r'\b(?:\d[ -]*?){13,16}\b'),
  ];

  static const String _redactedPlaceholder = '[REDACTED]';

  AppLogger({
    this.tag = 'App',
    this.minLevel = LogLevel.debug,
    List<LogSink>? sinks,
  }) : _sinks = sinks ?? [_defaultConsoleSink];

  static void _defaultConsoleSink(LogEntry entry) {
    // Standard platform output
    // ignore: avoid_print
    print(entry.toString());
  }

  /// Redacts sensitive patterns from a string.
  static String redact(String input) {
    var result = input;
    for (final pattern in _sensitivePatterns) {
      result = result.replaceAllMapped(pattern, (match) {
        if (match.groupCount >= 2) {
          return '${match.group(1)}$_redactedPlaceholder';
        }
        return _redactedPlaceholder;
      });
    }
    return result;
  }

  /// Recursively redacts maps and nested structures.
  static dynamic redactValue(dynamic value) {
    if (value is String) {
      return redact(value);
    } else if (value is Map) {
      return value.map<String, dynamic>((k, v) {
        final keyStr = k.toString().toLowerCase();
        if (keyStr.contains('password') ||
            keyStr.contains('secret') ||
            keyStr.contains('token') ||
            keyStr.contains('pin') ||
            keyStr.contains('key')) {
          return MapEntry(k.toString(), _redactedPlaceholder);
        }
        return MapEntry(k.toString(), redactValue(v));
      });
    } else if (value is Iterable) {
      return value.map((item) => redactValue(item)).toList();
    }
    return value;
  }

  void _log(
    LogLevel level,
    String message, {
    Map<String, dynamic>? metadata,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (level.index < minLevel.index) return;

    final sanitizedMessage = redact(message);
    final sanitizedMetadata = metadata != null ? redactValue(metadata) as Map<String, dynamic> : null;

    final entry = LogEntry(
      timestamp: DateTime.now().toUtc(),
      level: level,
      tag: tag,
      message: sanitizedMessage,
      metadata: sanitizedMetadata,
      error: error,
      stackTrace: stackTrace,
    );

    for (final sink in _sinks) {
      try {
        sink(entry);
      } catch (_) {
        // Silently prevent logger crash
      }
    }
  }

  void debug(String message, [Map<String, dynamic>? metadata]) =>
      _log(LogLevel.debug, message, metadata: metadata);

  void info(String message, [Map<String, dynamic>? metadata]) =>
      _log(LogLevel.info, message, metadata: metadata);

  void warn(String message, [Map<String, dynamic>? metadata]) =>
      _log(LogLevel.warn, message, metadata: metadata);

  void error(String message, {Object? error, StackTrace? stackTrace, Map<String, dynamic>? metadata}) =>
      _log(LogLevel.error, message, metadata: metadata, error: error, stackTrace: stackTrace);

  /// Structured audit log for ledger, auth, and trust lifecycle events.
  void audit(String action, {required String actorId, required Map<String, dynamic> details}) {
    _log(
      LogLevel.audit,
      'AUDIT: $action by $actorId',
      metadata: {
        'action': action,
        'actorId': actorId,
        'details': details,
      },
    );
  }

  /// Creates a child logger with a sub-tag.
  AppLogger child(String subTag) => AppLogger(
        tag: '$tag.$subTag',
        minLevel: minLevel,
        sinks: _sinks,
      );
}
