import 'dart:convert';

import 'package:postzera/core/data/default_profiles.dart';
import 'package:postzera/core/models/json_read.dart';
import 'package:postzera/core/models/platform_profile.dart';
import 'package:postzera/core/ports/profile_repository.dart';
import 'package:postzera/platform/storage/sqlite_database.dart';
import 'package:postzera/utils/log.dart';
import 'package:sqlite3/sqlite3.dart';

/// Platform profiles in SQLite. Each profile is a JSON blob; the columns for
/// order and flags are the source of truth for those three values.
class SqliteProfileRepository implements ProfileRepository {
  SqliteProfileRepository(this._db);

  final Database _db;

  @override
  Future<List<PlatformProfile>> all() async {
    final ResultSet rows = _db.select(
      'SELECT id, sort_order, enabled, is_custom, json FROM platform_profiles '
      'ORDER BY sort_order ASC, id ASC',
    );
    final List<PlatformProfile> result = <PlatformProfile>[];
    for (final Row row in rows) {
      final PlatformProfile? profile = _fromRow(row);
      if (profile != null) {
        result.add(profile);
      }
    }
    return result;
  }

  @override
  Future<void> upsert(PlatformProfile profile) async => _upsert(profile);

  @override
  Future<void> delete(String id) async {
    _db.execute(
      'DELETE FROM platform_profiles WHERE id = ? AND is_custom = 1',
      <Object?>[id],
    );
  }

  @override
  Future<void> reorder(List<String> orderedIds) async {
    SqliteDatabase.transaction<void>(_db, () {
      for (int i = 0; i < orderedIds.length; i++) {
        _db.execute(
          'UPDATE platform_profiles SET sort_order = ? WHERE id = ?',
          <Object?>[i, orderedIds[i]],
        );
      }
    });
  }

  @override
  Future<void> resetToDefault(String id) async {
    final Iterable<PlatformProfile> matches =
        defaultProfiles().where((PlatformProfile p) => p.id == id);
    if (matches.isEmpty) {
      return;
    }
    final PlatformProfile fresh = matches.first;
    final ResultSet rows = _db.select(
      'SELECT id, sort_order, enabled, is_custom, json FROM platform_profiles '
      'WHERE id = ?',
      <Object?>[id],
    );
    final PlatformProfile? current = rows.isEmpty ? null : _fromRow(rows.first);
    _upsert(
      current == null
          ? fresh
          : fresh.copyWith(
              enabled: current.enabled,
              sortOrder: current.sortOrder,
            ),
    );
  }

  @override
  Future<void> ensureDefaults() async {
    final int count =
        readInt(_db.select('SELECT COUNT(*) AS n FROM platform_profiles').first['n']);
    if (count > 0) {
      return;
    }
    SqliteDatabase.transaction<void>(_db, () {
      defaultProfiles().forEach(_upsert);
    });
  }

  void _upsert(PlatformProfile profile) {
    _db.execute(
      'INSERT INTO platform_profiles(id, sort_order, enabled, is_custom, json) '
      'VALUES(?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET '
      'sort_order=excluded.sort_order, enabled=excluded.enabled, '
      'is_custom=excluded.is_custom, json=excluded.json',
      <Object?>[
        profile.id,
        profile.sortOrder,
        profile.enabled ? 1 : 0,
        profile.isCustom ? 1 : 0,
        jsonEncode(profile.toJson()),
      ],
    );
  }

  static PlatformProfile? _fromRow(Row row) {
    try {
      final Object? decoded = jsonDecode(readString(row['json']));
      return PlatformProfile.fromJson(readMap(decoded)).copyWith(
        id: readString(row['id']),
        sortOrder: readInt(row['sort_order']),
        enabled: readInt(row['enabled']) != 0,
        isCustom: readInt(row['is_custom']) != 0,
      );
    } on FormatException {
      Log.w('db', 'skipped an unreadable profile row');
      return null;
    }
  }
}

/// The fallback used when SQLite cannot be used.
class InMemoryProfileRepository implements ProfileRepository {
  final Map<String, PlatformProfile> _items = <String, PlatformProfile>{};

  @override
  Future<List<PlatformProfile>> all() async {
    final List<PlatformProfile> list = _items.values.toList()
      ..sort((PlatformProfile a, PlatformProfile b) {
        final int byOrder = a.sortOrder.compareTo(b.sortOrder);
        return byOrder != 0 ? byOrder : a.id.compareTo(b.id);
      });
    return list;
  }

  @override
  Future<void> upsert(PlatformProfile profile) async {
    _items[profile.id] = profile;
  }

  @override
  Future<void> delete(String id) async {
    if (_items[id]?.isCustom ?? false) {
      _items.remove(id);
    }
  }

  @override
  Future<void> reorder(List<String> orderedIds) async {
    for (int i = 0; i < orderedIds.length; i++) {
      final PlatformProfile? p = _items[orderedIds[i]];
      if (p != null) {
        _items[p.id] = p.copyWith(sortOrder: i);
      }
    }
  }

  @override
  Future<void> resetToDefault(String id) async {
    final Iterable<PlatformProfile> matches =
        defaultProfiles().where((PlatformProfile p) => p.id == id);
    if (matches.isEmpty) {
      return;
    }
    final PlatformProfile? current = _items[id];
    _items[id] = current == null
        ? matches.first
        : matches.first.copyWith(
            enabled: current.enabled,
            sortOrder: current.sortOrder,
          );
  }

  @override
  Future<void> ensureDefaults() async {
    if (_items.isNotEmpty) {
      return;
    }
    for (final PlatformProfile p in defaultProfiles()) {
      _items[p.id] = p;
    }
  }
}
