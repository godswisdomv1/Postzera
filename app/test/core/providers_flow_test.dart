import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:postzera/core/data/builtin_card_themes.dart';
import 'package:postzera/core/models/app_error.dart';
import 'package:postzera/core/models/media_source.dart';
import 'package:postzera/core/models/platform_profile.dart';
import 'package:postzera/core/models/post.dart';
import 'package:postzera/core/models/send_record.dart';
import 'package:postzera/core/models/variant.dart';
import 'package:postzera/core/ports/media_picker_port.dart';
import 'package:postzera/core/ports/notification_port.dart';
import 'package:postzera/core/ports/share_port.dart';
import 'package:postzera/core/providers/banner_provider.dart';
import 'package:postzera/core/providers/composer_provider.dart';
import 'package:postzera/core/providers/media_jobs_provider.dart';
import 'package:postzera/core/providers/posts_provider.dart';
import 'package:postzera/core/providers/profiles_provider.dart';
import 'package:postzera/core/providers/queue_provider.dart';
import 'package:postzera/core/providers/reminders_provider.dart';
import 'package:postzera/core/providers/settings_sync.dart';
import 'package:postzera/core/providers/undo_provider.dart';
import 'package:postzera/core/services/media_pipeline.dart';
import 'package:postzera/core/services/variant_builder.dart';
import 'package:postzera/platform/storage/sqlite_post_repository.dart';
import 'package:postzera/platform/storage/sqlite_profile_repository.dart';
import 'package:postzera/platform/storage/sqlite_send_record_repository.dart';

import 'fakes.dart';
import 'test_helpers.dart';

Future<void> wait([int ms = 40]) =>
    Future<void>.delayed(Duration(milliseconds: ms));

