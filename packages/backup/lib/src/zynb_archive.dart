/// Canonical .ZYNB Archive Specification for Zaynahs Ecosystem.
/// Enforces Rule 87-88, Rule 102 (Golden Backup Test):
/// Verifiable, compressed, integrity-protected binary backup package.
library zynb_archive;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:core/core.dart';
import 'package:crypto/crypto.dart';

enum BackupType {
  daily,
  manual,
  preRestore;

  String get dbValue {
    switch (this) {
      case BackupType.daily:
        return 'DAILY';
      case BackupType.manual:
        return 'MANUAL';
      case BackupType.preRestore:
        return 'PRE_RESTORE';
    }
  }

  static BackupType fromString(String val) {
    final upper = val.toUpperCase();
    if (upper == 'DAILY') return BackupType.daily;
    if (upper == 'PRE_RESTORE' || upper == 'PRERESTORE') return BackupType.preRestore;
    return BackupType.manual;
  }
}

class ZynbManifest {
  final int formatVersion;
  final String ecosystemId;
  final BackupType backupType;
  final DateTime createdAt;
  final Map<String, int> tableRecordCounts;
  final Map<String, dynamic> metadata;

  const ZynbManifest({
    this.formatVersion = 1,
    required this.ecosystemId,
    required this.backupType,
    required this.createdAt,
    required this.tableRecordCounts,
    this.metadata = const {},
  });

  Map<String, dynamic> toJson() => {
        'formatVersion': formatVersion,
        'ecosystemId': ecosystemId,
        'backupType': backupType.dbValue,
        'createdAt': createdAt.toIso8601String(),
        'tableRecordCounts': tableRecordCounts,
        'metadata': metadata,
      };

  factory ZynbManifest.fromJson(Map<String, dynamic> json) {
    final type = BackupType.fromString(json['backupType'] as String? ?? 'MANUAL');

    return ZynbManifest(
      formatVersion: json['formatVersion'] as int? ?? 1,
      ecosystemId: json['ecosystemId'] as String? ?? 'eco_default',
      backupType: type,
      createdAt: DateTime.parse(json['createdAt'] as String),
      tableRecordCounts: Map<String, int>.from(json['tableRecordCounts'] as Map? ?? {}),
      metadata: Map<String, dynamic>.from(json['metadata'] as Map? ?? {}),
    );
  }
}

class UnpackedZynbArchive {
  final ZynbManifest manifest;
  final Map<String, String> entryChecksums;
  final Map<String, List<Map<String, dynamic>>> databaseTables;
  final String archiveSha256;

  const UnpackedZynbArchive({
    required this.manifest,
    required this.entryChecksums,
    required this.databaseTables,
    required this.archiveSha256,
  });
}

class ZynbArchive {
  static const List<int> magicBytes = [0x5A, 0x59, 0x4E, 0x42]; // "ZYNB"
  static const int currentVersion = 1;

  /// Packs a database snapshot, manifest, and checksums into a sealed .zynb binary archive.
  static Uint8List pack({
    required ZynbManifest manifest,
    required Map<String, List<Map<String, dynamic>>> databaseTables,
  }) {
    final manifestBytes = utf8.encode(jsonEncode(manifest.toJson()));

    // 1. Serialize and compress database tables
    final dbJsonBytes = utf8.encode(jsonEncode(databaseTables));
    final compressedDbBytes = gzip.encode(dbJsonBytes);

    // 2. Generate per-entry checksums
    final entryChecksums = <String, String>{
      'manifest.json': sha256.convert(manifestBytes).toString(),
      'database/tables.json.gz': sha256.convert(compressedDbBytes).toString(),
    };
    final checksumsBytes = utf8.encode(jsonEncode(entryChecksums));

    // 3. Assemble package body:
    // [Magic: 4B][Version: 2B][Type: 1B]
    // [ManifestLen: 4B][ManifestBytes]
    // [ChecksumsLen: 4B][ChecksumsBytes]
    // [DbLen: 4B][DbBytes]
    final bodyBuffer = BytesBuilder();
    bodyBuffer.add(magicBytes);

    // Version (uint16 big-endian)
    final versionData = ByteData(2)..setUint16(0, currentVersion, Endian.big);
    bodyBuffer.add(versionData.buffer.asUint8List());

    // Backup type (uint8)
    bodyBuffer.add([manifest.backupType.index]);

    // Manifest
    final mLenData = ByteData(4)..setUint32(0, manifestBytes.length, Endian.big);
    bodyBuffer.add(mLenData.buffer.asUint8List());
    bodyBuffer.add(manifestBytes);

    // Checksums
    final cLenData = ByteData(4)..setUint32(0, checksumsBytes.length, Endian.big);
    bodyBuffer.add(cLenData.buffer.asUint8List());
    bodyBuffer.add(checksumsBytes);

    // Database payload
    final dbLenData = ByteData(4)..setUint32(0, compressedDbBytes.length, Endian.big);
    bodyBuffer.add(dbLenData.buffer.asUint8List());
    bodyBuffer.add(compressedDbBytes);

    final rawBody = bodyBuffer.toBytes();

    // 4. Compute 32-byte SHA-256 seal over the entire package body
    final sealDigest = sha256.convert(rawBody).bytes;

    final finalArchive = BytesBuilder();
    finalArchive.add(rawBody);
    finalArchive.add(sealDigest); // 32 bytes trailing seal

    return finalArchive.toBytes();
  }

