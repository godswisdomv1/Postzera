import 'package:flutter_test/flutter_test.dart';
import 'package:postzera/core/models/app_settings.dart';
import 'package:postzera/core/models/entitlement.dart';
import 'package:postzera/platform/storage/prefs_settings_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<PrefsSettingsStore> store([Map<String, Object> initial = const <String, Object>{}]) async {
    SharedPreferences.setMockInitialValues(initial);
    return PrefsSettingsStore(await SharedPreferences.getInstance());
  }

  test('with nothing saved, the defaults are returned', () async {
    final PrefsSettingsStore s = await store();
    expect(await s.load(), const AppSettings());
  });

  test('settings round-trip', () async {
    final PrefsSettingsStore s = await store();
    const AppSettings custom = AppSettings(
      themeMode: ThemeModeSetting.dark,
      localeCode: 'ja',
      defaultCardThemeId: 'ink',
      remindersEnabled: false,
      reminderMinutes: 1080,
      onboardingDone: true,
    );
    await s.save(custom);
    expect(await s.load(), custom);
  });

  test('damaged settings fall back to the defaults', () async {
    final PrefsSettingsStore s = await store(<String, Object>{
      PrefsSettingsStore.settingsKey: '{not json',
    });
    expect(await s.load(), const AppSettings());
  });

  test('settings from a newer version load, ignoring unknown fields', () async {
    final PrefsSettingsStore s = await store(<String, Object>{
      PrefsSettingsStore.settingsKey:
          '{"schemaVersion":9,"themeMode":"dark","newThing":true}',
    });
    expect((await s.load()).themeMode, ThemeModeSetting.dark);
  });

  test('the entitlement cache round-trips as a cached value', () async {
    final PrefsSettingsStore s = await store();
    expect(await s.loadEntitlementCache(), isNull);
    await s.saveEntitlementCache(
      Entitlement(
        state: EntitlementState.pro,
        source: EntitlementSource.store,
        updatedAt: DateTime.utc(2026, 10, 18),
      ),
    );
    final Entitlement? cached = await s.loadEntitlementCache();
    expect(cached!.state, EntitlementState.pro);
    expect(cached.source, EntitlementSource.cache);
    expect(cached.updatedAt, DateTime.utc(2026, 10, 18));
  });

  test('saving an unknown entitlement clears the cache', () async {
    final PrefsSettingsStore s = await store();
    await s.saveEntitlementCache(
      const Entitlement(
        state: EntitlementState.free,
        source: EntitlementSource.store,
      ),
    );
    await s.saveEntitlementCache(const Entitlement.unknown());
    expect(await s.loadEntitlementCache(), isNull);
  });

  test('clearAll removes settings and the entitlement cache', () async {
    final PrefsSettingsStore s = await store();
    await s.save(const AppSettings(onboardingDone: true));
    await s.saveEntitlementCache(
      const Entitlement(
        state: EntitlementState.pro,
        source: EntitlementSource.store,
      ),
    );
    await s.clearAll();
    expect(await s.load(), const AppSettings());
    expect(await s.loadEntitlementCache(), isNull);
  });
}
