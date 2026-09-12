/// Unified FileStorageService filesystem abstraction.
/// Enforces Rule 97-98, Rule 106-119: Atomic file writes, temp scratch, and safe path resolution.
library file_storage_service;

import 'dart:io';
import 'package:core/core.dart';
import 'storage_taxonomy.dart';

class FileStorageService {
  final StorageTaxonomy taxonomy;

  FileStorageService(String baseDirectoryPath)
      : taxonomy = StorageTaxonomy(baseDirectoryPath) {
    taxonomy.initializeDirectories();
  }

  /// Writes file atomically using write_temp -> verify -> atomic_rename workflow.
  Future<File> saveFileAtomic({
    required StorageCategory category,
    required String fileName,
    required List<int> bytes,
  }) async {
    final destinationPath = taxonomy.sanitizeAndJailPath(category, fileName);
    final tempDir = taxonomy.getCategoryDirectory(StorageCategory.temp);
    final tempFileName = 'tmp_${EntityId.generateUuidV4()}.part';
    final tempFile = File('${tempDir.path}/$tempFileName');

    // 1. Write to temp file and flush to disk
    await tempFile.writeAsBytes(bytes, flush: true);

    // 2. Verify length integrity
    final writtenLength = await tempFile.length();
    if (writtenLength != bytes.length) {
      if (await tempFile.exists()) await tempFile.delete();
      throw StateError(
        'Integrity check failed: Expected ${bytes.length} bytes, wrote $writtenLength bytes.',
      );
    }

    // 3. Ensure target parent directory exists
    final targetFile = File(destinationPath);
    if (!await targetFile.parent.exists()) {
      await targetFile.parent.create(recursive: true);
    }

    // 4. Atomic rename into permanent location
    return await tempFile.rename(destinationPath);
  }

  /// Opens a readable byte stream for a jailed file.
  Stream<List<int>> openRead(StorageCategory category, String fileName) {
    final path = taxonomy.sanitizeAndJailPath(category, fileName);
    final file = File(path);
    if (!file.existsSync()) {
      throw PathNotFoundException(path, const OSError('File does not exist', 2));
    }
    return file.openRead();
  }

  /// Reads entire file bytes.
  Future<List<int>> readBytes(StorageCategory category, String fileName) async {
    final path = taxonomy.sanitizeAndJailPath(category, fileName);
    final file = File(path);
    if (!await file.exists()) {
      throw PathNotFoundException(path, const OSError('File does not exist', 2));
    }
    return await file.readAsBytes();
  }

  /// Deletes a file. Returns true if file existed and was deleted.
  Future<bool> delete(StorageCategory category, String fileName) async {
    final path = taxonomy.sanitizeAndJailPath(category, fileName);
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
      return true;
    }
    return false;
  }

  /// Checks if file exists.
  bool exists(StorageCategory category, String fileName) {
    final path = taxonomy.sanitizeAndJailPath(category, fileName);
    return File(path).existsSync();
  }

  /// Gets file size in bytes.
  int getFileSize(StorageCategory category, String fileName) {
    final path = taxonomy.sanitizeAndJailPath(category, fileName);
    final file = File(path);
    if (!file.existsSync()) return 0;
    return file.lengthSync();
  }

  /// Startup purge of all temporary scratch files.
  Future<int> purgeTemp() async {
    final tempDir = taxonomy.getCategoryDirectory(StorageCategory.temp);
    if (!await tempDir.exists()) return 0;

    int purgedCount = 0;
    final entities = tempDir.listSync(recursive: true);
    for (final entity in entities) {
      if (entity is File) {
        try {
          await entity.delete();
          purgedCount++;
        } catch (_) {}
      }
    }
    return purgedCount;
  }

  /// Clears cache files.
  Future<int> purgeCache() async {
    final cacheDir = taxonomy.getCategoryDirectory(StorageCategory.cache);
    if (!await cacheDir.exists()) return 0;

    int purgedCount = 0;
    final entities = cacheDir.listSync(recursive: true);
    for (final entity in entities) {
      if (entity is File) {
        try {
          await entity.delete();
          purgedCount++;
        } catch (_) {}
      }
    }
    return purgedCount;
  }

  /// Returns available free space in bytes.
  Future<int> getAvailableSpace() async {
    final health = await checkStorageHealth(autoPurgeCacheIfLow: false);
    return health.availableBytes;
  }

  /// Monitors disk space and triggers automatic cache cleanup when free space < 10%.
  Future<StorageSpaceInfo> checkStorageHealth({bool autoPurgeCacheIfLow = true}) async {
    int total = 1000 * 1024 * 1024 * 1024; // Default fallback: 1TB
    int available = 500 * 1024 * 1024 * 1024; // Default fallback: 500GB

    try {
      if (Platform.isMacOS || Platform.isLinux) {
        final result = await Process.run('df', ['-k', taxonomy.baseDirectory.path]);
        if (result.exitCode == 0) {
          final lines = (result.stdout as String).trim().split('\n');
          if (lines.length >= 2) {
            final parts = lines[1].split(RegExp(r'\s+'));
            if (parts.length >= 4) {
              final totalBlocks = int.tryParse(parts[1]) ?? 0;
              final availBlocks = int.tryParse(parts[3]) ?? 0;
              if (totalBlocks > 0) {
                total = totalBlocks * 1024;
                available = availBlocks * 1024;
              }
            }
          }
        }
      }
    } catch (_) {
      // Fallback in environments where Process.run is restricted
    }

    final freePercentage = total > 0 ? (available / total) * 100.0 : 100.0;
    final isLowSpace = freePercentage < 10.0;

    if (isLowSpace && autoPurgeCacheIfLow) {
      await purgeCache();
    }

    return StorageSpaceInfo(
      availableBytes: available,
      totalBytes: total,
      freePercentage: freePercentage,
      isLowSpace: isLowSpace,
    );
  }
}

class StorageSpaceInfo {
  final int availableBytes;
  final int totalBytes;
  final double freePercentage;
  final bool isLowSpace; // true if freePercentage < 10.0

  const StorageSpaceInfo({
    required this.availableBytes,
    required this.totalBytes,
    required this.freePercentage,
    required this.isLowSpace,
  });
}
