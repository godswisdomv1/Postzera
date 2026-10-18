/// Schema version written into every persisted model's JSON.
const int modelSchemaVersion = 1;

/// Tolerant JSON readers. A missing or wrongly typed value gives the fallback
/// instead of throwing, so an older or newer file never crashes the app.
String readString(Object? raw, [String fallback = '']) =>
    raw is String ? raw : fallback;

String? readStringOrNull(Object? raw) => raw is String ? raw : null;

int readInt(Object? raw, [int fallback = 0]) =>
    raw is num ? raw.toInt() : fallback;

int? readIntOrNull(Object? raw) => raw is num ? raw.toInt() : null;

bool readBool(Object? raw, [bool fallback = false]) =>
    raw is bool ? raw : fallback;

T readEnum<T extends Enum>(List<T> values, Object? raw, T fallback) {
  if (raw is String) {
    for (final T value in values) {
      if (value.name == raw) {
        return value;
      }
    }
  }
  return fallback;
}

List<String> readStringList(Object? raw) {
  if (raw is List<dynamic>) {
    return <String>[
      for (final Object? item in raw)
        if (item is String) item,
    ];
  }
  return const <String>[];
}

Map<String, Object?> readMap(Object? raw) {
  if (raw is Map<dynamic, dynamic>) {
    return <String, Object?>{
      for (final MapEntry<dynamic, dynamic> e in raw.entries)
        e.key.toString(): e.value as Object?,
    };
  }
  return const <String, Object?>{};
}

List<Map<String, Object?>> readMapList(Object? raw) {
  if (raw is List<dynamic>) {
    return <Map<String, Object?>>[
      for (final Object? item in raw)
        if (item is Map<dynamic, dynamic>) readMap(item),
    ];
  }
  return const <Map<String, Object?>>[];
}

DateTime? readDateOrNull(Object? raw) => raw is num
    ? DateTime.fromMillisecondsSinceEpoch(raw.toInt(), isUtc: true)
    : null;
