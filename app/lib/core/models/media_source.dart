import 'package:flutter/foundation.dart';
import 'package:postzera/core/models/json_read.dart';

enum MediaSourceKind { auto, photo, video }

/// Where a post's media comes from. [path] is the app-owned copy and is null
/// for an auto card. [durationMs] is set for videos only.
@immutable
class MediaSource {
  const MediaSource({required this.kind, this.path, this.durationMs});

  const MediaSource.auto()
    : kind = MediaSourceKind.auto,
      path = null,
      durationMs = null;

  factory MediaSource.fromJson(Map<String, Object?> json) => MediaSource(
    kind: readEnum(MediaSourceKind.values, json['kind'], MediaSourceKind.auto),
    path: readStringOrNull(json['path']),
    durationMs: readIntOrNull(json['durationMs']),
  );

  final MediaSourceKind kind;
  final String? path;
  final int? durationMs;

  bool get isAuto => kind == MediaSourceKind.auto;

  MediaSource copyWith({
    MediaSourceKind? kind,
    String? path,
    int? durationMs,
    bool clearPath = false,
    bool clearDuration = false,
  }) => MediaSource(
    kind: kind ?? this.kind,
    path: clearPath ? null : (path ?? this.path),
    durationMs: clearDuration ? null : (durationMs ?? this.durationMs),
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': modelSchemaVersion,
    'kind': kind.name,
    'path': path,
    'durationMs': durationMs,
  };

  @override
  bool operator ==(Object other) =>
      other is MediaSource &&
      other.kind == kind &&
      other.path == path &&
      other.durationMs == durationMs;

  @override
  int get hashCode => Object.hash(kind, path, durationMs);
}
