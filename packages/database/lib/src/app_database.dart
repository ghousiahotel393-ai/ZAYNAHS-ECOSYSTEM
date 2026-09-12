/// Central Database Engine for Zaynahs Ecosystem.
/// Orchestrates schema migrations, WAL connections, and atomic transactions.
library app_database;

import 'package:sqlite3/sqlite3.dart';
import 'database_connection.dart';
import 'schema/schema_v1.dart';
import 'schema/schema_v2.dart';

class AppDatabase {
  final DatabaseConnection connection;
  bool _initialized = false;

  static const int currentSchemaVersion = SchemaV2.version;

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
      _applyInitialSchema();
    } else if (currentVersion < currentSchemaVersion) {
      _migrate(currentVersion, currentSchemaVersion);
    }

    _initialized = true;
  }

  int getSchemaVersion() {
    final result = connection.select('PRAGMA user_version;');
    if (result.isEmpty) return 0;
    return result.first.values[0] as int? ?? 0;
  }

  void _applyInitialSchema() {
    transaction(() {
      for (final sql in SchemaV1.ddlStatements) {
        connection.execute(sql);
      }
      for (final sql in SchemaV2.migrationStatements) {
        connection.execute(sql);
      }
      connection.execute('PRAGMA user_version = $currentSchemaVersion;');
    });
  }

  void _migrate(int fromVersion, int toVersion) {
    transaction(() {
      if (fromVersion < 2 && toVersion >= 2) {
        for (final sql in SchemaV2.migrationStatements) {
          connection.execute(sql);
        }
        connection.execute('PRAGMA user_version = 2;');
      }
    });
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
