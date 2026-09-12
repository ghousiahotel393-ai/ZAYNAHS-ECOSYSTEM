/// Central Database Engine for Zaynahs Ecosystem.
/// Orchestrates schema migrations, WAL connections, and atomic transactions.
library app_database;

import 'package:sqlite3/sqlite3.dart';
import 'database_connection.dart';
import 'schema/schema_v1.dart';

class AppDatabase {
  final DatabaseConnection connection;
  bool _initialized = false;

  AppDatabase(this.connection);

  /// Factory for on-disk database.
  factory AppDatabase.openFile(String path) =>
      AppDatabase(DatabaseConnection.openFile(path));

  /// Factory for in-memory database (tests).
  factory AppDatabase.openInMemory() =>
      AppDatabase(DatabaseConnection.openInMemory());

  Database get rawDb => connection.db;

  /// Initializes schema and runs pending migrations.
  void initialize() {
    if (_initialized) return;

    final currentVersion = getSchemaVersion();

    if (currentVersion == 0) {
      _applySchemaV1();
    } else if (currentVersion < SchemaV1.version) {
      _migrate(currentVersion, SchemaV1.version);
    }

    _initialized = true;
  }

  int getSchemaVersion() {
    final result = connection.select('PRAGMA user_version;');
    if (result.isEmpty) return 0;
    return result.first.values[0] as int? ?? 0;
  }

  void _applySchemaV1() {
    transaction(() {
      for (final sql in SchemaV1.ddlStatements) {
        connection.execute(sql);
      }
      connection.execute('PRAGMA user_version = ${SchemaV1.version};');
    });
  }

  void _migrate(int fromVersion, int toVersion) {
    // Incremental migrations will be added in future versions
    // For now, version 1 is baseline
  }

  int _transactionDepth = 0;

  bool get inTransaction => _transactionDepth > 0;

  /// Runs an atomic transaction block.
  /// Supports nested transactions via SQLite SAVEPOINT.
  /// If any exception occurs, rolled back immediately.
  T transaction<T>(T Function() action) {
    if (_transactionDepth > 0) {
      final savepointName = 'sp_$_transactionDepth';
      _transactionDepth++;
      connection.execute('SAVEPOINT $savepointName;');
      try {
        final result = action();
        connection.execute('RELEASE $savepointName;');
        return result;
      } catch (e) {
        try {
          connection.execute('ROLLBACK TO $savepointName;');
          connection.execute('RELEASE $savepointName;');
        } catch (_) {}
        rethrow;
      } finally {
        _transactionDepth--;
      }
    } else {
      _transactionDepth = 1;
      connection.execute('BEGIN IMMEDIATE;');
      try {
        final result = action();
        connection.execute('COMMIT;');
        return result;
      } catch (e) {
        try {
          connection.execute('ROLLBACK;');
        } catch (_) {}
        rethrow;
      } finally {
        _transactionDepth = 0;
      }
    }
  }

  void close() {
    connection.close();
  }
}
