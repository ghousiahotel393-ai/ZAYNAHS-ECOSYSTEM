/// Resumable Chunked File Transfer Protocol Engine.
/// Enforces Section 02, Rule 50-53, and Golden Test #104:
/// 6-step protocol: START -> META -> CHUNK -> ACK -> VERIFY -> COMPLETE.
/// Resumes cleanly from offset upon connection cut; verifies SHA-256 hash.
library file_transfer_protocol;

import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

enum TransferStep {
  start,
  meta,
  chunk,
  ack,
  verify,
  complete,
  interrupted,
  failed;
}

class TransferMeta {
  final String transferId;
  final String fileName;
  final int fileSizeBytes;
  final String sha256Hash;
  final int chunkSize;

  const TransferMeta({
    required this.transferId,
    required this.fileName,
    required this.fileSizeBytes,
    required this.sha256Hash,
    this.chunkSize = 64 * 1024, // 64 KB bounded chunk size
  });

  Map<String, dynamic> toMap() => {
        'transfer_id': transferId,
        'file_name': fileName,
        'file_size_bytes': fileSizeBytes,
        'sha256_hash': sha256Hash,
        'chunk_size': chunkSize,
      };

  factory TransferMeta.fromMap(Map<String, dynamic> map) => TransferMeta(
        transferId: map['transfer_id'] as String,
        fileName: map['file_name'] as String,
        fileSizeBytes: (map['file_size_bytes'] as num).toInt(),
        sha256Hash: map['sha256_hash'] as String,
        chunkSize: (map['chunk_size'] as num?)?.toInt() ?? 64 * 1024,
      );

  String toJson() => jsonEncode(toMap());
  factory TransferMeta.fromJson(String jsonStr) =>
      TransferMeta.fromMap(jsonDecode(jsonStr) as Map<String, dynamic>);
}

class FileChunk {
  final String transferId;
  final int chunkIndex;
  final int offset;
  final List<int> bytes;

  const FileChunk({
    required this.transferId,
    required this.chunkIndex,
    required this.offset,
    required this.bytes,
  });
}

class ChunkAck {
  final String transferId;
  final int chunkIndex;
  final int receivedOffset;

  const ChunkAck({
    required this.transferId,
    required this.chunkIndex,
    required this.receivedOffset,
  });

  Map<String, dynamic> toMap() => {
        'transfer_id': transferId,
        'chunk_index': chunkIndex,
        'received_offset': receivedOffset,
      };

  String toJson() => jsonEncode(toMap());
}

/// Sender-side protocol driver for chunked file transmission.
class FileTransferSender {
  final TransferMeta meta;
  final List<int> fileBytes;
  int currentOffset = 0;

  FileTransferSender({
    required this.meta,
    required this.fileBytes,
  });

  /// Yields file chunks starting from specified byte offset (supports resume).
  Iterable<FileChunk> getChunksFromOffset(int resumeOffset) sync* {
    currentOffset = resumeOffset;
    int chunkIndex = resumeOffset ~/ meta.chunkSize;

    while (currentOffset < fileBytes.length) {
      final end = (currentOffset + meta.chunkSize < fileBytes.length)
          ? currentOffset + meta.chunkSize
          : fileBytes.length;

      final slice = fileBytes.sublist(currentOffset, end);
      yield FileChunk(
        transferId: meta.transferId,
        chunkIndex: chunkIndex,
        offset: currentOffset,
        bytes: slice,
      );

      currentOffset = end;
      chunkIndex++;
    }
  }
}

/// Receiver-side protocol driver with in-memory buffer and SHA-256 verification.
class FileTransferReceiver {
  final TransferMeta meta;
  TransferStep step = TransferStep.start;
  final Map<int, List<int>> _receivedChunks = {};
  int _receivedBytes = 0;

  FileTransferReceiver(this.meta) {
    step = TransferStep.meta;
  }

  int get receivedBytes => _receivedBytes;
  double get progressPercentage =>
      meta.fileSizeBytes > 0 ? (_receivedBytes / meta.fileSizeBytes) * 100.0 : 0.0;

  /// Ingests an incoming chunk, updates offset, and returns ACK.
  ChunkAck receiveChunk(FileChunk chunk) {
    if (chunk.transferId != meta.transferId) {
      throw ArgumentError('Mismatched transferId on incoming chunk');
    }

    step = TransferStep.chunk;

    // Deduplicate if chunk already received
    if (!_receivedChunks.containsKey(chunk.chunkIndex)) {
      _receivedChunks[chunk.chunkIndex] = chunk.bytes;
      _receivedBytes += chunk.bytes.length;
    }

    step = TransferStep.ack;
    return ChunkAck(
      transferId: meta.transferId,
      chunkIndex: chunk.chunkIndex,
      receivedOffset: _receivedBytes,
    );
  }

  /// Marks connection interrupted (e.g. simulated network drop).
  void markInterrupted() {
    step = TransferStep.interrupted;
  }

  /// Resumes session from current received offset.
  int getResumeOffset() {
    return _receivedBytes;
  }

  /// Assembles all received chunks and verifies SHA-256 against meta (Golden Test 104).
  bool verifyAndComplete() {
    step = TransferStep.verify;

    if (_receivedBytes != meta.fileSizeBytes) {
      step = TransferStep.failed;
      return false;
    }

    // Assemble bytes in sequential chunk index order
    final builder = BytesBuilder(copy: false);
    final sortedKeys = _receivedChunks.keys.toList()..sort();
    for (final index in sortedKeys) {
      builder.add(_receivedChunks[index]!);
    }
    final assembled = builder.takeBytes();

    final computedHash = sha256.convert(assembled).toString();
    if (computedHash == meta.sha256Hash) {
      step = TransferStep.complete;
      return true;
    } else {
      step = TransferStep.failed;
      return false;
    }
  }

  /// Returns assembled bytes if completed successfully.
  List<int>? getAssembledBytes() {
    if (step != TransferStep.complete) return null;
    final builder = BytesBuilder(copy: false);
    final sortedKeys = _receivedChunks.keys.toList()..sort();
    for (final index in sortedKeys) {
      builder.add(_receivedChunks[index]!);
    }
    return builder.takeBytes();
  }
}
