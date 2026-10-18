import 'package:postzera/core/models/platform_profile.dart';

/// Storage of platform profiles, in display order.
abstract class ProfileRepository {
  Future<List<PlatformProfile>> all();

  Future<void> upsert(PlatformProfile profile);

  /// Deletes a custom profile. Built-in profiles are never deleted.
  Future<void> delete(String id);

  /// Stores the new display order: [orderedIds] lists every profile id.
  Future<void> reorder(List<String> orderedIds);

  /// Puts a built-in profile back to its default template and limits,
  /// keeping its enabled flag and position.
  Future<void> resetToDefault(String id);

  /// Fills the nine built-in profiles on first run. Does nothing when
  /// profiles already exist.
  Future<void> ensureDefaults();
}
