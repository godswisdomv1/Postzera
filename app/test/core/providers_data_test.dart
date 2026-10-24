import 'package:flutter_test/flutter_test.dart';
import 'package:postzera/core/models/app_error.dart';
import 'package:postzera/core/models/media_source.dart';
import 'package:postzera/core/models/media_spec.dart';
import 'package:postzera/core/models/platform_profile.dart';
import 'package:postzera/core/models/post.dart';
import 'package:postzera/core/models/send_record.dart';
import 'package:postzera/core/ports/file_import_port.dart';
import 'package:postzera/core/ports/post_repository.dart';
import 'package:postzera/core/ports/share_port.dart';
import 'package:postzera/core/providers/banner_provider.dart';
import 'package:postzera/core/providers/import_provider.dart';
import 'package:postzera/core/providers/posts_provider.dart';
import 'package:postzera/core/providers/profiles_provider.dart';
import 'package:postzera/core/providers/undo_provider.dart';
import 'package:postzera/core/services/csv_importer.dart';
import 'package:postzera/platform/storage/sqlite_post_repository.dart';
import 'package:postzera/platform/storage/sqlite_profile_repository.dart';
import 'package:postzera/platform/storage/sqlite_send_record_repository.dart';

import 'fakes.dart';
import 'test_helpers.dart';

