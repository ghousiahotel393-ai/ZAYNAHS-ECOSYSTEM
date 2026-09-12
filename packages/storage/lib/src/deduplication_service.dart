/// Content Addressable Deduplication Engine.
/// Prevents redundant writes of identical media attachments and images across ecosystem.
library deduplication_service;

import 'dart:async';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:core/core.dart';
import 'package:database/database.dart';
import 'storage_taxonomy.dart';

class DeduplicationResult {
  final String fileId;
  final String filePath;
  final String sha256Hash;
  final int fileSizeBytes;
  final bool isDeduplicated; // true if existing content was reused
  final int referenceCount;

  const DeduplicationResult({
    required this.fileId,
    required this.filePath,
    required this.sha256Hash,
    required this.fileSizeBytes,
    required this.isDeduplicated,
    required this.referenceCount,
  });
}

class DeduplicationService {
  final StorageTaxonomy taxonomy;
  final AppDatabase db;

  DeduplicationService({
    required this.taxonomy,
    required this.db,
  });

  /// Saves incoming stream, checking if identical SHA-256 hash already exists.
  /// If hash matches, links reference without writing duplicate bytes to disk.
  Future<DeduplicationResult> saveDeduplicated({
    required StorageCategory category,
    required String fileName,
    required Stream<List<int>> dataStream,
    String mimeType = 'application/octet-stream',
  }) async {
    // 1. Stream to temp file while calculating SHA-256
    final tempDir = taxonomy.getCategoryDirectory(StorageCategory.temp);
    final tempPath = '${tempDir.path}/dedup_${EntityId.generateUuidV4()}.part';
    final tempFile = File(tempPath);
    final sink = tempFile.openWrite();
    final digestSink = _DigestSink();
    final hasher = sha256.startChunkedConversion(digestSink);

    int totalBytes = 0;
    try {
      await for (final chunk in dataStream) {
        if (chunk.isEmpty) continue;
        sink.add(chunk);
        hasher.add(chunk);
        totalBytes += chunk.length;
      }
      await sink.flush();
      await sink.close();
      hasher.close();

      final digest = digestSink.value;
      if (digest == null) {
        throw StateError('Failed to compute digest for stream');
      }
      final shaHex = digest.toString();

      // 2. Check if identical hash already exists in storage_files
      final existing = db.connection.select(
        'SELECT * FROM storage_files WHERE sha256_hash = ? AND category = ?',
        [shaHex, category.name],
      );

      if (existing.isNotEmpty) {
        // MATCH FOUND: reuse existing file!
        final row = existing.first;
        final fileId = row['id'] as String;
        final filePath = row['file_path'] as String;
        final currentRefs = row['reference_count'] as int;
        final newRefs = currentRefs + 1;

        // Increment reference count
        db.connection.execute(
          'UPDATE storage_files SET reference_count = ? WHERE id = ?',
          [newRefs, fileId],
        );

        // Delete temporary duplicate file
        if (await tempFile.exists()) {
          await tempFile.delete();
        }

        return DeduplicationResult(
          fileId: fileId,
          filePath: filePath,
          sha256Hash: shaHex,
          fileSizeBytes: totalBytes,
          isDeduplicated: true,
          referenceCount: newRefs,
        );
      } else {
        // NO MATCH: Atomically move temp file to permanent location
        final destinationPath = taxonomy.sanitizeAndJailPath(category, fileName);
        final targetFile = File(destinationPath);
        if (!await targetFile.parent.exists()) {
          await targetFile.parent.create(recursive: true);
        }

        await tempFile.rename(destinationPath);

        final fileId = 'fil_${EntityId.generateUuidV4()}';
        final now = DateTime.now().toUtc().toIso8601String();

        db.connection.execute(
          '''
          INSERT INTO storage_files (
            id, category, file_name, file_path, sha256_hash,
            file_size_bytes, mime_type, reference_count, created_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, 1, ?)
          ''',
          [fileId, category.name, fileName, destinationPath, shaHex, totalBytes, mimeType, now],
        );

        return DeduplicationResult(
          fileId: fileId,
          filePath: destinationPath,
          sha256Hash: shaHex,
          fileSizeBytes: totalBytes,
          isDeduplicated: false,
          referenceCount: 1,
        );
      }
    } catch (e) {
      if (await tempFile.exists()) {
        try {
          await tempFile.delete();
        } catch (_) {}
      }
      rethrow;
    }
  }

  /// Decrements reference count and physically deletes file when count reaches 0.
  Future<bool> releaseReference(String fileId) async {
    final rs = db.connection.select(
      'SELECT * FROM storage_files WHERE id = ?',
      [fileId],
    );
    if (rs.isEmpty) return false;

    final row = rs.first;
    final currentRefs = row['reference_count'] as int;
    final filePath = row['file_path'] as String;

    if (currentRefs <= 1) {
      // Last reference: delete physical file and row
      db.connection.execute('DELETE FROM storage_files WHERE id = ?', [fileId]);
      final physicalFile = File(filePath);
      if (await physicalFile.exists()) {
        await physicalFile.delete();
      }
      return true;
    } else {
      // Decrement reference
      db.connection.execute(
        'UPDATE storage_files SET reference_count = ? WHERE id = ?',
        [currentRefs - 1, fileId],
      );
      return false;
    }
  }
}

class _DigestSink implements Sink<Digest> {
  Digest? value;
  @override
  void add(Digest data) => value = data;
  @override
  void close() {}
}
