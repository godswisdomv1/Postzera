import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:postzera/core/models/app_error.dart';
import 'package:postzera/core/ports/ads_port.dart';
import 'package:postzera/core/ports/clock.dart';
import 'package:postzera/core/ports/consent_port.dart';
import 'package:postzera/core/ports/file_import_port.dart';
import 'package:postzera/core/ports/file_store_port.dart';
import 'package:postzera/core/ports/media_picker_port.dart';
import 'package:postzera/core/ports/media_renderer_port.dart';
import 'package:postzera/core/ports/notification_port.dart';
import 'package:postzera/core/ports/post_repository.dart';
import 'package:postzera/core/ports/profile_repository.dart';
import 'package:postzera/core/ports/purchase_port.dart';
import 'package:postzera/core/ports/send_record_repository.dart';
import 'package:postzera/core/ports/settings_store.dart';
import 'package:postzera/core/ports/share_port.dart';
import 'package:postzera/core/ports/video_composer_port.dart';
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
import 'package:postzera/l10n/app_localizations.dart';
import 'package:postzera/screens/screen_services.dart';
import 'package:postzera/utils/log.dart';
import 'package:postzera/widgets/pz_ad_slot.dart';

/// What the database open told the app, for the notices it must show.
@immutable
class StartupNotices {
  const StartupNotices({
    this.databaseRecovered = false,
    this.databaseUnavailable = false,
  });

  /// A damaged database was set aside and a fresh one started.
  final bool databaseRecovered;

  /// SQLite could not be used, so posts are kept in memory only.
  final bool databaseUnavailable;
}

/// Every port the app needs, as one bundle. `bootstrap.dart` fills it with
/// the real adapters; tests fill it with fakes.
class Adapters {
  const Adapters({
    required this.postRepo,
    required this.recordRepo,
    required this.profileRepo,
    required this.settingsStore,
    required this.files,
    required this.renderer,
    required this.video,
    required this.picker,
    required this.share,
    required this.clipboard,
    required this.links,
    required this.notifications,
    required this.purchases,
    required this.consent,
    required this.ads,
    required this.fileImport,
    required this.bannerBuilder,
    required this.appVersion,
    this.clock = const SystemClock(),
    this.notices = const StartupNotices(),
  });

  final PostRepository postRepo;
  final SendRecordRepository recordRepo;
  final ProfileRepository profileRepo;
  final SettingsStore settingsStore;
  final FileStorePort files;
  final MediaRendererPort renderer;
  final VideoComposerPort video;
  final MediaPickerPort picker;
  final SharePort share;
  final ClipboardPort clipboard;
  final LinkPort links;
  final NotificationPort notifications;
  final PurchasePort purchases;
  final ConsentPort consent;
  final AdsPort ads;
  final FileImportPort fileImport;
  final PzBannerBuilder bannerBuilder;
  final String appVersion;
  final Clock clock;
  final StartupNotices notices;
}

/// The reminder notification texts in the language of [l10n].
NotificationTexts Function(int platformCount) notificationTextsFor(
  AppLocalizations l10n,
) {
  return (int platformCount) => NotificationTexts(
    title: l10n.reminder_title,
    channelName: l10n.reminder_channelName,
    bodyFor: (int postCount) => l10n.reminder_body(
      l10n.reminder_postsCount(postCount),
      l10n.reminder_platformsCount(platformCount),
    ),
  );
}

/// Holds every adapter and provider, built once at startup. Screens see it
/// through [ScreenServices] and never learn which adapter is behind a port.
class AppServices implements ScreenServices {
  AppServices._({
    required this.files,
    required this.notices,
    required this.sync,
    required this.banners,
    required this.undo,
    required this.profiles,
    required this.media,
    required this.reminders,
    required this.posts,
    required this.queue,
    required this.composer,
    required this.entitlement,
    required this.consent,
    required this.theme,
    required this.locale,
    required this.settings,
    required this.importer,
    required this.clock,
    required this.links,
    required this.bannerBuilder,
    required this.appVersion,
  });

