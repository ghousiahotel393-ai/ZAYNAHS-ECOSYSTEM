/// Secret & Credential Scanner for Zaynahs Ecosystem.
/// Enforces Rule 79-80, 103 (Zero secrets in git, logs, or network payloads).
library secret_scanner;

import 'dart:io';

class SecretFinding {
  final String rule;
  final String description;
  final String matchedSnippet;
  final int lineNumber;
  final String? source;

  const SecretFinding({
    required this.rule,
    required this.description,
    required this.matchedSnippet,
    required this.lineNumber,
    this.source,
  });

  @override
  String toString() =>
      '[$rule] $description at line $lineNumber (${source ?? "text"}): $matchedSnippet';
}

class SecretScanner {
  static final List<RegExp> secretPatterns = [
    // 1. Private Keys
    RegExp(r'-----BEGIN [A-Z ]*PRIVATE KEY-----', caseSensitive: false),

    // 2. Bearer Tokens (JWT / long access tokens)
    RegExp(r'Bearer\s+[A-Za-z0-9_\-\.]{25,}', caseSensitive: false),

    // 3. Cloudflare User / API Tokens (cfut_...)
    RegExp(r'cfut_[a-zA-Z0-9_\-]{30,}', caseSensitive: false),

    // 4. AWS Access Keys
    RegExp(r'\b(AKIA|ABIA|ACCA|ASIA)[0-9A-Z]{16}\b'),

    // 5. Plaintext password fields with actual assigned values
    RegExp(r'''["']?(?:password|client_secret|private_key)["']?\s*[:=]\s*["']([^"'\s]{6,})["']''',
        caseSensitive: false),
  ];

  /// Scans a text buffer or log snippet for secret violations.
  static List<SecretFinding> scanText(String text, {String? sourceName}) {
    final findings = <SecretFinding>[];
    final lines = text.split('\n');

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      // Ignore known dummy test values or redaction markers
      if (line.contains('[REDACTED]') ||
          line.contains('REDACTED') ||
          line.contains('dummy_') ||
          line.contains('mock_') ||
          line.contains('example')) {
        continue;
      }

      for (final pattern in secretPatterns) {
        final match = pattern.firstMatch(line);
        if (match != null) {
          final matched = match.group(0) ?? '';
          findings.add(SecretFinding(
            rule: 'ZERO_SECRETS_VIOLATION',
            description: 'Detected potentially exposed secret or credential pattern',
            matchedSnippet: matched.length > 20 ? '${matched.substring(0, 16)}...' : matched,
            lineNumber: i + 1,
            source: sourceName,
          ));
        }
      }
    }

    return findings;
  }

  /// Scans a directory recursively (skipping .git, build, artifacts, test mocks).
  static List<SecretFinding> scanDirectory(
    Directory dir, {
    List<String> ignorePaths = const ['.git', '.dart_tool', 'build', '.gemini', 'node_modules'],
  }) {
    final findings = <SecretFinding>[];
    if (!dir.existsSync()) return findings;

    for (final entity in dir.listSync(recursive: true, followLinks: false)) {
      if (entity is File) {
        final path = entity.path;
        if (ignorePaths.any((p) => path.contains(p))) continue;

        // Scan only relevant source/config extensions
        if (!path.endsWith('.dart') &&
            !path.endsWith('.yaml') &&
            !path.endsWith('.json') &&
            !path.endsWith('.md')) {
          continue;
        }

        try {
          final content = entity.readAsStringSync();
          final fileFindings = scanText(content, sourceName: path);
          findings.addAll(fileFindings);
        } catch (_) {
          // Skip binary or unreadable files
        }
      }
    }

    return findings;
  }

  /// Asserts that a log string contains zero unredacted secrets.
  /// Throws StateError on violation.
  static void assertZeroSecrets(String text, {String? context}) {
    final violations = scanText(text, sourceName: context);
    if (violations.isNotEmpty) {
      throw StateError(
        'Secret leak detected in ${context ?? "log text"}: ${violations.join("; ")}',
      );
    }
  }
}
