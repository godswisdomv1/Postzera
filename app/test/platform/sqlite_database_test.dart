import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:postzera/core/models/app_error.dart';
import 'package:postzera/core/services/storage_migrations.dart';
import 'package:postzera/platform/storage/sqlite_database.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  late Directory dir;
  late String path;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('postzera_db_');
    path = '${dir.path}/postzera.db';
  });

  tearDown(() {
    dir.deleteSync(recursive: true);
  });

  test('a new in-memory database is migrated to the current version', () {
    final DatabaseOpenResult r = SqliteDatabase.openInMemory();
    final Database db = r.database!;
    expect(db.userVersion, StorageMigrations.currentVersion);
    final List<Object?> tables = db
        .select("SELECT name FROM sqlite_master WHERE type = 'table'")
        .map((Row row) => row['name'])
        .toList();
    expect(tables, containsAll(<String>['posts', 'platform_profiles', 'send_records']));
    db.close();
  });

  test('foreign keys are switched on', () {
    final Database db = SqliteDatabase.openInMemory().database!;
    expect(db.select('PRAGMA foreign_keys').first.values.first, 1);
    db.close();
  });

  test('a new file is created, migrated and reopened without changes', () {
    final DatabaseOpenResult first = SqliteDatabase.openFile(path);
    expect(first.database, isNotNull);
    expect(first.recoveredFromCorruption, isFalse);
    first.database!.execute(
      "INSERT INTO platform_profiles VALUES('x', 0, 1, 0, '{}')",
    );
    first.database!.close();

    final DatabaseOpenResult second = SqliteDatabase.openFile(path);
    expect(second.recoveredFromCorruption, isFalse);
    expect(
      second.database!.select('SELECT COUNT(*) AS n FROM platform_profiles').first['n'],
      1,
    );
    second.database!.close();
  });

  test('a database from a newer app is refused and left untouched', () {
    final Database raw = sqlite3.open(path);
    raw.execute('CREATE TABLE future(a)');
    raw.userVersion = 99;
    raw.close();
    final int sizeBefore = File(path).lengthSync();

    expect(
      () => SqliteDatabase.openFile(path),
      throwsA(
        isA<AppError>().having(
          (AppError e) => e.kind,
          'kind',
          AppErrorKind.dbDowngrade,
        ),
      ),
    );

    expect(File(path).lengthSync(), sizeBefore);
    final Database check = sqlite3.open(path);
    expect(check.userVersion, 99);
    check.close();
    expect(
      dir.listSync().where((FileSystemEntity e) => e.path.contains('corrupt')),
      isEmpty,
    );
  });

  test('a damaged file is set aside and a fresh database is started', () {
    File(path).writeAsBytesSync(List<int>.filled(4096, 7));
    final DatabaseOpenResult r = SqliteDatabase.openFile(
      path,
      now: () => DateTime.utc(2026, 10, 18, 9),
    );
    expect(r.recoveredFromCorruption, isTrue);
    expect(r.database, isNotNull);
    expect(r.database!.userVersion, StorageMigrations.currentVersion);
    final List<String> names = dir
        .listSync()
        .map((FileSystemEntity e) => e.path.split('/').last)
        .toList();
    expect(names.any((String n) => n.startsWith('postzera.db.corrupt-')), isTrue);
    r.database!.close();
  });

  test('transaction keeps nothing when the body throws', () {
    final Database db = SqliteDatabase.openInMemory().database!;
    expect(
      () => SqliteDatabase.transaction<void>(db, () {
        db.execute("INSERT INTO platform_profiles VALUES('a', 0, 1, 0, '{}')");
        throw StateError('stop');
      }),
      throwsStateError,
    );
    expect(db.select('SELECT COUNT(*) AS n FROM platform_profiles').first['n'], 0);
    db.close();
  });
}
