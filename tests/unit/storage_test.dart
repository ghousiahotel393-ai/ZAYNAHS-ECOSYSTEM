import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:database/database.dart';
import 'package:storage/storage.dart';

Future<void> main() async {
  int passed = 0;
  int failed = 0;

  Future<void> testAsync(String name, Future<void> Function() body) async {
    try {
      await body();
      passed++;
      // ignore: avoid_print
      print('  ✓ $name');
    } catch (e, st) {
      failed++;
      // ignore: avoid_print
      print('  ✗ $name: $e\n$st');
    }
  }

  void expect(dynamic actual, dynamic expected) {
    if (actual != expected) {
      throw AssertionError('Expected: $expected, Actual: $actual');
    }
  }

  void assertTrue(bool condition, [String? message]) {
    if (!condition) {
      throw AssertionError(message ?? 'Expected condition to be true');
    }
  }

  // ignore: avoid_print
  print('\n=== Running Storage & File Foundation Tests ===');

  final tempTestDir = Directory.systemTemp.createTempSync('zaynahs_storage_test_');

  try {
    final storageService = FileStorageService(tempTestDir.path);
    final taxonomy = storageService.taxonomy;

    await testAsync('StorageTaxonomy initializes directories and blocks path traversal', () async {
      final mediaDir = taxonomy.getCategoryDirectory(StorageCategory.mediaProducts);
      assertTrue(mediaDir.existsSync());

      // Valid relative path stays jailed
      final validPath = taxonomy.sanitizeAndJailPath(
        StorageCategory.mediaProducts,
        'shoes/sneaker_red.jpg',
      );
      assertTrue(validPath.startsWith(mediaDir.path));

      // Path traversal attack #1: ../ escapes jail
      bool blocked1 = false;
      try {
        taxonomy.sanitizeAndJailPath(StorageCategory.mediaProducts, '../../etc/passwd');
      } catch (_) {
        blocked1 = true;
      }
      assertTrue(blocked1, 'Expected traversal attack to be blocked');

      // Path traversal attack #2: absolute path escapes jail
      bool blocked2 = false;
      try {
        taxonomy.sanitizeAndJailPath(StorageCategory.mediaProducts, '/var/log/secret');
      } catch (_) {
        blocked2 = true;
      }
      assertTrue(blocked2, 'Expected absolute path attack to be blocked');
    });

    await testAsync('FileStorageService atomic file write, read, and delete', () async {
      const fileName = 'test_document.pdf';
      final content = utf8.encode('CONFIDENTIAL FINANCIAL REPORT - ZAYNAHS');

      final savedFile = await storageService.saveFileAtomic(
        category: StorageCategory.mediaDocuments,
        fileName: fileName,
        bytes: content,
      );

      assertTrue(await savedFile.exists());
      expect(storageService.getFileSize(StorageCategory.mediaDocuments, fileName), content.length);

      final readBack = await storageService.readBytes(StorageCategory.mediaDocuments, fileName);
      expect(utf8.decode(readBack), 'CONFIDENTIAL FINANCIAL REPORT - ZAYNAHS');

      // Delete file
      final deleted = await storageService.delete(StorageCategory.mediaDocuments, fileName);
      assertTrue(deleted);
      assertTrue(!storageService.exists(StorageCategory.mediaDocuments, fileName));
    });

    await testAsync('ChunkedStreamService bounded 64KB streaming I/O and SHA-256 calculation', () async {
      const totalSize = 256 * 1024; // 256 KB test file
      final payload = Uint8List(totalSize);
      for (int i = 0; i < totalSize; i++) {
        payload[i] = i % 256;
      }

      final expectedDigest = sha256.convert(payload).toString();

      // Create stream chunked in 32KB pieces
      Stream<List<int>> createChunkedStream() async* {
        for (int i = 0; i < totalSize; i += 32768) {
          yield payload.sublist(i, i + 32768);
        }
      }

      final result = await ChunkedStreamService.saveStreamBounded(
        taxonomy: taxonomy,
        category: StorageCategory.cctvRecordings,
        fileName: 'cam01_segment_001.mp4',
        dataStream: createChunkedStream(),
      );

      expect(result.totalBytes, totalSize);
      expect(result.sha256Hex, expectedDigest);
      assertTrue(await result.file.exists());

      // Read back via chunked stream
      final readChunks = <int>[];
      await for (final chunk in ChunkedStreamService.readChunkedStream(result.file, chunkSize: 65536)) {
        readChunks.addAll(chunk);
      }
      expect(readChunks.length, totalSize);
      expect(sha256.convert(readChunks).toString(), expectedDigest);
    });

    await testAsync('DeduplicationService eliminates redundant disk writes using storage_files table', () async {
      final db = AppDatabase.openInMemory();
      db.initialize();

      final dedupService = DeduplicationService(
        taxonomy: taxonomy,
        db: db,
      );

      final imageBytes = utf8.encode('SAME_PRODUCT_IMAGE_BYTES_1234567890');
      Stream<List<int>> makeStream() async* {
        yield imageBytes;
      }

      // 1. Save original file
      final res1 = await dedupService.saveDeduplicated(
        category: StorageCategory.mediaProducts,
        fileName: 'product_1_front.jpg',
        dataStream: makeStream(),
      );

      assertTrue(!res1.isDeduplicated);
      expect(res1.referenceCount, 1);
      assertTrue(File(res1.filePath).existsSync());

      // 2. Save duplicate content under a different filename
      final res2 = await dedupService.saveDeduplicated(
        category: StorageCategory.mediaProducts,
        fileName: 'product_2_same_image.jpg',
        dataStream: makeStream(),
      );

      assertTrue(res2.isDeduplicated);
      expect(res2.referenceCount, 2);
      // Reuses identical disk path
      expect(res2.filePath, res1.filePath);

      // 3. Release 1st reference: physical file must remain on disk
      final deleted1 = await dedupService.releaseReference(res1.fileId);
      assertTrue(!deleted1);
      assertTrue(File(res1.filePath).existsSync());

      // 4. Release 2nd reference: physical file must now be deleted
      final deleted2 = await dedupService.releaseReference(res1.fileId);
      assertTrue(deleted2);
      assertTrue(!File(res1.filePath).existsSync());

      db.close();
    });

    await testAsync('FileStorageService purgeTemp cleans scratch files', () async {
      final tempDir = taxonomy.getCategoryDirectory(StorageCategory.temp);
      final dummyTemp1 = File('${tempDir.path}/scratch1.tmp');
      final dummyTemp2 = File('${tempDir.path}/scratch2.tmp');
      await dummyTemp1.writeAsString('scratch');
      await dummyTemp2.writeAsString('scratch');

      final purged = await storageService.purgeTemp();
      assertTrue(purged >= 2);
      assertTrue(!dummyTemp1.existsSync());
      assertTrue(!dummyTemp2.existsSync());
    });

    await testAsync('FileStorageService monitors space and executes purgeCache', () async {
      final cacheDir = taxonomy.getCategoryDirectory(StorageCategory.cache);
      final cacheFile = File('${cacheDir.path}/cached_image.dat');
      await cacheFile.writeAsString('cached data');
      assertTrue(cacheFile.existsSync());

      final available = await storageService.getAvailableSpace();
      assertTrue(available > 0);

      final health = await storageService.checkStorageHealth(autoPurgeCacheIfLow: false);
      assertTrue(health.totalBytes > 0);
      assertTrue(health.availableBytes > 0);
      assertTrue(health.freePercentage >= 0.0 && health.freePercentage <= 100.0);

      final purged = await storageService.purgeCache();
      assertTrue(purged >= 1);
      assertTrue(!cacheFile.existsSync());
    });
  } finally {
    if (tempTestDir.existsSync()) {
      tempTestDir.deleteSync(recursive: true);
    }
  }

  // ignore: avoid_print
  print('\nStorage tests summary: $passed passed, $failed failed.');
  if (failed > 0) {
    exit(1);
  }
}
