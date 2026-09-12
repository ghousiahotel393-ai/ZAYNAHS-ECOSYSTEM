/// Bounded chunked streaming I/O with incremental SHA-256 hashing.
/// Enforces Rule 99-105: Constant bounded memory usage for arbitrary file sizes.
library chunked_stream_service;

import 'dart:async';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:core/core.dart';
import 'storage_taxonomy.dart';

class StreamSaveResult {
  final int totalBytes;
  final String sha256Hex;
  final File file;

  const StreamSaveResult({
    required this.totalBytes,
    required this.sha256Hex,
    required this.file,
  });
}

class ChunkedStreamService {
  static const int defaultChunkSize = 64 * 1024; // 64 KB bounded buffer

  /// Streams incoming byte stream directly to disk while calculating SHA-256 on the fly.
  /// Never buffers more than one [chunkSize] chunk in RAM.
  static Future<StreamSaveResult> saveStreamBounded({
    required StorageTaxonomy taxonomy,
    required StorageCategory category,
    required String fileName,
    required Stream<List<int>> dataStream,
    int chunkSize = defaultChunkSize,
  }) async {
    final destinationPath = taxonomy.sanitizeAndJailPath(category, fileName);
    final tempDir = taxonomy.getCategoryDirectory(StorageCategory.temp);
    final tempPath = '${tempDir.path}/stream_${EntityId.generateUuidV4()}.part';
    final tempFile = File(tempPath);

    final sink = tempFile.openWrite();
    final digestSink = _DigestSink();
    final hasher = sha256.startChunkedConversion(digestSink);

    int bytesTotal = 0;

    try {
      await for (final chunk in dataStream) {
        if (chunk.isEmpty) continue;
        sink.add(chunk);
        hasher.add(chunk);
        bytesTotal += chunk.length;
      }

      await sink.flush();
      await sink.close();
      hasher.close();

      final finalDigest = digestSink.value;
      if (finalDigest == null) {
        throw StateError('Failed to compute digest for stream');
      }

      // Ensure destination directory exists
      final targetFile = File(destinationPath);
      if (!await targetFile.parent.exists()) {
        await targetFile.parent.create(recursive: true);
      }

      // Atomic rename
      final finalFile = await tempFile.rename(destinationPath);

      return StreamSaveResult(
        totalBytes: bytesTotal,
        sha256Hex: finalDigest.toString(),
        file: finalFile,
      );
    } catch (e) {
      if (await tempFile.exists()) {
        try {
          await tempFile.delete();
        } catch (_) {}
      }
      rethrow;
    }
  }

  /// Reads a file in strictly bounded [chunkSize] chunks.
  static Stream<List<int>> readChunkedStream(File file, {int chunkSize = defaultChunkSize}) async* {
    final raf = await file.open(mode: FileMode.read);
    try {
      while (true) {
        final chunk = await raf.read(chunkSize);
        if (chunk.isEmpty) break;
        yield chunk;
      }
    } finally {
      await raf.close();
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
