import 'package:flutter/foundation.dart';
import 'package:postzera/core/models/json_read.dart';

enum SendStatus { pending, done, skipped }

/// Whether one post has been sent to one platform.
@immutable
class SendRecord {
  const SendRecord({
    required this.postId,
    required this.platformId,
    required this.status,
    this.doneAt,
  });

  factory SendRecord.fromJson(Map<String, Object?> json) => SendRecord(
    postId: readString(json['postId']),
    platformId: readString(json['platformId']),
    status: readEnum(SendStatus.values, json['status'], SendStatus.pending),
    doneAt: readDateOrNull(json['doneAt']),
  );

  final String postId;
  final String platformId;
  final SendStatus status;

  /// UTC.
  final DateTime? doneAt;

  SendRecord copyWith({
    String? postId,
    String? platformId,
    SendStatus? status,
    DateTime? doneAt,
    bool clearDoneAt = false,
  }) => SendRecord(
    postId: postId ?? this.postId,
    platformId: platformId ?? this.platformId,
    status: status ?? this.status,
    doneAt: clearDoneAt ? null : (doneAt ?? this.doneAt),
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': modelSchemaVersion,
    'postId': postId,
    'platformId': platformId,
    'status': status.name,
    'doneAt': doneAt?.toUtc().millisecondsSinceEpoch,
  };

  @override
  bool operator ==(Object other) =>
      other is SendRecord &&
      other.postId == postId &&
      other.platformId == platformId &&
      other.status == status &&
      other.doneAt == doneAt;

  @override
  int get hashCode => Object.hash(postId, platformId, status, doneAt);
}
