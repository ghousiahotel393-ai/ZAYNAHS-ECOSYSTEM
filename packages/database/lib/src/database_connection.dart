/// SQLite Database Connection Factory and Configuration.
/// Enforces WAL mode, foreign keys, and busy timeout according to Rule 81-85.
library database_connection;

import 'dart:io';
import 'package:sqlite3/sqlite3.dart';

class DatabaseConnection {
  final Database db;
  final bool isInMemory;
  final String? filePath;

  DatabaseConnection._(this.db, {this.isInMemory = false, this.filePath});

  /// Opens or creates an on-disk SQLite database file with WAL mode.
  factory DatabaseConnection.openFile(String path) {
    // Ensure parent directory exists
    final file = File(path);
    if (!file.parent.existsSync()) {
      file.parent.createSync(recursive: true);
    }

    final db = sqlite3.open(path);
    _configurePragmas(db, isDisk: true);
    return DatabaseConnection._(db, isInMemory: false, filePath: path);
  }

  /// Opens an in-memory SQLite database (isolated, ideal for tests).
  factory DatabaseConnection.openInMemory() {
    final db = sqlite3.openInMemory();
    _configurePragmas(db, isDisk: false);
    return DatabaseConnection._(db, isInMemory: true);
  }

  static void _configurePragmas(Database db, {required bool isDisk}) {
    // 1. Mandatory foreign key enforcement (Rule 81)
    db.execute('PRAGMA foreign_keys = ON;');

    // 2. 5-second busy timeout to handle concurrent access without immediate lock failure
    db.execute('PRAGMA busy_timeout = 5000;');

    if (isDisk) {
      // 3. Write-Ahead Logging for non-blocking concurrent readers
      db.execute('PRAGMA journal_mode = WAL;');
      // 4. Normal synchronous mode for balanced speed and crash resilience with WAL
      db.execute('PRAGMA synchronous = NORMAL;');
    }
  }

  /// Executes a DDL or mutating statement.
  void execute(String sql, [List<Object?> parameters = const []]) {
    db.execute(sql, parameters);
  }

  /// Executes a query returning rows.
  ResultSet select(String sql, [List<Object?> parameters = const []]) {
    return db.select(sql, parameters);
  }

  /// Closes database connection.
  void close() {
    db.dispose();
  }
}
