import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postzera/app_services.dart';
import 'package:postzera/core/models/app_error.dart';
import 'package:postzera/core/ports/ads_port.dart';
import 'package:postzera/core/ports/notification_port.dart';
import 'package:postzera/core/ports/purchase_port.dart';
import 'package:postzera/l10n/app_localizations.dart';
import 'package:postzera/platform/storage/sqlite_post_repository.dart';
import 'package:postzera/platform/storage/sqlite_profile_repository.dart';
import 'package:postzera/platform/storage/sqlite_send_record_repository.dart';

import '../core/fakes.dart';
import '../core/test_helpers.dart';
import '../screens/test_services.dart';

/// Every port as a fake, so the real wiring of [AppServices] can be tested.
class Harness {
  Harness({StartupNotices notices = const StartupNotices()}) {
    adapters = Adapters(
      postRepo: InMemoryPostRepository(),
      recordRepo: InMemorySendRecordRepository(),
      profileRepo: InMemoryProfileRepository(),
      settingsStore: settingsStore,
      files: files,
      renderer: FakeRenderer(files),
      video: FakeVideo(files),
      picker: FakePicker(),
      share: FakeShare(),
      clipboard: FakeClipboard(),
      links: FakeLinks(),
      notifications: notifications,
      purchases: purchases,
      consent: consent,
      ads: FakeAds(),
      fileImport: FakeImport(),
      bannerBuilder: (BuildContext c, BannerHandle b) => const SizedBox(),
      appVersion: '1.0.0 (1)',
      clock: FixedClock(TestServices.now),
      notices: notices,
    );
    services = AppServices.create(adapters);
  }

  final FakeFileStore files = FakeFileStore();
  final FakeSettingsStore settingsStore = FakeSettingsStore();
  final FakeNotifications notifications = FakeNotifications();
  final FakePurchases purchases = FakePurchases();
  final FakeConsent consent = FakeConsent();
  late final Adapters adapters;
  late final AppServices services;
}

void main() {
  test('loadInitial reads the nine platforms and settings', () async {
    final Harness h = Harness();
    addTearDown(h.services.dispose);
    await h.services.loadInitial();
    expect(h.services.profiles.value.profiles, hasLength(9));
    expect(h.services.settings.value.loaded, isTrue);
    expect(h.services.appVersion, '1.0.0 (1)');
  });

  test('loadInitial subscribes to store events', () async {
    final Harness h = Harness();
    addTearDown(h.services.dispose);
    await h.services.loadInitial();
    h.purchases.controller.add(const PurchaseCompleted());
    await pumpEventQueue();
    expect(h.services.entitlement.value.entitlement.state.name, 'pro');
  });

  test('saving a scheduled post replans the reminders', () async {
    final Harness h = Harness();
    addTearDown(h.services.dispose);
    await h.services.loadInitial();
    expect(h.notifications.replaced, isEmpty);
    await h.services.posts.save(TestServices.scheduled('a'));
    await pumpEventQueue();
    expect(h.notifications.replaced, isNotEmpty);
    expect(h.notifications.replaced.last, hasLength(1));
  });

  test('an unusable database leaves a permanent warning', () async {
    final Harness h = Harness(
      notices: const StartupNotices(databaseUnavailable: true),
    );
    addTearDown(h.services.dispose);
    await h.services.loadInitial();
    expect(
      h.services.banners.value.sticky.map((i) => i.error?.kind),
      contains(AppErrorKind.dbUnavailable),
    );
  });

  test('a healthy database leaves no warning', () async {
    final Harness h = Harness();
    addTearDown(h.services.dispose);
    await h.services.loadInitial();
    expect(h.services.banners.value.sticky, isEmpty);
  });

  test('reminder texts are localized and pluralized', () {
    final AppLocalizations en = lookupAppLocalizations(const Locale('en'));
    final NotificationTexts t = notificationTextsFor(en)(9);
    expect(t.title, 'Time to post');
    expect(t.bodyFor(3), '3 posts ready for 9 platforms');
    expect(t.bodyFor(1), '1 post ready for 9 platforms');
    expect(notificationTextsFor(en)(1).bodyFor(2), '2 posts ready for 1 platform');
  });
}
