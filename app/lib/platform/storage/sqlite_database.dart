import 'dart:io';

import 'package:postzera/core/models/app_error.dart';
import 'package:postzera/core/services/storage_migrations.dart';
import 'package:postzera/utils/log.dart';
import 'package:sqlite3/sqlite3.dart';

/// The outcome of opening the database.
class DatabaseOpenResult {
  const DatabaseOpenResult({
    this.database,
    this.problem,
    this.recoveredFromCorruption = false,
  });

  /// Null when SQLite cannot be used. The repositories then fall back to
  /// in-memory versions and the app shows a permanent warning.
  final Database? database;

  /// Set together with a null [database]: `dbUnavailable`.
  final AppError? problem;

  /// True when a damaged file was set aside and a fresh database created. The
  /// app shows a one-time `dbCorrupt` banner.
  final bool recoveredFromCorruption;
}

class _CorruptDatabase implements Exception {
  const _CorruptDatabase();
}

class _MigrationFailed implements Exception {
  const _MigrationFailed();
}

/// Opens, migrates and, when needed, repairs the database.
abstract final class SqliteDatabase {
  static const String fileName = 'postzera.db';

  /// Opens the database at [path].
  ///
  /// A newer database than this app understands throws an `AppError` of kind
  /// `dbDowngrade` and the file is not changed. A damaged file is renamed to
  /// `<path>.corrupt-<timestamp>` and a fresh database is created. If SQLite
  /// cannot be loaded or a migration fails, the result has no database.
  static DatabaseOpenResult openFile(String path, {DateTime Function()? now}) {
    final DateTime Function() clock = now ?? DateTime.now;
    final Database db;
    try {
      db = sqlite3.open(path);
    } on SqliteException {
      return _recover(path, clock);
    } catch (error) {
      Log.e('db', 'cannot load sqlite: ${error.runtimeType}');
      return _unavailable();
    }
    return _initializeOrRecover(db, path, clock);
  }

  /// A fresh in-memory database, for tests.
  static DatabaseOpenResult openInMemory() {
    final Database db = sqlite3.openInMemory();
    try {
      return DatabaseOpenResult(database: _initialize(db));
    } catch (error) {
      db.close();
      Log.e('db', 'in-memory setup failed: ${error.runtimeType}');
      return _unavailable();
    }
  }

  /// Runs [body] in one transaction. Nothing is kept if it throws.
  static T transaction<T>(Database db, T Function() body) {
    db.execute('BEGIN');
    try {
      final T result = body();
      db.execute('COMMIT');
      return result;
    } catch (_) {
      try {
        db.execute('ROLLBACK');
      } catch (_) {
        // Nothing left to roll back.
      }
      rethrow;
    }
  }

  static DatabaseOpenResult _initializeOrRecover(
    Database db,
    String path,
    DateTime Function() clock,
  ) {
    try {
      return DatabaseOpenResult(database: _initialize(db));
    } on _CorruptDatabase {
      db.close();
      return _recover(path, clock);
    } on SqliteException {
      db.close();
      return _recover(path, clock);
    } on _MigrationFailed {
      db.close();
      return _unavailable();
    }
  }

  static Database _initialize(Database db) {
    final int version = db.userVersion;
    if (version > StorageMigrations.currentVersion) {
      db.close();
      throw AppError.of(
        AppErrorKind.dbDowngrade,
        details: 'file version $version',
      );
    }
    final ResultSet check = db.select('PRAGMA quick_check');
    if (check.isEmpty || check.first.values.first != 'ok') {
      throw const _CorruptDatabase();
    }
    db.execute('PRAGMA foreign_keys = ON');

    final List<String> steps = StorageMigrations.stepsBetween(
      version,
      StorageMigrations.currentVersion,
    );
    if (steps.isNotEmpty) {
      try {
        transaction<void>(db, () {
          for (final String sql in steps) {
            db.execute(sql);
          }
          db.execute('PRAGMA user_version = ${StorageMigrations.currentVersion}');
        });
      } on SqliteException {
        throw const _MigrationFailed();
      }
    }
    return db;
  }

  static DatabaseOpenResult _recover(String path, DateTime Function() clock) {
    final String stamp = clock().toUtc().millisecondsSinceEpoch.toString();
    try {
      for (final String suffix in <String>['', '-wal', '-shm', '-journal']) {
        final File file = File('$path$suffix');
        if (file.existsSync()) {
          file.renameSync('$path.corrupt-$stamp$suffix');
        }
      }
      final Database fresh = sqlite3.open(path);
      final DatabaseOpenResult result = DatabaseOpenResult(
        database: _initialize(fresh),
        recoveredFromCorruption: true,
      );
      Log.w('db', 'damaged database set aside');
      return result;
    } on AppError {
      rethrow;
    } catch (error) {
      Log.e('db', 'recovery failed: ${error.runtimeType}');
      return _unavailable();
    }
  }

  static DatabaseOpenResult _unavailable() => DatabaseOpenResult(
        problem: AppError.of(AppErrorKind.dbUnavailable),
      );
}
