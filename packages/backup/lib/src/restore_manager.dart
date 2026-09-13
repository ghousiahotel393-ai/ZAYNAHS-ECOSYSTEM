/// Safe Disaster Recovery and Restore Coordinator for Zaynahs Ecosystem.
/// Enforces Rule 89-91, Rule 102 (Golden Backup Test):
/// Integrity check before modification, mandatory pre-restore snapshot,
/// atomic table replacement, projection rebuilding, and audit logging.
library restore_manager;

import 'dart:convert';
import 'package:core/core.dart';
import 'package:database/database.dart';
import 'package:storage/storage.dart';
import 'backup_writer.dart';
import 'projection_rebuilder.dart';
import 'zynb_archive.dart';

class RestoreResult {
  final BackupRecord preRestoreBackup;
  final RebuildSummary rebuildSummary;
  final int tablesRestored;
  final int totalRecordsRestored;
  final DateTime restoredAt;

  const RestoreResult({
    required this.preRestoreBackup,
    required this.rebuildSummary,
    required this.tablesRestored,
    required this.totalRecordsRestored,
    required this.restoredAt,
  });
}

class RestoreManager {
  final AppDatabase db;
  final FileStorageService storageService;
  final BackupWriter backupWriter;
  final ProjectionRebuilder projectionRebuilder;

  RestoreManager({
    required this.db,
    required this.storageService,
    required this.backupWriter,
    required this.projectionRebuilder,
  });

  static const List<String> tableDeletionOrder = [
    'audit_logs',
    'sync_conflicts',
    'sync_cursors',
    'sync_outbox',
    'storage_files',
    'cctv_events',
    'cctv_segments',
    'cctv_cameras',
    'register_shifts',
    'stock_count_items',
    'stock_counts',
    'purchase_order_items',
    'purchase_orders',
    'suppliers',
    'return_payments',
    'return_items',
    'returns',
    'sale_payments',
    'sale_items',
    'sales',
    'customers',
    'wallet_transactions',
    'wallets',
    'inventory_movements',
    'inventory_items',
    'users',
    'devices',
    'ecosystems',
  ];

  /// Executes safe restore from a .zynb backup archive.
  /// If the archive is corrupt (even 1 byte), aborts immediately without touching the active DB.
  Future<RestoreResult> restoreFromArchive({
    required List<int> archiveBytes,
    required String actorId,
    required String deviceId,
  }) async {
    final now = DateTime.now().toUtc();

    // 1. STEP 1: Verify Archive Integrity BEFORE touching the active database (Rule 89, 102)
    // If the archive has even a 1-byte corruption, unpack() throws ValidationException.
    final unpacked = ZynbArchive.unpack(archiveBytes);

    // 2. STEP 2: Mandatory Pre-Restore Snapshot (Rule 60, 81)
    // Before restoring ANY backup, take an automated pre-restore backup.
    final preRestoreBackup = await backupWriter.createBackup(
      type: BackupType.preRestore,
      actorId: actorId,
      deviceId: deviceId,
      customMetadata: {'reason': 'Automated safety snapshot prior to restore'},
    );

    // 3. STEP 3: Atomic Table Replacement (Rule 90: Never silently merge)
    int totalRestoredRecords = 0;
    int tablesCount = 0;

    db.transaction(() {
      db.connection.execute('PRAGMA defer_foreign_keys = ON;');

      // A. Delete existing records in child-first (reverse topological) order
      for (final tableName in tableDeletionOrder) {
        if (unpacked.databaseTables.containsKey(tableName)) {
          db.connection.execute('DELETE FROM $tableName;');
        }
      }

      // Also delete any other tables in unpacked that might not be in tableDeletionOrder
      for (final tableName in unpacked.databaseTables.keys) {
        if (!tableDeletionOrder.contains(tableName)) {
          db.connection.execute('DELETE FROM $tableName;');
        }
      }

      // B. Insert restored records in parent-first order
      for (final tableName in BackupWriter.coreBackupTables) {
        final rows = unpacked.databaseTables[tableName];
        if (rows != null && rows.isNotEmpty) {
          final columns = rows.first.keys.toList();
          final colListStr = columns.join(', ');
          final placeholders = List.filled(columns.length, '?').join(', ');
          final insertSql = 'INSERT INTO $tableName ($colListStr) VALUES ($placeholders);';

          for (final row in rows) {
            final values = columns.map((col) => row[col]).toList();
            db.connection.execute(insertSql, values);
            totalRestoredRecords++;
          }
        }
        tablesCount++;
      }

      // Handle any additional tables not in coreBackupTables
      for (final entry in unpacked.databaseTables.entries) {
        if (!BackupWriter.coreBackupTables.contains(entry.key)) {
          final tableName = entry.key;
          final rows = entry.value;
          if (rows.isNotEmpty) {
            final columns = rows.first.keys.toList();
            final colListStr = columns.join(', ');
            final placeholders = List.filled(columns.length, '?').join(', ');
            final insertSql = 'INSERT INTO $tableName ($colListStr) VALUES ($placeholders);';

            for (final row in rows) {
              final values = columns.map((col) => row[col]).toList();
              db.connection.execute(insertSql, values);
              totalRestoredRecords++;
            }
          }
          tablesCount++;
        }
      }

      // 4. STEP 4: Projection Rebuild (Rule 91)
      final rebuildSummary = projectionRebuilder.rebuildProjections();

      // 5. STEP 5: Log Structured Audit Event
      final auditId = 'aud_${EntityId.generateUuidV4()}';
      db.connection.execute(
        '''
        INSERT INTO audit_logs (
          id, timestamp, level, action, actor_id, device_id,
          entity_type, entity_id, details_json, previous_hash, entry_hash
        ) VALUES (?, ?, 'AUDIT', 'DATABASE_RESTORE_COMPLETED', ?, ?, 'backup', ?, ?, '', ?)
        ''',
        [
          auditId,
          now.toIso8601String(),
          actorId,
          deviceId,
          unpacked.manifest.ecosystemId,
          jsonEncode({
            'sourceBackupType': unpacked.manifest.backupType.name,
            'sourceCreatedAt': unpacked.manifest.createdAt.toIso8601String(),
            'preRestoreBackupId': preRestoreBackup.id,
            'tablesRestored': tablesCount,
            'recordsRestored': totalRestoredRecords,
          }),
          'hash_$auditId',
        ],
      );

      return RestoreResult(
        preRestoreBackup: preRestoreBackup,
        rebuildSummary: rebuildSummary,
        tablesRestored: tablesCount,
        totalRecordsRestored: totalRestoredRecords,
        restoredAt: now,
      );
    });

    final rebuild = projectionRebuilder.rebuildProjections();

    return RestoreResult(
      preRestoreBackup: preRestoreBackup,
      rebuildSummary: rebuild,
      tablesRestored: tablesCount,
      totalRecordsRestored: totalRestoredRecords,
      restoredAt: now,
    );
  }
}
