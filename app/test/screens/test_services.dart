import 'package:flutter/widgets.dart';
import 'package:postzera/core/models/post.dart';
import 'package:postzera/core/ports/ads_port.dart';
import 'package:postzera/core/ports/clock.dart';
import 'package:postzera/core/ports/notification_port.dart';
import 'package:postzera/core/ports/share_port.dart';
import 'package:postzera/core/providers/banner_provider.dart';
import 'package:postzera/core/providers/composer_provider.dart';
import 'package:postzera/core/providers/consent_provider.dart';
import 'package:postzera/core/providers/entitlement_provider.dart';
import 'package:postzera/core/providers/import_provider.dart';
import 'package:postzera/core/providers/locale_provider.dart';
import 'package:postzera/core/providers/media_jobs_provider.dart';
import 'package:postzera/core/providers/posts_provider.dart';
import 'package:postzera/core/providers/profiles_provider.dart';
import 'package:postzera/core/providers/queue_provider.dart';
import 'package:postzera/core/providers/reminders_provider.dart';
import 'package:postzera/core/providers/settings_provider.dart';
import 'package:postzera/core/providers/settings_sync.dart';
import 'package:postzera/core/providers/theme_provider.dart';
import 'package:postzera/core/providers/undo_provider.dart';
import 'package:postzera/core/services/csv_importer.dart';
import 'package:postzera/core/services/media_pipeline.dart';
import 'package:postzera/platform/storage/sqlite_post_repository.dart';
import 'package:postzera/platform/storage/sqlite_profile_repository.dart';
import 'package:postzera/platform/storage/sqlite_send_record_repository.dart';
import 'package:postzera/screens/screen_services.dart';
import 'package:postzera/widgets/pz_ad_slot.dart';

import '../core/fakes.dart';
import '../core/test_helpers.dart';

/// A link launcher that records what it was asked to open.
class FakeLinks implements LinkPort {
  final List<Uri> opened = <Uri>[];

  @override
  Future<bool> open(Uri url) async {
    opened.add(url);
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => Future<bool>.value(true);
}

/// Every service a screen may read, built from the real providers on
/// in-memory fakes, so a screen test exercises the real behaviour.
class TestServices implements ScreenServices {
  TestServices._();

  /// A fixed "now", in local time, so "today" is the same day anywhere.
  static final DateTime now = DateTime(2026, 10, 18, 8);

  late final FixedClock fixedClock = FixedClock(now);
  late final InMemoryPostRepository postRepo = InMemoryPostRepository();
  late final InMemorySendRecordRepository recordRepo =
      InMemorySendRecordRepository();
  late final InMemoryProfileRepository profileRepo =
      InMemoryProfileRepository();
  late final FakeFileStore files = FakeFileStore();
  late final FakeClipboard clipboard = FakeClipboard();
  late final FakeShare share = FakeShare();
  late final FakePicker picker = FakePicker();
  late final FakeLinks fakeLinks = FakeLinks();
  late final FakeImport fakeImport = FakeImport();
  late final FakeConsent fakeConsent = FakeConsent();
  late final FakeSettingsStore settingsStore = FakeSettingsStore();
  late final FakeRenderer renderer = FakeRenderer(files);
  late final FakeNotifications notifications = FakeNotifications();
  late final FakePurchases purchases = FakePurchases();
  late final SettingsSync sync = SettingsSync(settingsStore);

  @override
  late final BannerProvider banners = BannerProvider();
  @override
  late final UndoProvider undo = UndoProvider();
  @override
  late final ProfilesProvider profiles = ProfilesProvider(
    profiles: profileRepo,
    banners: banners,
  );
  @override
  late final MediaJobsProvider media = MediaJobsProvider(
    pipeline: MediaPipeline(
      files: files,
      renderer: renderer,
      video: FakeVideo(files),
    ),
  );
  @override
  late final PostsProvider posts = PostsProvider(
    posts: postRepo,
    records: recordRepo,
    files: files,
    share: share,
    clock: fixedClock,
    undo: undo,
    banners: banners,
  );
  @override
  late final QueueProvider queue = QueueProvider(
    posts: postRepo,
    records: recordRepo,
    profiles: profiles,
    jobs: media,
    files: files,
    clipboard: clipboard,
    share: share,
    clock: fixedClock,
    undo: undo,
    banners: banners,
  );
  @override
  late final ComposerProvider composer = ComposerProvider(
    posts: posts,
    profiles: profiles,
    settings: sync,
    picker: picker,
    files: files,
    clock: fixedClock,
    banners: banners,
  );
  @override
  late final EntitlementProvider entitlement = EntitlementProvider(
    purchases: purchases,
    store: settingsStore,
    clock: fixedClock,
    banners: banners,
  );
  @override
  late final ConsentProvider consent = ConsentProvider(
    consent: fakeConsent,
    ads: FakeAds(),
    entitlement: entitlement,
    clock: fixedClock,
  );
  @override
  late final ThemeProvider theme = ThemeProvider(sync);
  @override
  late final LocaleProvider locale = LocaleProvider(sync);
  @override
  late final SettingsProvider settings = SettingsProvider(
    sync: sync,
    posts: postRepo,
    profiles: profileRepo,
    records: recordRepo,
    files: files,
    notifications: notifications,
    banners: banners,
  );
  @override
  late final RemindersProvider reminders = RemindersProvider(
    notifications: notifications,
    posts: postRepo,
    profiles: profiles,
    settings: sync,
    clock: fixedClock,
    texts: (int platformCount) => NotificationTexts(
      title: 'Time to post',
      channelName: 'Reminders',
      bodyFor: (int count) => '$count posts',
    ),
  );
  @override
  late final ImportProvider importer = ImportProvider(
    picker: fakeImport,
    posts: postRepo,
    importer: CsvImporter(),
    banners: banners,
  );

  @override
  Clock get clock => fixedClock;
  @override
  LinkPort get links => fakeLinks;
  @override
  PzBannerBuilder get bannerBuilder =>
      (BuildContext c, BannerHandle b) => const SizedBox.expand();
  @override
  String get appVersion => '1.0.0 (1)';

  /// Builds the services, loads the default profiles and saves [saved] posts.
  static Future<TestServices> create({
    List<Post> saved = const <Post>[],
  }) async {
    final TestServices s = TestServices._();
    await s.sync.load();
    await s.profiles.load();
    for (final Post p in saved) {
      await s.postRepo.upsert(p);
    }
    await s.posts.load();
    return s;
  }

  /// A scheduled post, by default later today.
  static Post scheduled(
    String id, {
    String hook = 'Launch day',
    DateTime? at,
    String body = 'Body text',
  }) => testPost(hook: hook, body: body, cta: 'Go').copyWith(
    id: id,
    status: PostStatus.scheduled,
    scheduledAt: (at ?? DateTime(2026, 10, 18, 18)).toUtc(),
  );

  void dispose() {
    banners.dispose();
    undo.dispose();
    composer.dispose();
  }
}
