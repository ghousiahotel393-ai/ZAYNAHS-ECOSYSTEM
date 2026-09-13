/// Atomic Backup Archive Writer for Zaynahs Ecosystem.
/// Enforces Rule 86-88, Rule 102:
/// WAL checkpoint, table snapshot, atomic save, and audit logging.
library backup_writer;

import 'dart:convert';
import 'package:core/core.dart';
import 'package:crypto/crypto.dart';
import 'package:database/database.dart';
import 'package:storage/storage.dart';
import 'zynb_archive.dart';

class BackupRecord {
  final String id;
  final BackupType backupType;
  final String filePath;
  final int fileSizeBytes;
  final String sha256Checksum;
  final ZynbManifest manifest;
  final String status;
  final String actorId;
  final String deviceId;
  final DateTime createdAt;

  const BackupRecord({
    required this.id,
    required this.backupType,
    required this.filePath,
    required this.fileSizeBytes,
    required this.sha256Checksum,
    required this.manifest,
    required this.status,
    required this.actorId,
    required this.deviceId,
    required this.createdAt,
  });
}

class BackupWriter {
  final AppDatabase db;
  final FileStorageService storageService;

  BackupWriter({
    required this.db,
    required this.storageService,
  });

  static const List<String> coreBackupTables = [
    'ecosystems',
    'devices',
    'users',
    'inventory_items',
    'inventory_movements',
    'wallets',
    'wallet_transactions',
    'customers',
    'sales',
    'sale_items',
    'sale_payments',
    'returns',
    'return_items',
    'return_payments',
    'suppliers',
    'purchase_orders',
    'purchase_order_items',
    'stock_counts',
    'stock_count_items',
    'register_shifts',
    'cctv_cameras',
    'cctv_segments',
    'cctv_events',
    'storage_files',
    'sync_outbox',
    'sync_cursors',
    'sync_conflicts',
    'audit_logs',
  ];

  /// Creates an atomic .zynb backup archive of the entire ecosystem database.
  Future<BackupRecord> createBackup({
    required BackupType type,
    required String actorId,
    required String deviceId,
    String? ecosystemId,
    Map<String, dynamic> customMetadata = const {},
  }) async {
    final now = DateTime.now().toUtc();

    // 1. Flush SQLite WAL to ensure consistency
    try {
      db.connection.execute('PRAGMA wal_checkpoint(TRUNCATE);');
    } catch (_) {
      // For in-memory databases wal_checkpoint may be a no-op
    }

    // 2. Extract table rows and count records
    final Map<String, List<Map<String, dynamic>>> databaseTables = {};
    final Map<String, int> tableRecordCounts = {};

    for (final table in coreBackupTables) {
      final rows = db.connection.select('SELECT * FROM $table');
      databaseTables[table] = rows;
      tableRecordCounts[table] = rows.length;
    }

    // Determine ecosystem ID
    String resolvedEcoId = ecosystemId ?? 'eco_default';
    final ecoRows = db.connection.select('SELECT id FROM ecosystems LIMIT 1');
    if (ecoRows.isNotEmpty) {
      resolvedEcoId = ecoRows.first['id'] as String;
    }

    // 3. Assemble Manifest
    final manifest = ZynbManifest(
      formatVersion: 1,
      ecosystemId: resolvedEcoId,
      backupType: type,
      createdAt: now,
      tableRecordCounts: tableRecordCounts,
      metadata: customMetadata,
    );

    // 4. Pack into .zynb Binary Archive
    final archiveBytes = ZynbArchive.pack(
      manifest: manifest,
      databaseTables: databaseTables,
    );

    final archiveChecksum = sha256.convert(archiveBytes).toString();

    // 5. Select category directory and filename
    final category = (type == BackupType.daily)
        ? StorageCategory.backupsDaily
        : StorageCategory.backupsManual;

    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    final hms = '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
    final fileName = '${type.name}_${y}${m}${d}_${hms}.zynb';

    // 6. Atomically save file
    await storageService.saveFileAtomic(
      category: category,
      fileName: fileName,
      bytes: archiveBytes,
    );

    final backupId = 'bak_${EntityId.generateUuidV4()}';
    final filePath = '${category.relativePath}/$fileName';

    // 7. Record into backup_records table
    db.connection.execute(
      '''
      INSERT INTO backup_records (
        id, backup_type, file_path, file_size_bytes, sha256_checksum,
        manifest_json, status, actor_id, device_id, created_at
      ) VALUES (?, ?, ?, ?, ?, ?, 'COMPLETED', ?, ?, ?)
      ''',
      [
        backupId,
        type.dbValue,
        filePath,
        archiveBytes.length,
        archiveChecksum,
        jsonEncode(manifest.toJson()),
        actorId,
        deviceId,
        now.toIso8601String(),
      ],
    );

    // 8. Log Structured Audit Event
    final auditId = 'aud_${EntityId.generateUuidV4()}';
    db.connection.execute(
      '''
      INSERT INTO audit_logs (
        id, timestamp, level, action, actor_id, device_id,
        entity_type, entity_id, details_json, previous_hash, entry_hash
      ) VALUES (?, ?, 'AUDIT', 'BACKUP_CREATED', ?, ?, 'backup', ?, ?, '', ?)
      ''',
      [
        auditId,
        now.toIso8601String(),
        actorId,
        deviceId,
        backupId,
        jsonEncode({
          'backupId': backupId,
          'type': type.name.toUpperCase(),
          'fileSizeBytes': archiveBytes.length,
          'checksum': archiveChecksum,
        }),
        'hash_$backupId',
      ],
    );

    return BackupRecord(
      id: backupId,
      backupType: type,
      filePath: filePath,
      fileSizeBytes: archiveBytes.length,
      sha256Checksum: archiveChecksum,
      manifest: manifest,
      status: 'COMPLETED',
      actorId: actorId,
      deviceId: deviceId,
      createdAt: now,
    );
  }
}
