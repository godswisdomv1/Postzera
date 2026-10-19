import 'package:flutter_test/flutter_test.dart';
import 'package:postzera/core/services/storage_migrations.dart';

void main() {
  test('the current version is 1', () {
    expect(StorageMigrations.currentVersion, 1);
  });

  test('a new database gets every table and index', () {
    final String sql = StorageMigrations.stepsBetween(0, 1).join(';\n');
    expect(sql, contains('CREATE TABLE posts'));
    expect(sql, contains('CREATE TABLE platform_profiles'));
    expect(sql, contains('CREATE TABLE send_records'));
    expect(sql, contains('ON DELETE CASCADE'));
    expect(sql, contains('idx_posts_scheduled'));
    expect(sql, contains('idx_posts_status'));
  });

  test('an up-to-date database has nothing to do', () {
    expect(StorageMigrations.stepsBetween(1, 1), isEmpty);
  });

  test('a version this app does not know is refused', () {
    expect(() => StorageMigrations.stepsBetween(0, 2), throwsArgumentError);
    expect(() => StorageMigrations.stepsBetween(-1, 1), throwsArgumentError);
  });
}
