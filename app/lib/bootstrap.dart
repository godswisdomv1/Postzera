import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart' show AdWidget;
import 'package:intl/date_symbol_data_local.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:postzera/app.dart';
import 'package:postzera/app_services.dart';
import 'package:postzera/core/data/app_links.dart';
import 'package:postzera/core/models/app_error.dart';
import 'package:postzera/core/ports/ads_port.dart';
import 'package:postzera/core/ports/post_repository.dart';
import 'package:postzera/core/ports/profile_repository.dart';
import 'package:postzera/core/ports/send_record_repository.dart';
import 'package:postzera/core/providers/banner_provider.dart';
import 'package:postzera/platform/ads/ads_service.dart';
import 'package:postzera/platform/ads/consent_service.dart';
import 'package:postzera/platform/import/file_import_service.dart';
import 'package:postzera/platform/media/card_renderer.dart';
import 'package:postzera/platform/media/media_picker_service.dart';
import 'package:postzera/platform/media/video_composer.dart';
import 'package:postzera/platform/notifications/notification_service.dart';
import 'package:postzera/platform/purchases/purchase_service.dart';
import 'package:postzera/platform/share/clipboard_service.dart';
import 'package:postzera/platform/share/link_launcher.dart';
import 'package:postzera/platform/share/share_service.dart';
import 'package:postzera/platform/storage/file_store.dart';
import 'package:postzera/platform/storage/prefs_settings_store.dart';
import 'package:postzera/platform/storage/sqlite_database.dart';
import 'package:postzera/platform/storage/sqlite_post_repository.dart';
import 'package:postzera/platform/storage/sqlite_profile_repository.dart';
import 'package:postzera/platform/storage/sqlite_send_record_repository.dart';
import 'package:postzera/utils/global_error_handler.dart';
import 'package:postzera/utils/license_registration.dart';
import 'package:postzera/utils/log.dart';
import 'package:sqlite3/sqlite3.dart' show Database;

/// Generated media older than this is deleted at every launch.
const Duration outputMaxAge = Duration(days: 14);

/// Starts the app. The order keeps the first frame free of anything that
/// needs the network: the error hooks, the licences and the locale data, then
/// the database, settings and platforms (all on the phone), then the first
/// frame. Consent, the store, reminders and the file sweep come afterwards.
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  installGlobalErrorHandlers(
    errorWidgetBuilder: (FlutterErrorDetails details) => FatalErrorView(
      error: AppError.of(
        AppErrorKind.unexpected,
        details: details.exception.runtimeType.toString(),
      ),
      onRetry: restartAppView,
      onSupport: () => unawaited(_openSupportPage()),
    ),
  );
  registerFontLicenses();

  final AppServices services;
  try {
    await initializeDateFormatting();
    services = AppServices.create(await openAdapters());
    await services.loadInitial();
  } catch (error) {
    Log.e('startup', 'cannot start: ${error.runtimeType}');
    runApp(
      FatalApp(
        error: error is AppError
            ? error
            : AppError.of(
                AppErrorKind.unexpected,
                details: error.runtimeType.toString(),
              ),
        onSupport: () => unawaited(_openSupportPage()),
      ),
    );
    return;
  }
  runApp(PostzeraApp(services: services));
  WidgetsBinding.instance.addPostFrameCallback(
    (Duration _) => unawaited(startDeferred(services)),
  );
}

Future<bool> _openSupportPage() =>
    const LinkLauncher().open(Uri.parse(AppLinks.supportUrl));

/// Opens the real database, files and plugins. A database that is damaged is
/// set aside and replaced. A database that cannot be used at all becomes
/// in-memory storage with a permanent warning. A database newer than this app
/// throws `dbDowngrade`, which ends in the fatal view.
Future<Adapters> openAdapters() async {
  final Directory root = await getApplicationSupportDirectory();
  final DatabaseOpenResult opened = SqliteDatabase.openFile(
    p.join(root.path, SqliteDatabase.fileName),
  );
  final Database? db = opened.database;
  final PostRepository posts = db == null
      ? InMemoryPostRepository()
      : SqlitePostRepository(db);
  final ProfileRepository profiles = db == null
      ? InMemoryProfileRepository()
      : SqliteProfileRepository(db);
  final SendRecordRepository records = db == null
      ? InMemorySendRecordRepository()
      : SqliteSendRecordRepository(db);
  final PrefsSettingsStore settings = await PrefsSettingsStore.open();

  String version = '';
  try {
    final PackageInfo info = await PackageInfo.fromPlatform();
    version = '${info.version} (${info.buildNumber})';
  } catch (error) {
    Log.w('startup', 'version unreadable: ${error.runtimeType}');
  }

  return Adapters(
    postRepo: posts,
    recordRepo: records,
    profileRepo: profiles,
    settingsStore: settings,
    files: FileStore(root),
    renderer: CardRenderer(),
    video: VideoComposer(),
    picker: MediaPickerService(),
    share: ShareService(),
    clipboard: const ClipboardService(),
    links: const LinkLauncher(),
    notifications: NotificationService(),
    purchases: PurchaseService(),
    consent: ConsentService(),
    ads: AdsService(),
    fileImport: const FileImportService(),
    bannerBuilder: (BuildContext context, BannerHandle banner) =>
        banner is BannerAdHandle
        ? AdWidget(ad: banner.ad)
        : const SizedBox.shrink(),
    appVersion: version,
    notices: StartupNotices(
      databaseRecovered: opened.recoveredFromCorruption,
      databaseUnavailable: db == null,
    ),
  );
}

/// What runs after the first frame. The steps start in the blueprint's order
/// (consent, store, reminders, file sweep) but do not wait for each other:
/// the consent form stays on screen until the person answers it, and that
/// must not delay reminders or a purchase restore. Ads are still requested
/// only after consent allows them, because the consent provider guards that.
/// A step that fails is logged and the others still run.
Future<void> startDeferred(AppServices s) async {
  if (s.notices.databaseRecovered) {
    s.banners.show(BannerItem.failure(AppError.of(AppErrorKind.dbCorrupt)));
  }
  await Future.wait(<Future<void>>[
    _guard('consent', s.consent.refresh),
    _guard('store', s.entitlement.connect),
    _guard('reminders', () async {
      await s.reminders.init();
      await s.reminders.sync();
    }),
    _guard('sweep', () async {
      await s.files.sweepOutputs(olderThan: outputMaxAge);
    }),
  ]);
}

Future<void> _guard(String name, Future<void> Function() step) async {
  try {
    await step();
  } catch (error) {
    Log.w('startup', '$name failed: ${error.runtimeType}');
  }
}
