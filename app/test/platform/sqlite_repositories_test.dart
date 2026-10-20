import 'package:flutter_test/flutter_test.dart';
import 'package:postzera/core/data/default_profiles.dart';
import 'package:postzera/core/models/platform_profile.dart';
import 'package:postzera/core/models/send_record.dart';
import 'package:postzera/core/ports/profile_repository.dart';
import 'package:postzera/core/ports/send_record_repository.dart';
import 'package:postzera/platform/storage/sqlite_database.dart';
import 'package:postzera/platform/storage/sqlite_post_repository.dart';
import 'package:postzera/platform/storage/sqlite_profile_repository.dart';
import 'package:postzera/platform/storage/sqlite_send_record_repository.dart';
import 'package:sqlite3/sqlite3.dart';

import '../core/test_helpers.dart';
import 'post_repository_contract.dart';

void profileRepositoryContract(String name, ProfileRepository Function() make) {
  group(name, () {
    late ProfileRepository repo;
    setUp(() => repo = make());

    test('ensureDefaults fills the nine built-in profiles once', () async {
      await repo.ensureDefaults();
      final List<PlatformProfile> first = await repo.all();
      expect(first.map((PlatformProfile p) => p.id).toList(), <String>[
        'x',
        'instagram',
        'facebook',
        'linkedin',
        'tiktok',
        'pinterest',
        'reddit',
        'medium',
        'quora',
      ]);
      await repo.upsert(first.first.copyWith(enabled: false));
      await repo.ensureDefaults();
      expect((await repo.all()).first.enabled, isFalse);
      expect((await repo.all()).length, 9);
    });

    test('profiles survive a round trip unchanged', () async {
      await repo.ensureDefaults();
      final List<PlatformProfile> stored = await repo.all();
      final List<PlatformProfile> defaults = defaultProfiles();
      expect(stored, defaults);
    });

    test('reorder changes the display order', () async {
      await repo.ensureDefaults();
      final List<String> ids =
          (await repo.all()).map((PlatformProfile p) => p.id).toList();
      await repo.reorder(ids.reversed.toList());
      expect(
        (await repo.all()).map((PlatformProfile p) => p.id).toList(),
        ids.reversed.toList(),
      );
    });

    test('enabling and disabling is kept', () async {
      await repo.ensureDefaults();
      final PlatformProfile tiktok =
          (await repo.all()).firstWhere((PlatformProfile p) => p.id == 'tiktok');
      await repo.upsert(tiktok.copyWith(enabled: false));
      final PlatformProfile again =
          (await repo.all()).firstWhere((PlatformProfile p) => p.id == 'tiktok');
      expect(again.enabled, isFalse);
    });

    test('resetToDefault restores the template but keeps order and enabled',
        () async {
      await repo.ensureDefaults();
      final PlatformProfile x =
          (await repo.all()).firstWhere((PlatformProfile p) => p.id == 'x');
      await repo.upsert(
        x.copyWith(captionLimit: 99, enabled: false, sortOrder: 7),
      );
      await repo.resetToDefault('x');
      final PlatformProfile reset =
          (await repo.all()).firstWhere((PlatformProfile p) => p.id == 'x');
      expect(reset.captionLimit, 280);
      expect(reset.enabled, isFalse);
      expect(reset.sortOrder, 7);
    });

    test('only custom profiles can be deleted', () async {
      await repo.ensureDefaults();
      await repo.upsert(
        defaultProfiles().first.copyWith(
              id: 'mine',
              name: 'Mine',
              isCustom: true,
              sortOrder: 20,
            ),
      );
      await repo.delete('x');
      await repo.delete('mine');
      final List<String> ids =
          (await repo.all()).map((PlatformProfile p) => p.id).toList();
      expect(ids, contains('x'));
      expect(ids, isNot(contains('mine')));
    });
  });
}

