/// Strict local filesystem taxonomy and path traversal jail.
/// Enforces Rule 97-98, Rule 106-119, and Section 82-83.
library storage_taxonomy;

import 'dart:io';

enum StorageCategory {
  database('app_data/database'),
  mediaProducts('media/products'),
  mediaChat('media/chat'),
  mediaDocuments('media/documents'),
  cctvRecordings('cctv/recordings'),
  cctvSnapshots('cctv/snapshots'),
  backupsDaily('backups/daily'),
  backupsManual('backups/manual'),
  cache('cache'),
  temp('temp');

  final String relativePath;
  const StorageCategory(this.relativePath);
}

class StorageTaxonomy {
  final String baseDirectoryPath;

  StorageTaxonomy(this.baseDirectoryPath);

  Directory get baseDirectory => Directory(baseDirectoryPath);

  /// Resolves the absolute directory path for a category.
  Directory getCategoryDirectory(StorageCategory category) {
    return Directory('$baseDirectoryPath/${category.relativePath}');
  }

  /// Ensures all category directories exist on disk.
  void initializeDirectories() {
    for (final cat in StorageCategory.values) {
      final dir = getCategoryDirectory(cat);
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
    }
  }

  /// Sanitizes a file name or relative subpath, strictly preventing path traversal attacks.
  /// Throws [SecurityException] if path attempts to escape category jail.
  String sanitizeAndJailPath(StorageCategory category, String relativeFilePath) {
    var clean = relativeFilePath.trim();

    // 1. Block directory traversal sequences
    if (clean.contains('..') ||
        clean.contains('\x00') ||
        clean.startsWith('/') ||
        clean.startsWith('\\')) {
      throw ArgumentError.value(
        relativeFilePath,
        'relativeFilePath',
        'Directory traversal / absolute path attack detected. Path is jailed.',
      );
    }

    // 2. Strip dangerous characters
    clean = clean.replaceAll(RegExp(r'[^a-zA-Z0-9_\-\.\/]'), '_');

    // 3. Normalize double slashes
    while (clean.contains('//')) {
      clean = clean.replaceAll('//', '/');
    }

    // 4. Verify canonical containment
    final categoryDir = getCategoryDirectory(category);
    final targetFile = File('${categoryDir.path}/$clean');
    final canonicalBase = Directory(categoryDir.path).resolveSymbolicLinksSync();

    // If file exists, check resolved link; if not, check parent
    final parentDir = targetFile.parent;
    if (parentDir.existsSync()) {
      final canonicalParent = parentDir.resolveSymbolicLinksSync();
      if (!canonicalParent.startsWith(canonicalBase)) {
        throw ArgumentError('Path escapes category jail: $relativeFilePath');
      }
    }

    return targetFile.path;
  }
}
