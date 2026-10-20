import 'package:flutter/foundation.dart';
import 'package:postzera/core/models/json_read.dart';
import 'package:postzera/core/models/media_source.dart';

enum PostStatus { draft, scheduled, sent, archived }

/// The master post: five text slots, a media choice and a schedule.
@immutable
class Post {
  const Post({
    required this.id,
    required this.hook,
    required this.cardThemeId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.body = '',
    this.cta = '',
    this.link = '',
    this.hashtags = const <String>[],
    this.mediaSource = const MediaSource.auto(),
    this.scheduledAt,
  });

  factory Post.fromJson(Map<String, Object?> json) {
    final DateTime epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    final Map<String, Object?> media = readMap(json['mediaSource']);
    return Post(
      id: readString(json['id']),
      hook: readString(json['hook']),
      body: readString(json['body']),
      cta: readString(json['cta']),
      link: readString(json['link']),
      hashtags: readStringList(json['hashtags']),
      mediaSource: media.isEmpty
          ? const MediaSource.auto()
          : MediaSource.fromJson(media),
      cardThemeId: readString(json['cardThemeId'], 'paper'),
      scheduledAt: readDateOrNull(json['scheduledAt']),
      status: readEnum(PostStatus.values, json['status'], PostStatus.draft),
      createdAt: readDateOrNull(json['createdAt']) ?? epoch,
      updatedAt: readDateOrNull(json['updatedAt']) ?? epoch,
    );
  }

  final String id;
  final String hook;
  final String body;
  final String cta;
  final String link;
  final String cardThemeId;
  final List<String> hashtags;
  final MediaSource mediaSource;

  /// UTC. Null for a draft.
  final DateTime? scheduledAt;
  final PostStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  Post copyWith({
    String? id,
    String? hook,
    String? body,
    String? cta,
    String? link,
    String? cardThemeId,
    List<String>? hashtags,
    MediaSource? mediaSource,
    DateTime? scheduledAt,
    bool clearScheduledAt = false,
    PostStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Post(
    id: id ?? this.id,
    hook: hook ?? this.hook,
    body: body ?? this.body,
    cta: cta ?? this.cta,
    link: link ?? this.link,
    cardThemeId: cardThemeId ?? this.cardThemeId,
    hashtags: hashtags ?? this.hashtags,
    mediaSource: mediaSource ?? this.mediaSource,
    scheduledAt: clearScheduledAt ? null : (scheduledAt ?? this.scheduledAt),
    status: status ?? this.status,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': modelSchemaVersion,
    'id': id,
    'hook': hook,
    'body': body,
    'cta': cta,
    'link': link,
    'hashtags': hashtags,
    'mediaSource': mediaSource.toJson(),
    'cardThemeId': cardThemeId,
    'scheduledAt': scheduledAt?.toUtc().millisecondsSinceEpoch,
    'status': status.name,
    'createdAt': createdAt.toUtc().millisecondsSinceEpoch,
    'updatedAt': updatedAt.toUtc().millisecondsSinceEpoch,
  };

  @override
  bool operator ==(Object other) =>
      other is Post &&
      other.id == id &&
      other.hook == hook &&
      other.body == body &&
      other.cta == cta &&
      other.link == link &&
      other.cardThemeId == cardThemeId &&
      listEquals(other.hashtags, hashtags) &&
      other.mediaSource == mediaSource &&
      other.scheduledAt == scheduledAt &&
      other.status == status &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(
    id,
    hook,
    body,
    cta,
    link,
    cardThemeId,
    Object.hashAll(hashtags),
    mediaSource,
    scheduledAt,
    status,
    createdAt,
    updatedAt,
  );
}
