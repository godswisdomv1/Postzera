import 'package:flutter/foundation.dart';
import 'package:postzera/core/models/json_read.dart';
import 'package:postzera/core/models/media_spec.dart';
import 'package:postzera/core/models/platform_template.dart';

/// Whether a platform gets an image, a video, or whatever the source is.
enum PreferredKind { image, video, followSource }

/// How caption length is measured. [x] uses X's published weighting.
enum CountingScheme { plain, x }

/// Everything the app knows about one platform: its template, media shape and
/// limits. Built-in and custom platforms use the same class.
@immutable
class PlatformProfile {
  const PlatformProfile({
    required this.id,
    required this.name,
    required this.monogram,
    required this.template,
    required this.media,
    required this.captionLimit,
    this.enabled = true,
    this.isCustom = false,
    this.sortOrder = 0,
    this.titleLimit,
    this.maxHashtags = 0,
    this.preferredKind = PreferredKind.followSource,
    this.countingScheme = CountingScheme.plain,
    this.openUrl,
  });

  factory PlatformProfile.fromJson(Map<String, Object?> json) {
    final Map<String, Object?> template = readMap(json['template']);
    final Map<String, Object?> media = readMap(json['media']);
    return PlatformProfile(
      id: readString(json['id']),
      name: readString(json['name']),
      monogram: readString(json['monogram']),
      enabled: readBool(json['enabled'], true),
      isCustom: readBool(json['isCustom']),
      sortOrder: readInt(json['sortOrder']),
      template: PlatformTemplate.fromJson(template),
      media: media.isEmpty
          ? MediaSpec.forAspect(MediaAspect.ratio4x5)
          : MediaSpec.fromJson(media),
      captionLimit: readInt(json['captionLimit'], 2200),
      titleLimit: readIntOrNull(json['titleLimit']),
      maxHashtags: readInt(json['maxHashtags']),
      preferredKind: readEnum(
        PreferredKind.values,
        json['preferredKind'],
        PreferredKind.followSource,
      ),
      countingScheme: readEnum(
        CountingScheme.values,
        json['countingScheme'],
        CountingScheme.plain,
      ),
      openUrl: readStringOrNull(json['openUrl']),
    );
  }

  /// A slug such as `instagram`.
  final String id;
  final String name;

  /// One or two letters shown in the platform mark.
  final String monogram;
  final bool enabled;
  final bool isCustom;
  final int sortOrder;
  final PlatformTemplate template;
  final MediaSpec media;
  final int captionLimit;

  /// Null when the platform has no title.
  final int? titleLimit;
  final int maxHashtags;
  final PreferredKind preferredKind;
  final CountingScheme countingScheme;

  /// Where **Open** launches when the platform's app is not in the share sheet.
  final String? openUrl;

  PlatformProfile copyWith({
    String? id,
    String? name,
    String? monogram,
    bool? enabled,
    bool? isCustom,
    int? sortOrder,
    PlatformTemplate? template,
    MediaSpec? media,
    int? captionLimit,
    int? titleLimit,
    bool clearTitleLimit = false,
    int? maxHashtags,
    PreferredKind? preferredKind,
    CountingScheme? countingScheme,
    String? openUrl,
    bool clearOpenUrl = false,
  }) =>
      PlatformProfile(
        id: id ?? this.id,
        name: name ?? this.name,
        monogram: monogram ?? this.monogram,
        enabled: enabled ?? this.enabled,
        isCustom: isCustom ?? this.isCustom,
        sortOrder: sortOrder ?? this.sortOrder,
        template: template ?? this.template,
        media: media ?? this.media,
        captionLimit: captionLimit ?? this.captionLimit,
        titleLimit: clearTitleLimit ? null : (titleLimit ?? this.titleLimit),
        maxHashtags: maxHashtags ?? this.maxHashtags,
        preferredKind: preferredKind ?? this.preferredKind,
        countingScheme: countingScheme ?? this.countingScheme,
        openUrl: clearOpenUrl ? null : (openUrl ?? this.openUrl),
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'schemaVersion': modelSchemaVersion,
        'id': id,
        'name': name,
        'monogram': monogram,
        'enabled': enabled,
        'isCustom': isCustom,
        'sortOrder': sortOrder,
        'template': template.toJson(),
        'media': media.toJson(),
        'captionLimit': captionLimit,
        'titleLimit': titleLimit,
        'maxHashtags': maxHashtags,
        'preferredKind': preferredKind.name,
        'countingScheme': countingScheme.name,
        'openUrl': openUrl,
      };

  @override
  bool operator ==(Object other) =>
      other is PlatformProfile &&
      other.id == id &&
      other.name == name &&
      other.monogram == monogram &&
      other.enabled == enabled &&
      other.isCustom == isCustom &&
      other.sortOrder == sortOrder &&
      other.template == template &&
      other.media == media &&
      other.captionLimit == captionLimit &&
      other.titleLimit == titleLimit &&
      other.maxHashtags == maxHashtags &&
      other.preferredKind == preferredKind &&
      other.countingScheme == countingScheme &&
      other.openUrl == openUrl;

  @override
  int get hashCode => Object.hash(
        id,
        name,
        monogram,
        enabled,
        isCustom,
        sortOrder,
        template,
        media,
        captionLimit,
        titleLimit,
        maxHashtags,
        preferredKind,
        countingScheme,
        openUrl,
      );
}
