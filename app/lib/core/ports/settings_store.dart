import 'package:postzera/core/models/app_settings.dart';
import 'package:postzera/core/models/entitlement.dart';

/// Storage of settings and the cached purchase flag.
abstract class SettingsStore {
  /// The saved settings, or the defaults when nothing was saved.
  Future<AppSettings> load();

  Future<void> save(AppSettings settings);

  /// The cached entitlement, or null when none was saved.
  Future<Entitlement?> loadEntitlementCache();

  Future<void> saveEntitlementCache(Entitlement entitlement);

  /// Removes settings and the cached entitlement.
  Future<void> clearAll();
}
