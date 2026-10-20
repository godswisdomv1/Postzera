import 'dart:convert';

import 'package:postzera/core/models/app_settings.dart';
import 'package:postzera/core/models/entitlement.dart';
import 'package:postzera/core/models/json_read.dart';
import 'package:postzera/core/ports/settings_store.dart';
import 'package:postzera/utils/log.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Settings and the cached purchase flag in `shared_preferences`.
///
/// Settings are one JSON value that carries its schema version. The cached
/// entitlement uses two separate keys, so it can be read without parsing.
class PrefsSettingsStore implements SettingsStore {
  PrefsSettingsStore(this._prefs);

  static Future<PrefsSettingsStore> open() async =>
      PrefsSettingsStore(await SharedPreferences.getInstance());

  final SharedPreferences _prefs;

  static const String settingsKey = 'postzera.settings';
  static const String entitlementStateKey = 'postzera.entitlement.state';
  static const String entitlementTimeKey = 'postzera.entitlement.updatedAt';

  @override
  Future<AppSettings> load() async {
    final String? raw = _prefs.getString(settingsKey);
    if (raw == null) {
      return const AppSettings();
    }
    try {
      return AppSettings.fromJson(readMap(jsonDecode(raw)));
    } on FormatException {
      Log.w('prefs', 'settings were unreadable, using defaults');
      return const AppSettings();
    }
  }

  @override
  Future<void> save(AppSettings settings) async {
    await _prefs.setString(settingsKey, jsonEncode(settings.toJson()));
  }

  @override
  Future<Entitlement?> loadEntitlementCache() async {
    final String? name = _prefs.getString(entitlementStateKey);
    if (name == null) {
      return null;
    }
    final EntitlementState state = readEnum(
      EntitlementState.values,
      name,
      EntitlementState.unknown,
    );
    if (state == EntitlementState.unknown) {
      return null;
    }
    return Entitlement(
      state: state,
      source: EntitlementSource.cache,
      updatedAt: readDateOrNull(_prefs.getInt(entitlementTimeKey)),
    );
  }

  @override
  Future<void> saveEntitlementCache(Entitlement entitlement) async {
    if (entitlement.state == EntitlementState.unknown) {
      await _prefs.remove(entitlementStateKey);
      await _prefs.remove(entitlementTimeKey);
      return;
    }
    await _prefs.setString(entitlementStateKey, entitlement.state.name);
    final DateTime? at = entitlement.updatedAt;
    if (at == null) {
      await _prefs.remove(entitlementTimeKey);
    } else {
      await _prefs.setInt(
        entitlementTimeKey,
        at.toUtc().millisecondsSinceEpoch,
      );
    }
  }

  @override
  Future<void> clearAll() async {
    await _prefs.remove(settingsKey);
    await _prefs.remove(entitlementStateKey);
    await _prefs.remove(entitlementTimeKey);
  }
}