void main() {
  final FixedClock clock = FixedClock(DateTime.utc(2026, 10, 18, 8));

  group('PostsProvider', () {
    late InMemoryPostRepository repo;
    late InMemorySendRecordRepository records;
    late FakeFileStore files;
    late FakeShare share;
    late UndoProvider undo;
    late BannerProvider banners;
    late int changes;
    late PostsProvider provider;

    Post post(String id, {String hook = 'Hook', PostStatus status = PostStatus.draft}) =>
        testPost(hook: hook).copyWith(id: id, status: status);

    setUp(() {
      repo = InMemoryPostRepository();
      records = InMemorySendRecordRepository();
      files = FakeFileStore();
      share = FakeShare();
      undo = UndoProvider();
      banners = BannerProvider();
      changes = 0;
      provider = PostsProvider(
        posts: repo,
        records: records,
        files: files,
        share: share,
        clock: clock,
        undo: undo,
        banners: banners,
        onChanged: () => changes++,
      );
    });

    tearDown(() {
      undo.dispose();
      banners.dispose();
    });

    test('load finishes loading with an empty library', () async {
      await provider.load();
      expect(provider.value.loading, isFalse);
      expect(provider.value.posts, isEmpty);
    });

    test('save stamps the update time, tells reminders and can announce', () async {
      await provider.save(
        post('a'),
        announce: BannerMessage.postSaved,
      );
      final Post stored = (await repo.byId('a'))!;
      expect(stored.updatedAt, DateTime.utc(2026, 10, 18, 8));
      expect(provider.value.posts.single.id, 'a');
      expect(changes, 1);
      expect(banners.value.transient?.message, BannerMessage.postSaved);
    });

    test('search, status filter and sort reload the list', () async {
      await provider.save(post('a', hook: 'Apple'));
      await provider.save(post('b', hook: 'Banana', status: PostStatus.sent));
      await provider.setQuery('app');
      expect(provider.value.posts.map((Post p) => p.id).toList(), <String>['a']);
      await provider.setQuery('');
      await provider.setStatus(PostStatus.sent);
      expect(provider.value.posts.map((Post p) => p.id).toList(), <String>['b']);
      await provider.setStatus(null);
      expect(provider.value.posts.length, 2);
      await provider.setSort(PostSort.oldest);
      expect(provider.value.sort, PostSort.oldest);
    });

    test('duplicate makes a draft copy with its own photo copy', () async {
      await repo.upsert(
        post('a', status: PostStatus.scheduled).copyWith(
          scheduledAt: DateTime.utc(2026, 11, 1),
          mediaSource: const MediaSource(
            kind: MediaSourceKind.photo,
            path: '/src/a.jpg',
          ),
        ),
      );
      await provider.duplicate('a');
      final List<Post> all = await repo.all();
      expect(all.length, 2);
      final Post copy = all.firstWhere((Post p) => p.id != 'a');
      expect(copy.status, PostStatus.draft);
      expect(copy.scheduledAt, isNull);
      expect(copy.hook, 'Hook');
      expect(copy.mediaSource.path, '/src/${copy.id}.jpg');
      expect((await repo.byId('a'))!.mediaSource.path, '/src/a.jpg');
      expect(banners.value.transient?.message, BannerMessage.postDuplicated);
    });

    test('a failing media copy falls back to a text card', () async {
      files.failCopy = true;
      await repo.upsert(
        post('a').copyWith(
          mediaSource: const MediaSource(
            kind: MediaSourceKind.photo,
            path: '/src/a.jpg',
          ),
        ),
      );
      await provider.duplicate('a');
      final Post copy = (await repo.all()).firstWhere((Post p) => p.id != 'a');
      expect(copy.mediaSource.isAuto, isTrue);
    });

    test('delete can be undone, and its files are kept until then', () async {
      await repo.upsert(post('a'));
      await records.upsert(
        const SendRecord(postId: 'a', platformId: 'x', status: SendStatus.done),
      );
      await provider.load();
      await provider.delete('a');
      expect(await repo.all(), isEmpty);
      expect(await records.forPost('a'), isEmpty);
      expect(files.deletedPostFiles, isEmpty);
      expect(undo.value?.label, UndoLabel.postDeleted);

      await undo.undo();
      expect((await repo.byId('a'))?.hook, 'Hook');
      expect((await records.forPost('a')).length, 1);
      expect(provider.value.posts.length, 1);
      expect(files.deletedPostFiles, isEmpty);
    });

    test('once the undo window passes, the files are removed', () async {
      await repo.upsert(post('a'));
      await provider.delete('a');
      await undo.expire();
      expect(files.deletedPostFiles, <String>['a']);
    });

    test('exporting shares a CSV file and says so', () async {
      await repo.upsert(post('a', hook: 'First, post'));
      final ShareOutcome? outcome = await provider.exportCsv();
      expect(outcome, ShareOutcome.opened);
      expect(share.shared.single.path, '/exports/postzera-posts.csv');
      expect(files.exports['/exports/postzera-posts.csv'], contains('"First, post"'));
      expect(banners.value.transient?.message, BannerMessage.exported);
    });

    test('a share failure is reported, not thrown', () async {
      share.failWith = AppError.of(AppErrorKind.shareFailed);
      final ShareOutcome? outcome = await provider.exportCsv();
      expect(outcome, isNull);
      expect(banners.value.transient?.error?.kind, AppErrorKind.shareFailed);
    });
  });

  group('ProfilesProvider', () {
    late InMemoryProfileRepository repo;
    late BannerProvider banners;
    late ProfilesProvider provider;

    setUp(() async {
      repo = InMemoryProfileRepository();
      banners = BannerProvider();
      provider = ProfilesProvider(profiles: repo, banners: banners);
      await provider.load();
    });

    test('loads the nine built-in platforms, all enabled', () {
      expect(provider.value.profiles.length, 9);
      expect(provider.value.enabled.length, 9);
      expect(provider.value.loading, isFalse);
    });

    test('the strictest caption limit follows the enabled platforms', () async {
      expect(provider.value.strictestCaptionLimit, 280);
      await provider.setEnabled('x', enabled: false);
      expect(provider.value.strictestCaptionLimit, 500);
      expect(provider.value.enabled.length, 8);
    });

    test('with nothing enabled there is no limit', () async {
      for (final PlatformProfile p in provider.value.profiles) {
        await provider.setEnabled(p.id, enabled: false);
      }
      expect(provider.value.strictestCaptionLimit, isNull);
    });

    test('platforms move up and down, and stay in bounds', () async {
      await provider.move('instagram', -1);
      expect(provider.value.profiles.first.id, 'instagram');
      expect(provider.value.profiles[1].id, 'x');
      await provider.move('instagram', -1);
      expect(provider.value.profiles.first.id, 'instagram');
      await provider.move('quora', 1);
      expect(provider.value.profiles.last.id, 'quora');
    });

    test('a custom platform gets the default blocks and the end of the list', () async {
      final AppError? error = await provider.addCustom(
        name: ' My site ',
        monogram: 'MS',
        captionLimit: 400,
        aspect: MediaAspect.ratio2x3,
        maxHashtags: 4,
      );
      expect(error, isNull);
      final PlatformProfile custom = provider.value.profiles.last;
      expect(custom.name, 'My site');
      expect(custom.isCustom, isTrue);
      expect(custom.id, startsWith('custom-'));
      expect(custom.template.blocks.length, 5);
      expect(custom.media.widthPx, 1000);
      expect(custom.sortOrder, 9);
    });

    test('bad custom platform input is rejected without a change', () async {
      for (final ({String name, String mono, int limit}) bad in <({String name, String mono, int limit})>[
        (name: '', mono: 'A', limit: 100),
        (name: 'Ok', mono: '', limit: 100),
        (name: 'Ok', mono: 'ABC', limit: 100),
        (name: 'Ok', mono: 'A', limit: 0),
      ]) {
        final AppError? error = await provider.addCustom(
          name: bad.name,
          monogram: bad.mono,
          captionLimit: bad.limit,
          aspect: MediaAspect.ratio4x5,
          maxHashtags: 1,
        );
        expect(error?.kind, AppErrorKind.validation);
      }
      expect(provider.value.profiles.length, 9);
    });

    test('only custom platforms can be deleted', () async {
      await provider.addCustom(
        name: 'Mine',
        monogram: 'M',
        captionLimit: 100,
        aspect: MediaAspect.ratio4x5,
        maxHashtags: 0,
      );
      final String customId = provider.value.profiles.last.id;
      await provider.deleteCustom('x');
      await provider.deleteCustom(customId);
      expect(provider.value.profiles.length, 9);
      expect(provider.value.byId('x'), isNotNull);
    });

    test('an edited template can be reset to its default', () async {
      final PlatformProfile x = provider.value.byId('x')!;
      await provider.save(x.copyWith(captionLimit: 99, enabled: false));
      expect(provider.value.byId('x')!.captionLimit, 99);
      await provider.resetToDefault('x');
      expect(provider.value.byId('x')!.captionLimit, 280);
      expect(provider.value.byId('x')!.enabled, isFalse);
    });
  });

  group('ImportProvider', () {
    late FakeImport picker;
    late InMemoryPostRepository repo;
    late BannerProvider banners;
    late int changes;
    late ImportProvider provider;

    setUp(() {
      picker = FakeImport();
      repo = InMemoryPostRepository();
      banners = BannerProvider();
      changes = 0;
      int counter = 0;
      provider = ImportProvider(
        picker: picker,
        posts: repo,
        importer: CsvImporter(clock: clock, idGenerator: () => 'id${counter++}'),
        banners: banners,
        onChanged: () => changes++,
      );
    });

    test('picking previews the valid and invalid rows', () async {
      picker.file = const ImportedFile(
        name: 'posts.csv',
        text: 'hook,body\nA,1\nB,2\n,bad\n',
      );
      await provider.pick();
      expect(provider.value.status, ImportStatus.previewed);
      expect(provider.value.fileName, 'posts.csv');
      expect(provider.value.result!.valid.length, 2);
      expect(provider.value.result!.errors.single.line, 4);
    });

    test('confirming imports the valid rows and says how many', () async {
      picker.file = const ImportedFile(name: 'p.csv', text: 'hook\nA\nB\n');
      await provider.pick();
      await provider.confirm();
      expect(provider.value.status, ImportStatus.done);
      expect(provider.value.importedCount, 2);
      expect((await repo.all()).length, 2);
      expect(banners.value.transient?.message, BannerMessage.imported);
      expect(banners.value.transient?.count, 2);
      expect(changes, 1);
    });

    test('confirming before choosing a file does nothing', () async {
      await provider.confirm();
      expect(provider.value.status, ImportStatus.idle);
      expect(await repo.all(), isEmpty);
    });

    test('backing out of the picker leaves things as they were', () async {
      await provider.pick();
      expect(provider.value.status, ImportStatus.idle);
      picker.file = const ImportedFile(name: 'p.csv', text: 'hook\nA\n');
      await provider.pick();
      picker.file = null;
      await provider.pick();
      expect(provider.value.status, ImportStatus.previewed);
      expect(provider.value.result!.valid.length, 1);
    });

    test('an unreadable file is a failure with a retry path', () async {
      picker.failWith = AppError.of(AppErrorKind.importUnreadable);
      await provider.pick();
      expect(provider.value.status, ImportStatus.failed);
      expect(provider.value.error?.kind, AppErrorKind.importUnreadable);
      provider.reset();
      expect(provider.value.status, ImportStatus.idle);
    });

    test('a file with no hook column previews with nothing to import', () async {
      picker.file = const ImportedFile(name: 'p.csv', text: 'body\nx\n');
      await provider.pick();
      expect(provider.value.result!.hookColumnMissing, isTrue);
      expect(provider.value.result!.valid, isEmpty);
    });
  });
}