  /// Verifies and unpacks a .zynb binary archive.
  /// Throws [ValidationException] immediately if any byte is corrupted or modified.
  static UnpackedZynbArchive unpack(List<int> archiveBytes) {
    if (archiveBytes.length < 4 + 2 + 1 + 4 + 4 + 4 + 32) {
      throw ValidationException.invalidValue('archiveBytes', 'Archive file size is too small to be a valid .zynb package.');
    }

    final totalLen = archiveBytes.length;
    final bodyBytes = archiveBytes.sublist(0, totalLen - 32);
    final providedSeal = archiveBytes.sublist(totalLen - 32);

    // 1. Verify Cryptographic Integrity Seal
    final expectedDigest = sha256.convert(bodyBytes).bytes;
    for (int i = 0; i < 32; i++) {
      if (providedSeal[i] != expectedDigest[i]) {
        throw ValidationException.invalidValue(
          'archiveBytes',
          'Cryptographic integrity failure: .zynb archive signature mismatch (corrupted or tampered).',
        );
      }
    }

    final archiveSha256 = sha256.convert(archiveBytes).toString();

    // 2. Verify Magic Header
    if (bodyBytes[0] != magicBytes[0] ||
        bodyBytes[1] != magicBytes[1] ||
        bodyBytes[2] != magicBytes[2] ||
        bodyBytes[3] != magicBytes[3]) {
      throw ValidationException.invalidValue('archiveBytes', 'Invalid .zynb magic header.');
    }

    // 3. Read components
    var offset = 4;
    final view = ByteData.sublistView(Uint8List.fromList(bodyBytes));

    final version = view.getUint16(offset, Endian.big);
    offset += 2;
    if (version > currentVersion) {
      throw ValidationException.invalidValue('archiveBytes', 'Unsupported .zynb archive version ($version).');
    }

    // Backup Type
    offset += 1;

    // Manifest
    final manifestLen = view.getUint32(offset, Endian.big);
    offset += 4;
    final manifestJsonStr = utf8.decode(bodyBytes.sublist(offset, offset + manifestLen));
    final manifest = ZynbManifest.fromJson(jsonDecode(manifestJsonStr) as Map<String, dynamic>);
    offset += manifestLen;

    // Checksums
    final checksumsLen = view.getUint32(offset, Endian.big);
    offset += 4;
    final checksumsJsonStr = utf8.decode(bodyBytes.sublist(offset, offset + checksumsLen));
    final entryChecksums = Map<String, String>.from(jsonDecode(checksumsJsonStr) as Map);
    offset += checksumsLen;

    // Database Payload
    final dbLen = view.getUint32(offset, Endian.big);
    offset += 4;
    final compressedDbBytes = bodyBytes.sublist(offset, offset + dbLen);

    // Verify entry checksum of DB payload
    final calculatedDbChecksum = sha256.convert(compressedDbBytes).toString();
    if (entryChecksums['database/tables.json.gz'] != calculatedDbChecksum) {
      throw ValidationException.invalidValue(
        'archiveBytes',
        'Database payload checksum verification failed inside .zynb archive.',
      );
    }

    final decompressedDbBytes = gzip.decode(compressedDbBytes);
    final dbJsonStr = utf8.decode(decompressedDbBytes);
    final rawDbMap = jsonDecode(dbJsonStr) as Map<String, dynamic>;

    final Map<String, List<Map<String, dynamic>>> databaseTables = {};
    for (final entry in rawDbMap.entries) {
      final rows = (entry.value as List).map((r) => Map<String, dynamic>.from(r as Map)).toList();
      databaseTables[entry.key] = rows;
    }

    return UnpackedZynbArchive(
      manifest: manifest,
      entryChecksums: entryChecksums,
      databaseTables: databaseTables,
      archiveSha256: archiveSha256,
    );
  }
}