void main() {
  const VariantBuilder builder = VariantBuilder();

  Variant variant(String platform, {String hook = 'Hook'}) => builder.build(
        testPost(hook: hook, body: 'Body text', cta: 'Go'),
        profileById(platform),
        cardThemeById('paper'),
      );

  group('MediaJobsProvider', () {
    late FakeFileStore files;
    late FakeRenderer renderer;
    late MediaJobsProvider jobs;

    setUp(() {
      files = FakeFileStore();
      renderer = FakeRenderer(files);
      jobs = MediaJobsProvider(
        pipeline: MediaPipeline(
          files: files,
          renderer: renderer,
          video: FakeVideo(files),
        ),
      );
    });

    test('a job goes from queued to ready with its file', () async {
      final Variant v = variant('instagram');
      final Future<MediaResult> result = jobs.produce('p1', v);
      expect(jobs.jobFor('p1', 'instagram')?.status, MediaJobStatus.queued);
      final MediaResult r = await result;
      expect(r.path, endsWith('.png'));
      final MediaJob job = jobs.jobFor('p1', 'instagram')!;
      expect(job.status, MediaJobStatus.ready);
      expect(job.progress, 1);
      expect(job.result, r);
    });

    test('the same variant is never rendered twice', () async {
      final Variant v = variant('instagram');
      await jobs.produce('p1', v);
      await jobs.produce('p1', v);
      expect(renderer.images, 1);
    });

    test('asking again while it renders shares the one render', () async {
      renderer.gate = Completer<void>();
      final Variant v = variant('instagram');
      final Future<MediaResult> a = jobs.produce('p1', v);
      final Future<MediaResult> b = jobs.produce('p1', v);
      renderer.gate!.complete();
      expect((await a).path, (await b).path);
      expect(renderer.images, 1);
    });

    test('a changed variant of the same platform renders again', () async {
      await jobs.produce('p1', variant('instagram'));
      await jobs.produce('p1', variant('instagram', hook: 'Different'));
      expect(renderer.images, 2);
    });

    test('a failed render is a failed job, and retry makes it ready', () async {
      renderer.failWith = StateError('boom');
      final Variant v = variant('instagram');
      await expectLater(
        jobs.produce('p1', v),
        throwsA(
          isA<AppError>().having(
            (AppError e) => e.kind,
            'kind',
            AppErrorKind.renderFailed,
          ),
        ),
      );
      final MediaJob failed = jobs.jobFor('p1', 'instagram')!;
      expect(failed.status, MediaJobStatus.failed);
      expect(failed.error?.kind, AppErrorKind.renderFailed);

      renderer.failWith = null;
      jobs.retry('p1', v);
      await wait();
      expect(jobs.jobFor('p1', 'instagram')?.status, MediaJobStatus.ready);
    });

    test('requestAll renders every variant, one at a time', () async {
      jobs.requestAll('p1', <Variant>[
        variant('x'),
        variant('instagram'),
        variant('pinterest'),
      ]);
      await wait(100);
      expect(
        <MediaJobStatus?>[
          jobs.jobFor('p1', 'x')?.status,
          jobs.jobFor('p1', 'instagram')?.status,
          jobs.jobFor('p1', 'pinterest')?.status,
        ],
        everyElement(MediaJobStatus.ready),
      );
      expect(renderer.images, 3);
    });

    test('a queued job can be cancelled before it starts', () async {
      renderer.gate = Completer<void>();
      final Future<MediaResult> first = jobs.produce('p1', variant('instagram'));
      final Future<MediaResult> second = jobs.produce('p1', variant('x'));
      final Future<void> check = expectLater(second, throwsA(isA<MediaCancelled>()));
      await jobs.cancel('p1', 'x');
      await check;
      expect(jobs.jobFor('p1', 'x'), isNull);
      renderer.gate!.complete();
      await first;
      expect(jobs.jobFor('p1', 'instagram')?.status, MediaJobStatus.ready);
    });

    test('a running job can be cancelled', () async {
      renderer.gate = Completer<void>();
      final Future<MediaResult> running = jobs.produce('p1', variant('instagram'));
      final Future<void> check = expectLater(running, throwsA(isA<MediaCancelled>()));
      await wait(10);
      await jobs.cancel('p1', 'instagram');
      renderer.gate!.complete();
      await check;
      expect(jobs.jobFor('p1', 'instagram'), isNull);
      expect(files.sizes.keys.where((String k) => k.startsWith('/out/')), isEmpty);
    });

    test('cancelAll stops everything', () async {
      renderer.gate = Completer<void>();
      final Future<MediaResult> a = jobs.produce('p1', variant('instagram'));
      final Future<MediaResult> b = jobs.produce('p1', variant('x'));
      final Future<void> checkA = expectLater(a, throwsA(isA<MediaCancelled>()));
      final Future<void> checkB = expectLater(b, throwsA(isA<MediaCancelled>()));
      await wait(10);
      await jobs.cancelAll();
      renderer.gate!.complete();
      await checkA;
      await checkB;
      expect(jobs.value.jobs, isEmpty);
    });
  });

  group('QueueProvider', () {
    // Local times, so "today" is the same day in any time zone.
    final DateTime now = DateTime(2026, 10, 18, 8);
    final FixedClock clock = FixedClock(now);

    late InMemoryPostRepository posts;
    late InMemorySendRecordRepository records;
    late FakeFileStore files;
    late FakeRenderer renderer;
    late MediaJobsProvider jobs;
    late FakeClipboard clipboard;
    late FakeShare share;
    late UndoProvider undo;
    late BannerProvider banners;
    late ProfilesProvider profiles;
    late int changes;
    late QueueProvider queue;

    Post scheduled(String id, {DateTime? at}) => testPost(
          hook: 'Hook',
          body: 'Body text',
          cta: 'Go',
          link: 'https://example.com',
        ).copyWith(
          id: id,
          status: PostStatus.scheduled,
          scheduledAt: (at ?? DateTime(2026, 10, 18, 18)).toUtc(),
        );

    setUp(() async {
      posts = InMemoryPostRepository();
      records = InMemorySendRecordRepository();
      files = FakeFileStore();
      renderer = FakeRenderer(files);
      jobs = MediaJobsProvider(
        pipeline: MediaPipeline(
          files: files,
          renderer: renderer,
          video: FakeVideo(files),
        ),
      );
      clipboard = FakeClipboard();
      share = FakeShare();
      undo = UndoProvider();
      banners = BannerProvider();
      profiles = ProfilesProvider(
        profiles: InMemoryProfileRepository(),
        banners: banners,
      );
      await profiles.load();
      changes = 0;
      queue = QueueProvider(
        posts: posts,
        records: records,
        profiles: profiles,
        jobs: jobs,
        files: files,
        clipboard: clipboard,
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

    test('load sorts scheduled posts into today and upcoming', () async {
      await posts.upsert(scheduled('today'));
      await posts.upsert(scheduled('later', at: DateTime(2026, 10, 20, 9)));
      await posts.upsert(scheduled('draft').copyWith(status: PostStatus.draft));
      await queue.load();
      expect(queue.value.loading, isFalse);
      expect(queue.value.sections.today.single.post.id, 'today');
      expect(queue.value.sections.upcoming.single.post.id, 'later');
      expect(queue.value.sections.today.single.platformCount, 9);
    });

    test('send makes the media, copies the caption and opens the share sheet',
        () async {
      await posts.upsert(scheduled('p1'));
      final ShareOutcome? outcome = await queue.send('p1', 'instagram');
      expect(outcome, ShareOutcome.opened);
      expect(share.shared.single.path, endsWith('.png'));
      expect(clipboard.copied.single, share.shared.single.text);
      expect(clipboard.copied.single, startsWith('Hook'));
      expect(queue.value.confirmation, const SendConfirmation('p1', 'instagram'));
      expect(queue.value.sending, isFalse);
    });

    test('an unavailable share sheet shows an error and no confirmation', () async {
      await posts.upsert(scheduled('p1'));
      share.outcome = ShareOutcome.unavailable;
      await queue.send('p1', 'instagram');
      expect(queue.value.confirmation, isNull);
      expect(queue.value.error?.kind, AppErrorKind.shareUnavailable);
    });

    test('a share failure is classified and retryable', () async {
      await posts.upsert(scheduled('p1'));
      share.failWith = StateError('no app');
      final ShareOutcome? outcome = await queue.send('p1', 'instagram');
      expect(outcome, isNull);
      expect(queue.value.error?.kind, AppErrorKind.shareFailed);
      expect(queue.value.error?.retriable, isTrue);
      queue.clearError();
      expect(queue.value.error, isNull);
    });

    test('a render failure stops the send before sharing', () async {
      await posts.upsert(scheduled('p1'));
      renderer.failWith = StateError('boom');
      await queue.send('p1', 'instagram');
      expect(queue.value.error?.kind, AppErrorKind.renderFailed);
      expect(share.shared, isEmpty);
      expect(clipboard.copied, isEmpty);
    });

    test('a post that no longer exists is an error, not a crash', () async {
      await queue.send('ghost', 'instagram');
      expect(queue.value.error, isNotNull);
    });

    test('the app never marks a post by itself', () async {
      await posts.upsert(scheduled('p1'));
      await queue.send('p1', 'instagram');
      expect(await records.forPost('p1'), isEmpty);
      queue.dismissConfirmation();
      expect(queue.value.confirmation, isNull);
      expect(await records.forPost('p1'), isEmpty);
    });

    test('marking as posted records it, counts it, and can be undone', () async {
      await posts.upsert(scheduled('p1'));
      await queue.load();
      await queue.markPosted('p1', 'instagram');
      expect((await records.forPost('p1')).single.status, SendStatus.done);
      expect(queue.value.sections.today.single.doneCount, 1);
      expect(queue.value.statusOf('p1', 'instagram'), SendStatus.done);
      expect(undo.value?.label, UndoLabel.markedPosted);
      expect(changes, 1);

      await undo.undo();
      expect(queue.value.statusOf('p1', 'instagram'), SendStatus.pending);
      expect(queue.value.sections.today.single.doneCount, 0);
    });

    test('skipping records it as skipped', () async {
      await posts.upsert(scheduled('p1'));
      await queue.load();
      await queue.skip('p1', 'reddit');
      expect(queue.value.statusOf('p1', 'reddit'), SendStatus.skipped);
      expect(queue.value.sections.today.single.skippedCount, 1);
    });

    test('when every platform is done or skipped the post is sent and leaves the queue',
        () async {
      await posts.upsert(scheduled('p1'));
      await queue.load();
      final List<String> ids =
          profiles.value.enabled.map((PlatformProfile p) => p.id).toList();
      for (int i = 0; i < ids.length; i++) {
        if (i.isEven) {
          await queue.markPosted('p1', ids[i]);
        } else {
          await queue.skip('p1', ids[i]);
        }
      }
      expect((await posts.byId('p1'))!.status, PostStatus.sent);
      expect(queue.value.sections.isEmpty, isTrue);

      await undo.undo();
      expect((await posts.byId('p1'))!.status, PostStatus.scheduled);
      expect(queue.value.sections.today.length, 1);
    });

    test('copyTitle puts the platform title on the clipboard', () async {
      await posts.upsert(scheduled('p1'));
      await queue.copyTitle('p1', 'reddit');
      expect(clipboard.copied, <String>['Hook']);
      expect(banners.value.transient?.message, BannerMessage.titleCopied);
    });

    test('copyTitle does nothing on a platform without a title', () async {
      await posts.upsert(scheduled('p1'));
      await queue.copyTitle('p1', 'instagram');
      expect(clipboard.copied, isEmpty);
    });

    test('copyCaption puts the caption on the clipboard', () async {
      await posts.upsert(scheduled('p1'));
      await queue.copyCaption('p1', 'instagram');
      expect(clipboard.copied.single, startsWith('Hook'));
      expect(banners.value.transient?.message, BannerMessage.captionCopied);
    });
  });

  group('ComposerProvider', () {
    final DateTime morning = DateTime(2026, 10, 18, 8);

    late InMemoryPostRepository repo;
    late FakeFileStore files;
    late FakePicker picker;
    late BannerProvider banners;
    late SettingsSync settings;
    late ProfilesProvider profiles;
    late PostsProvider posts;
    late FixedClock clock;
    late ComposerProvider composer;

    ComposerProvider make(DateTime at) {
      clock = FixedClock(at);
      return ComposerProvider(
        posts: PostsProvider(
          posts: repo,
          records: InMemorySendRecordRepository(),
          files: files,
          share: FakeShare(),
          clock: clock,
          undo: UndoProvider(),
          banners: banners,
        ),
        profiles: profiles,
        settings: settings,
        picker: picker,
        files: files,
        clock: clock,
        banners: banners,
        autosaveDelay: const Duration(milliseconds: 15),
      );
    }

    setUp(() async {
      repo = InMemoryPostRepository();
      files = FakeFileStore();
      picker = FakePicker();
      banners = BannerProvider();
      settings = SettingsSync(FakeSettingsStore());
      profiles = ProfilesProvider(
        profiles: InMemoryProfileRepository(),
        banners: banners,
      );
      await profiles.load();
      composer = make(morning);
    });

    tearDown(() => composer.dispose());

    test('a new post gets an id and the default theme', () {
      composer.startNew();
      expect(composer.value.postId.length, 22);
      expect(composer.value.cardThemeId, 'paper');
      expect(composer.value.isNew, isTrue);
      expect(composer.value.hasContent, isFalse);
    });

    test('typing is autosaved as a draft after a pause', () async {
      composer.startNew();
      composer.setHook('Hello');
      expect(await repo.all(), isEmpty);
      await wait(60);
      final Post saved = (await repo.all()).single;
      expect(saved.hook, 'Hello');
      expect(saved.status, PostStatus.draft);
      expect(composer.value.isNew, isFalse);
    });

    test('typing again resets the pause, so only the final text is saved', () async {
      composer.startNew();
      composer.setHook('a');
      await wait(8);
      composer.setHook('ab');
      await wait(8);
      composer.setHook('abc');
      await wait(70);
      final List<Post> all = await repo.all();
      expect(all.length, 1);
      expect(all.single.hook, 'abc');
    });

    test('an empty form is never saved', () async {
      composer.startNew();
      composer.setHook('   ');
      await wait(60);
      expect(await repo.all(), isEmpty);
    });

    test('the hook is required before variants can be built', () async {
      composer.startNew();
      composer.setBody('Only a body');
      expect(await composer.buildVariants(), isFalse);
      expect(composer.value.hookError?.kind, AppErrorKind.validation);
      composer.setHook('Now a hook');
      expect(composer.value.hookError, isNull);
      expect(await composer.buildVariants(), isTrue);
    });

    test('building gives one variant per enabled platform, cleared by editing', () async {
      composer.startNew();
      composer.setHook('Hello');
      composer.setBody('World');
      await composer.buildVariants();
      expect(composer.value.variants.length, 9);
      composer.setBody('Changed');
      expect(composer.value.variants, isEmpty);
    });

    test('hashtags are cleaned when the variants are built', () async {
      composer.startNew();
      composer.setHook('Hello');
      composer.setHashtagsText('one, #two  ONE');
      await composer.buildVariants();
      final Variant instagram = composer.value.variants
          .firstWhere((Variant v) => v.platformId == 'instagram');
      expect(instagram.caption, endsWith('#one #two'));
    });

    test('scheduling before the daily time picks today at that time', () async {
      composer.startNew();
      composer.setHook('Hello');
      final Post? post = await composer.schedule();
      expect(post!.status, PostStatus.scheduled);
      expect(post.scheduledAt, DateTime(2026, 10, 18, 9).toUtc());
      expect((await repo.byId(post.id))!.status, PostStatus.scheduled);
      expect(banners.value.transient?.message, BannerMessage.postScheduled);
    });

    test('scheduling after the daily time picks tomorrow', () async {
      composer.dispose();
      composer = make(DateTime(2026, 10, 18, 10));
      composer.startNew();
      composer.setHook('Hello');
      final Post? post = await composer.schedule();
      expect(post!.scheduledAt, DateTime(2026, 10, 19, 9).toUtc());
    });

    test('a chosen time is used as it is', () async {
      composer.startNew();
      composer.setHook('Hello');
      composer.setSchedule(DateTime(2026, 11, 2, 14, 30));
      final Post? post = await composer.schedule();
      expect(post!.scheduledAt, DateTime(2026, 11, 2, 14, 30).toUtc());
    });

    test('scheduling needs a hook', () async {
      composer.startNew();
      expect(await composer.schedule(), isNull);
      expect(await repo.all(), isEmpty);
    });

    test('send now queues the post for this moment', () async {
      composer.startNew();
      composer.setHook('Hello');
      final Post? post = await composer.sendNow();
      expect(post!.status, PostStatus.scheduled);
      expect(post.scheduledAt, morning.toUtc());
    });

    test('a photo is copied into the app and used', () async {
      picker.photo = const PickedMedia(path: '/gallery/a.jpg', sizeBytes: 5);
      composer.startNew();
      await composer.pickPhoto();
      final String id = composer.value.postId;
      expect(composer.value.media.kind, MediaSourceKind.photo);
      expect(composer.value.media.path, '/src/$id.jpg');
      expect(composer.value.pickingMedia, isFalse);
    });

    test('a video keeps its length', () async {
      picker.video = const PickedMedia(
        path: '/gallery/a.mp4',
        sizeBytes: 5,
        durationMs: 9000,
      );
      composer.startNew();
      await composer.pickVideo();
      expect(composer.value.media.kind, MediaSourceKind.video);
      expect(composer.value.media.durationMs, 9000);
    });

    test('backing out of the picker changes nothing', () async {
      composer.startNew();
      await composer.pickPhoto();
      expect(composer.value.media.isAuto, isTrue);
      expect(composer.value.error, isNull);
    });

    test('an unreadable photo is a sourceUnreadable error', () async {
      picker.failWith = AppError.of(AppErrorKind.sourceUnreadable);
      composer.startNew();
      await composer.pickPhoto();
      expect(composer.value.error?.kind, AppErrorKind.sourceUnreadable);
      expect(composer.value.media.isAuto, isTrue);
    });

    test('going back to a text card removes the copy', () async {
      picker.photo = const PickedMedia(path: '/gallery/a.jpg', sizeBytes: 5);
      composer.startNew();
      await composer.pickPhoto();
      final String copy = composer.value.media.path!;
      await composer.useAutoCard();
      expect(composer.value.media.isAuto, isTrue);
      expect(files.deleted, contains(copy));
    });

    test('a post that was never saved cleans up its files when abandoned', () async {
      composer.startNew();
      final String id = composer.value.postId;
      await composer.discardIfUnsaved();
      expect(files.deletedPostFiles, <String>[id]);
    });

    test('a saved post keeps its files when the screen is left', () async {
      composer.startNew();
      composer.setHook('Hello');
      await composer.saveDraft();
      await composer.discardIfUnsaved();
      expect(files.deletedPostFiles, isEmpty);
    });

    test('editing a scheduled post keeps it scheduled', () async {
      final Post original = testPost(hook: 'Old', body: 'x').copyWith(
        id: 'p1',
        status: PostStatus.scheduled,
        scheduledAt: DateTime.utc(2026, 11, 1, 9),
        hashtags: const <String>['#a'],
        createdAt: DateTime.utc(2026, 10, 1),
      );
      await repo.upsert(original);
      composer.edit(original);
      expect(composer.value.hashtagsText, '#a');
      expect(composer.value.isNew, isFalse);
      composer.setBody('Edited');
      await wait(60);
      final Post saved = (await repo.byId('p1'))!;
      expect(saved.body, 'Edited');
      expect(saved.status, PostStatus.scheduled);
      expect(saved.scheduledAt, DateTime.utc(2026, 11, 1, 9));
      expect(saved.createdAt, DateTime.utc(2026, 10, 1));
    });

    test('the strictest caption limit is passed through for the hint', () {
      expect(composer.strictestCaptionLimit, 280);
    });

    test('one platform can fall back to a plain card after its render failed',
        () async {
      picker.photo = const PickedMedia(path: '/gallery/a.jpg', sizeBytes: 5);
      composer.startNew();
      composer.setHook('Hello');
      await composer.pickPhoto();
      await composer.buildVariants();
      final Variant before = composer.value.variants
          .firstWhere((Variant v) => v.platformId == 'instagram');
      expect(before.mediaPlan.sourceKind, MediaSourceKind.photo);
      final Variant? plain = composer.variantWithAutoCard('instagram');
      expect(plain!.mediaPlan.sourceKind, MediaSourceKind.auto);
      expect(composer.value.variants.length, 9);
      final Variant other = composer.value.variants
          .firstWhere((Variant v) => v.platformId == 'x');
      expect(other.mediaPlan.sourceKind, MediaSourceKind.photo);
    });
  });

  group('RemindersProvider', () {
    final DateTime now = DateTime.utc(2026, 10, 18, 8);

    late FakeNotifications notifications;
    late InMemoryPostRepository repo;
    late SettingsSync settings;
    late FakeSettingsStore settingsStore;
    late ProfilesProvider profiles;
    late RemindersProvider reminders;

    Post scheduled(String id, DateTime at) => testPost().copyWith(
          id: id,
          status: PostStatus.scheduled,
          scheduledAt: at,
        );

    setUp(() async {
      notifications = FakeNotifications();
      repo = InMemoryPostRepository();
      settingsStore = FakeSettingsStore();
      settings = SettingsSync(settingsStore);
      profiles = ProfilesProvider(
        profiles: InMemoryProfileRepository(),
        banners: BannerProvider(),
      );
      await profiles.load();
      reminders = RemindersProvider(
        notifications: notifications,
        posts: repo,
        profiles: profiles,
        settings: settings,
        clock: FixedClock(now),
        texts: testTexts,
      );
    });

    test('init prepares notifications and reads the permission', () async {
      notifications.permission = NotificationPermission.granted;
      await reminders.init();
      expect(notifications.inits, 1);
      expect(reminders.value.permission, NotificationPermission.granted);
    });

    test('sync schedules one reminder per distinct minute', () async {
      await repo.upsert(scheduled('a', DateTime.utc(2026, 10, 19, 9)));
      await repo.upsert(scheduled('b', DateTime.utc(2026, 10, 19, 9, 0, 30)));
      await repo.upsert(scheduled('c', DateTime.utc(2026, 10, 20, 9)));
      await reminders.sync();
      expect(notifications.replaced.single.length, 2);
      expect(notifications.replaced.single.first.postCount, 2);
      expect(reminders.value.scheduledCount, 2);
      expect(reminders.value.error, isNull);
      expect(reminders.value.syncing, isFalse);
    });

    test('with reminders turned off, everything is cancelled', () async {
      await repo.upsert(scheduled('a', DateTime.utc(2026, 10, 19, 9)));
      await settings.update((s) => s.copyWith(remindersEnabled: false));
      await reminders.sync();
      expect(notifications.replaced, isEmpty);
      expect(notifications.cancels, 1);
      expect(reminders.value.scheduledCount, 0);
    });

    test('a scheduling failure is a retryable error and the next sync clears it',
        () async {
      await repo.upsert(scheduled('a', DateTime.utc(2026, 10, 19, 9)));
      notifications.failReplace = StateError('os');
      await reminders.sync();
      expect(reminders.value.error?.kind, AppErrorKind.scheduleFailed);
      expect(reminders.value.error?.retriable, isTrue);
      notifications.failReplace = null;
      await reminders.sync();
      expect(reminders.value.error, isNull);
      expect(notifications.replaced.length, 1);
    });

    test('granting permission schedules the reminders', () async {
      await repo.upsert(scheduled('a', DateTime.utc(2026, 10, 19, 9)));
      final NotificationPermission result = await reminders.requestPermission();
      expect(result, NotificationPermission.granted);
      expect(notifications.replaced.length, 1);
    });

    test('denying permission schedules nothing', () async {
      await repo.upsert(scheduled('a', DateTime.utc(2026, 10, 19, 9)));
      notifications.onRequest = NotificationPermission.denied;
      final NotificationPermission result = await reminders.requestPermission();
      expect(result, NotificationPermission.denied);
      expect(reminders.value.permission, NotificationPermission.denied);
      expect(notifications.replaced, isEmpty);
    });

    test('a change during a sync triggers one more sync, so the last change wins',
        () async {
      await repo.upsert(scheduled('a', DateTime.utc(2026, 10, 19, 9)));
      notifications.gate = Completer<void>();
      final Future<void> first = reminders.sync();
      await wait(10);
      await repo.upsert(scheduled('b', DateTime.utc(2026, 10, 20, 9)));
      await reminders.sync();
      notifications.gate!.complete();
      await first;
      expect(notifications.replaced.length, 2);
      expect(notifications.replaced.first.length, 1);
      expect(notifications.replaced.last.length, 2);
    });

    test('taps and the launching tap come through', () async {
      notifications.launch = const NotificationTap(42);
      expect((await reminders.launchTap())?.notificationId, 42);
      final Future<NotificationTap> next = reminders.taps.first;
      notifications.tapController.add(const NotificationTap(7));
      expect((await next).notificationId, 7);
    });
  });
}