void sendRecordRepositoryContract(
  String name,
  SendRecordRepository Function() make,
  Future<void> Function(String postId) prepare,
) {
  group(name, () {
    late SendRecordRepository repo;
    setUp(() => repo = make());

    SendRecord record(String post, String platform, SendStatus s) =>
        SendRecord(
          postId: post,
          platformId: platform,
          status: s,
          doneAt: s == SendStatus.done ? DateTime.utc(2026, 10, 18, 9) : null,
        );

    test('stores and replaces a record', () async {
      await prepare('p1');
      await repo.upsert(record('p1', 'x', SendStatus.pending));
      await repo.upsert(record('p1', 'x', SendStatus.done));
      final List<SendRecord> list = await repo.forPost('p1');
      expect(list.length, 1);
      expect(list.single.status, SendStatus.done);
      expect(list.single.doneAt, DateTime.utc(2026, 10, 18, 9));
    });

    test('forPosts groups records by post', () async {
      await prepare('p1');
      await prepare('p2');
      await repo.upsert(record('p1', 'x', SendStatus.done));
      await repo.upsert(record('p1', 'reddit', SendStatus.skipped));
      await repo.upsert(record('p2', 'x', SendStatus.done));
      final Map<String, List<SendRecord>> map =
          await repo.forPosts(<String>['p1', 'p2', 'p3']);
      expect(map['p1']!.length, 2);
      expect(map['p2']!.length, 1);
      expect(map.containsKey('p3'), isFalse);
    });

    test('deleteForPost removes only that post', () async {
      await prepare('p1');
      await prepare('p2');
      await repo.upsert(record('p1', 'x', SendStatus.done));
      await repo.upsert(record('p2', 'x', SendStatus.done));
      await repo.deleteForPost('p1');
      expect(await repo.forPost('p1'), isEmpty);
      expect((await repo.forPost('p2')).length, 1);
    });
  });
}

void main() {
  late Database db;
  setUp(() => db = SqliteDatabase.openInMemory().database!);
  tearDown(() => db.close());

  postRepositoryContract('SqlitePostRepository', () => SqlitePostRepository(db));
  postRepositoryContract('InMemoryPostRepository', InMemoryPostRepository.new);

  profileRepositoryContract(
    'SqliteProfileRepository',
    () => SqliteProfileRepository(db),
  );
  profileRepositoryContract(
    'InMemoryProfileRepository',
    InMemoryProfileRepository.new,
  );

  sendRecordRepositoryContract(
    'SqliteSendRecordRepository',
    () => SqliteSendRecordRepository(db),
    (String postId) => SqlitePostRepository(db).upsert(testPost().copyWith(id: postId)),
  );
  sendRecordRepositoryContract(
    'InMemorySendRecordRepository',
    InMemorySendRecordRepository.new,
    (String postId) async {},
  );

  group('SQLite specifics', () {
    test('saving a post again keeps its send records', () async {
      final SqlitePostRepository posts = SqlitePostRepository(db);
      final SqliteSendRecordRepository records = SqliteSendRecordRepository(db);
      await posts.upsert(testPost().copyWith(id: 'p1'));
      await records.upsert(
        const SendRecord(postId: 'p1', platformId: 'x', status: SendStatus.done),
      );
      await posts.upsert(testPost(hook: 'Edited').copyWith(id: 'p1'));
      expect((await records.forPost('p1')).length, 1);
    });

    test('deleting a post removes its send records', () async {
      final SqlitePostRepository posts = SqlitePostRepository(db);
      final SqliteSendRecordRepository records = SqliteSendRecordRepository(db);
      await posts.upsert(testPost().copyWith(id: 'p1'));
      await records.upsert(
        const SendRecord(postId: 'p1', platformId: 'x', status: SendStatus.done),
      );
      await posts.delete('p1');
      expect(await records.forPost('p1'), isEmpty);
    });

    test('deleting every post removes every send record', () async {
      final SqlitePostRepository posts = SqlitePostRepository(db);
      final SqliteSendRecordRepository records = SqliteSendRecordRepository(db);
      await posts.upsert(testPost().copyWith(id: 'p1'));
      await records.upsert(
        const SendRecord(postId: 'p1', platformId: 'x', status: SendStatus.done),
      );
      await posts.deleteAll();
      expect(await records.forPosts(<String>['p1']), isEmpty);
    });

    test('forPosts copes with more ids than one statement can take', () async {
      final SqliteSendRecordRepository records = SqliteSendRecordRepository(db);
      final List<String> ids = List<String>.generate(1000, (int i) => 'p$i');
      expect(await records.forPosts(ids), isEmpty);
    });
  });
}
