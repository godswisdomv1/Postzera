import 'package:flutter_test/flutter_test.dart';
import 'package:postzera/core/models/app_error.dart';
import 'package:postzera/core/models/app_settings.dart';
import 'package:postzera/core/models/post.dart';
import 'package:postzera/core/models/send_record.dart';
import 'package:postzera/core/providers/banner_provider.dart';
import 'package:postzera/core/providers/locale_provider.dart';
import 'package:postzera/core/providers/settings_provider.dart';
import 'package:postzera/core/providers/settings_sync.dart';
import 'package:postzera/core/providers/theme_provider.dart';
import 'package:postzera/core/providers/undo_provider.dart';
import 'package:postzera/platform/storage/sqlite_post_repository.dart';
import 'package:postzera/platform/storage/sqlite_profile_repository.dart';
import 'package:postzera/platform/storage/sqlite_send_record_repository.dart';

import 'fakes.dart';
import 'test_helpers.dart';

Future<void> wait([int ms = 40]) =>
    Future<void>.delayed(Duration(milliseconds: ms));

void main() {
  group('BannerProvider', () {
    test('a banner disappears by itself', () async {
      final BannerProvider b = BannerProvider(
        autoDismiss: const Duration(milliseconds: 20),
      );
      b.success(BannerMessage.postSaved);
      expect(b.value.transient?.message, BannerMessage.postSaved);
      await wait();
      expect(b.value.transient, isNull);
    });

    test('a new banner replaces the old one and restarts the timer', () async {
      final BannerProvider b = BannerProvider(
        autoDismiss: const Duration(milliseconds: 60),
      );
      b.success(BannerMessage.postSaved);
      await wait(40);
      b.failure(AppError.of(AppErrorKind.shareFailed));
      await wait(40);
      expect(b.value.transient?.error?.kind, AppErrorKind.shareFailed);
      await wait(60);
      expect(b.value.transient, isNull);
    });

    test('sticky banners stay until removed and are not duplicated', () {
      final BannerProvider b = BannerProvider();
      const BannerItem item = BannerItem(
        id: 'db',
        kind: BannerKind.warning,
        message: BannerMessage.storageFallback,
      );
      b.addSticky(item);
      b.addSticky(item);
      expect(b.value.sticky.length, 1);
      b.success(BannerMessage.postSaved);
      b.dismiss();
      expect(b.value.sticky.length, 1);
      b.removeSticky('db');
      expect(b.value.sticky, isEmpty);
    });
  });

  group('UndoProvider', () {
    test('undo runs revert and not onExpire', () async {
      final UndoProvider u = UndoProvider(window: const Duration(seconds: 5));
      bool reverted = false;
      bool expired = false;
      await u.register(
        UndoAction(
          label: UndoLabel.postDeleted,
          revert: () async => reverted = true,
          onExpire: () async => expired = true,
        ),
      );
      expect(u.value?.label, UndoLabel.postDeleted);
      await u.undo();
      expect(reverted, isTrue);
      expect(expired, isFalse);
      expect(u.value, isNull);
      u.dispose();
    });

    test('the action becomes final after the window', () async {
      final UndoProvider u = UndoProvider(window: const Duration(milliseconds: 20));
      bool expired = false;
      await u.register(
        UndoAction(
          label: UndoLabel.postDeleted,
          revert: () async {},
          onExpire: () async => expired = true,
        ),
      );
      await wait();
      expect(expired, isTrue);
      expect(u.value, isNull);
    });

    test('a newer action makes the older one final', () async {
      final UndoProvider u = UndoProvider();
      final List<String> log = <String>[];
      await u.register(
        UndoAction(
          label: UndoLabel.postDeleted,
          revert: () async {},
          onExpire: () async => log.add('first final'),
        ),
      );
      await u.register(
        UndoAction(label: UndoLabel.markedPosted, revert: () async {}),
      );
      expect(log, <String>['first final']);
      expect(u.value?.label, UndoLabel.markedPosted);
      u.dispose();
    });

    test('undo with nothing to undo does nothing', () async {
      final UndoProvider u = UndoProvider();
      await u.undo();
      expect(u.value, isNull);
    });
  });

  group('SettingsSync, theme and locale', () {
    test('two quick changes from different providers both survive', () async {
      final FakeSettingsStore store = FakeSettingsStore();
      final SettingsSync sync = SettingsSync(store);
      await sync.load();
      final ThemeProvider theme = ThemeProvider(sync);
      final LocaleProvider locale = LocaleProvider(sync);
      final Future<void> a = theme.setMode(ThemeModeSetting.dark);
      final Future<void> b = locale.setLocale('ar');
      await Future.wait(<Future<void>>[a, b]);
      expect(store.settings.themeMode, ThemeModeSetting.dark);
      expect(store.settings.localeCode, 'ar');
      expect(theme.value, ThemeModeSetting.dark);
      expect(locale.value, 'ar');
    });

    test('the theme follows the system unless chosen', () {
      final SettingsSync sync = SettingsSync(FakeSettingsStore());
      final ThemeProvider theme = ThemeProvider(sync);
      expect(theme.isDark(systemIsDark: true), isTrue);
      expect(theme.isDark(systemIsDark: false), isFalse);
      theme.value = ThemeModeSetting.light;
      expect(theme.isDark(systemIsDark: true), isFalse);
      theme.value = ThemeModeSetting.dark;
      expect(theme.isDark(systemIsDark: false), isTrue);
    });

    test('the language can be cleared back to the system', () async {
      final FakeSettingsStore store = FakeSettingsStore();
      final SettingsSync sync = SettingsSync(store);
      final LocaleProvider locale = LocaleProvider(sync);
      await locale.setLocale('ja');
      expect(locale.value, 'ja');
      await locale.setLocale(null);
      expect(locale.value, isNull);
      expect(store.settings.localeCode, isNull);
    });

    test('an unsupported language is ignored', () async {
      final SettingsSync sync = SettingsSync(FakeSettingsStore());
      final LocaleProvider locale = LocaleProvider(sync);
      await locale.setLocale('xx');
      expect(locale.value, isNull);
    });

    test('there are 11 languages and two are right to left', () {
      expect(LocaleProvider.supported.length, 11);
      expect(
        LocaleProvider.supported
            .where((SupportedLocale l) => l.rtl)
            .map((SupportedLocale l) => l.code)
            .toSet(),
        <String>{'ar', 'he'},
      );
      expect(LocaleProvider.isRtl('he'), isTrue);
      expect(LocaleProvider.isRtl('en'), isFalse);
    });

    test('a failed save keeps the value in memory and raises dbUnavailable', () async {
      final FakeSettingsStore store = FakeSettingsStore()..failSave = true;
      final SettingsSync sync = SettingsSync(store);
      await expectLater(
        sync.update((AppSettings s) => s.copyWith(onboardingDone: true)),
        throwsA(isA<AppError>()),
      );
      expect(sync.current.onboardingDone, isTrue);
    });
  });

  group('SettingsProvider', () {
    late FakeSettingsStore store;
    late SettingsSync sync;
    late InMemoryPostRepository posts;
    late InMemoryProfileRepository profiles;
    late InMemorySendRecordRepository records;
    late FakeFileStore files;
    late FakeNotifications notifications;
    late BannerProvider banners;
    late int changes;
    late SettingsProvider provider;

    setUp(() {
      store = FakeSettingsStore();
      sync = SettingsSync(store);
      posts = InMemoryPostRepository();
      profiles = InMemoryProfileRepository();
      records = InMemorySendRecordRepository();
      files = FakeFileStore();
      notifications = FakeNotifications();
      banners = BannerProvider();
      changes = 0;
      provider = SettingsProvider(
        sync: sync,
        posts: posts,
        profiles: profiles,
        records: records,
        files: files,
        notifications: notifications,
        banners: banners,
        onChanged: () => changes++,
      );
    });

    test('reminder changes are saved and trigger a reminder sync', () async {
      await provider.setRemindersEnabled(enabled: false);
      await provider.setReminderMinutes(2000);
      expect(store.settings.remindersEnabled, isFalse);
      expect(store.settings.reminderMinutes, 1439);
      expect(changes, 2);
    });

    test('onboarding and the default card theme are saved', () async {
      await provider.completeOnboarding();
      await provider.setDefaultCardTheme('ink');
      expect(store.settings.onboardingDone, isTrue);
      expect(store.settings.defaultCardThemeId, 'ink');
      expect(provider.value.settings.defaultCardThemeId, 'ink');
      expect(changes, 0);
    });

    test('a failed save shows a failure banner', () async {
      store.failSave = true;
      await provider.completeOnboarding();
      expect(banners.value.transient?.error?.kind, AppErrorKind.dbUnavailable);
    });

    test('delete all data wipes everything and returns to first run', () async {
      await profiles.ensureDefaults();
      await posts.upsert(testPost().copyWith(id: 'a'));
      await records.upsert(
        const SendRecord(postId: 'a', platformId: 'x', status: SendStatus.done),
      );
      await provider.completeOnboarding();
      store.cache = null;
      await provider.deleteAllData();
      expect(await posts.all(), isEmpty);
      expect(await records.forPost('a'), isEmpty);
      expect((await profiles.all()).length, 9);
      expect(files.deletedAll, isTrue);
      expect(notifications.cancels, 1);
      expect(store.clears, 1);
      expect(provider.value.settings.onboardingDone, isFalse);
      expect(provider.value.deleting, isFalse);
      expect(banners.value.transient?.message, BannerMessage.dataDeleted);
      expect(changes, 1);
    });

    test('custom platforms are removed by delete all data', () async {
      await profiles.ensureDefaults();
      final first = (await profiles.all()).first;
      await profiles.upsert(first.copyWith(id: 'custom-1', isCustom: true));
      expect((await profiles.all()).length, 10);
      await provider.deleteAllData();
      expect((await profiles.all()).length, 9);
    });
  });

  test('Post status values used by the providers exist', () {
    expect(PostStatus.values, contains(PostStatus.scheduled));
  });
}