  /// Builds every provider from the ports in [a]. Anything that changes the
  /// posts or the reminder settings asks the reminders to replan.
  factory AppServices.create(Adapters a) {
    final SettingsSync sync = SettingsSync(a.settingsStore);
    final BannerProvider banners = BannerProvider();
    final UndoProvider undo = UndoProvider();
    final ProfilesProvider profiles = ProfilesProvider(
      profiles: a.profileRepo,
      banners: banners,
    );
    final MediaJobsProvider media = MediaJobsProvider(
      pipeline: MediaPipeline(
        files: a.files,
        renderer: a.renderer,
        video: a.video,
      ),
    );
    final RemindersProvider reminders = RemindersProvider(
      notifications: a.notifications,
      posts: a.postRepo,
      profiles: profiles,
      settings: sync,
      clock: a.clock,
      texts: notificationTextsFor(
        lookupAppLocalizations(const Locale('en')),
      ),
    );
    void replan() => unawaited(reminders.sync());
    final PostsProvider posts = PostsProvider(
      posts: a.postRepo,
      records: a.recordRepo,
      files: a.files,
      share: a.share,
      clock: a.clock,
      undo: undo,
      banners: banners,
      onChanged: replan,
    );
    final QueueProvider queue = QueueProvider(
      posts: a.postRepo,
      records: a.recordRepo,
      profiles: profiles,
      jobs: media,
      files: a.files,
      clipboard: a.clipboard,
      share: a.share,
      clock: a.clock,
      undo: undo,
      banners: banners,
      onChanged: replan,
    );
    final ComposerProvider composer = ComposerProvider(
      posts: posts,
      profiles: profiles,
      settings: sync,
      picker: a.picker,
      files: a.files,
      clock: a.clock,
      banners: banners,
    );
    final EntitlementProvider entitlement = EntitlementProvider(
      purchases: a.purchases,
      store: a.settingsStore,
      clock: a.clock,
      banners: banners,
    );
    final ConsentProvider consent = ConsentProvider(
      consent: a.consent,
      ads: a.ads,
      entitlement: entitlement,
      clock: a.clock,
    );
    return AppServices._(
      files: a.files,
      notices: a.notices,
      sync: sync,
      banners: banners,
      undo: undo,
      profiles: profiles,
      media: media,
      reminders: reminders,
      posts: posts,
      queue: queue,
      composer: composer,
      entitlement: entitlement,
      consent: consent,
      theme: ThemeProvider(sync),
      locale: LocaleProvider(sync),
      settings: SettingsProvider(
        sync: sync,
        posts: a.postRepo,
        profiles: a.profileRepo,
        records: a.recordRepo,
        files: a.files,
        notifications: a.notifications,
        banners: banners,
        onChanged: replan,
      ),
      importer: ImportProvider(
        picker: a.fileImport,
        posts: a.postRepo,
        importer: CsvImporter(),
        banners: banners,
        onChanged: replan,
      ),
      clock: a.clock,
      links: a.links,
      bannerBuilder: a.bannerBuilder,
      appVersion: a.appVersion,
    );
  }

  /// Used by the startup steps that clear old generated files.
  final FileStorePort files;
  final StartupNotices notices;
  final SettingsSync sync;

  @override
  final BannerProvider banners;
  @override
  final UndoProvider undo;
  @override
  final ProfilesProvider profiles;
  @override
  final MediaJobsProvider media;
  @override
  final RemindersProvider reminders;
  @override
  final PostsProvider posts;
  @override
  final QueueProvider queue;
  @override
  final ComposerProvider composer;
  @override
  final EntitlementProvider entitlement;
  @override
  final ConsentProvider consent;
  @override
  final ThemeProvider theme;
  @override
  final LocaleProvider locale;
  @override
  final SettingsProvider settings;
  @override
  final ImportProvider importer;
  @override
  final Clock clock;
  @override
  final LinkPort links;
  @override
  final PzBannerBuilder bannerBuilder;
  @override
  final String appVersion;

  /// Reads everything the first frame needs, all from the phone: settings,
  /// platforms, the cached purchase answer, posts and the queue. Nothing here
  /// waits on a network service. A step that fails is logged and the app
  /// starts with that provider's defaults.
  Future<void> loadInitial() async {
    await _safe('settings', settings.load);
    await _safe('profiles', profiles.load);
    await _safe('entitlement', entitlement.init);
    await _safe('posts', posts.load);
    await _safe('queue', queue.load);
    if (notices.databaseUnavailable) {
      banners.addSticky(
        BannerItem.failure(AppError.of(AppErrorKind.dbUnavailable)),
      );
    }
  }

  static Future<void> _safe(String name, Future<void> Function() step) async {
    try {
      await step();
    } catch (error) {
      Log.w('startup', '$name failed: ${error.runtimeType}');
    }
  }

  void dispose() {
    importer.dispose();
    settings.dispose();
    locale.dispose();
    theme.dispose();
    consent.dispose();
    entitlement.dispose();
    composer.dispose();
    queue.dispose();
    posts.dispose();
    reminders.dispose();
    media.dispose();
    profiles.dispose();
    undo.dispose();
    banners.dispose();
    sync.dispose();
  }
}
