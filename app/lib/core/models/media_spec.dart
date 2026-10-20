import 'package:flutter/foundation.dart';
import 'package:postzera/core/models/json_read.dart';

/// The fixed list of shapes a platform can use.
enum MediaAspect { ratio16x9, ratio4x5, ratio9x16, ratio2x3 }

/// Clear space, in canvas pixels, kept free of text on each edge.
@immutable
class SafeInsets {
  const SafeInsets({
    required this.top,
    required this.bottom,
    required this.left,
    required this.right,
  });

  factory SafeInsets.fromJson(Map<String, Object?> json) => SafeInsets(
    top: readInt(json['top']),
    bottom: readInt(json['bottom']),
    left: readInt(json['left']),
    right: readInt(json['right']),
  );

  /// The insets of blueprint section 8: for 9:16, 270 / 672 / 64 / 227 px
  /// (the strictest edges of the Reels, Stories and TikTok zones); for every
  /// other shape, 6% of the matching dimension on each side.
  factory SafeInsets.forCanvas(MediaAspect aspect, int width, int height) {
    if (aspect == MediaAspect.ratio9x16) {
      return const SafeInsets(top: 270, bottom: 672, left: 64, right: 227);
    }
    final int vertical = (height * 0.06).round();
    final int horizontal = (width * 0.06).round();
    return SafeInsets(
      top: vertical,
      bottom: vertical,
      left: horizontal,
      right: horizontal,
    );
  }

  final int top;
  final int bottom;
  final int left;
  final int right;

  Map<String, Object?> toJson() => <String, Object?>{
    'top': top,
    'bottom': bottom,
    'left': left,
    'right': right,
  };

  @override
  bool operator ==(Object other) =>
      other is SafeInsets &&
      other.top == top &&
      other.bottom == bottom &&
      other.left == left &&
      other.right == right;

  @override
  int get hashCode => Object.hash(top, bottom, left, right);
}

/// The canvas a platform's media is made at.
@immutable
class MediaSpec {
  const MediaSpec({
    required this.aspect,
    required this.widthPx,
    required this.heightPx,
    required this.safeInsets,
    this.maxVideoSeconds = 60,
  });

  /// The default size of [aspect]: 16:9 is 1600 x 900, 4:5 is 1080 x 1350,
  /// 9:16 is 1080 x 1920 and 2:3 is 1000 x 1500.
  factory MediaSpec.forAspect(MediaAspect aspect, {int maxVideoSeconds = 60}) {
    final (int, int) size = switch (aspect) {
      MediaAspect.ratio16x9 => (1600, 900),
      MediaAspect.ratio4x5 => (1080, 1350),
      MediaAspect.ratio9x16 => (1080, 1920),
      MediaAspect.ratio2x3 => (1000, 1500),
    };
    return MediaSpec(
      aspect: aspect,
      widthPx: size.$1,
      heightPx: size.$2,
      safeInsets: SafeInsets.forCanvas(aspect, size.$1, size.$2),
      maxVideoSeconds: maxVideoSeconds,
    );
  }

  factory MediaSpec.fromJson(Map<String, Object?> json) {
    final MediaAspect aspect = readEnum(
      MediaAspect.values,
      json['aspect'],
      MediaAspect.ratio4x5,
    );
    final MediaSpec fallback = MediaSpec.forAspect(aspect);
    final int width = readInt(json['widthPx'], fallback.widthPx);
    final int height = readInt(json['heightPx'], fallback.heightPx);
    final Map<String, Object?> insets = readMap(json['safeInsets']);
    return MediaSpec(
      aspect: aspect,
      widthPx: width > 0 ? width : fallback.widthPx,
      heightPx: height > 0 ? height : fallback.heightPx,
      safeInsets: insets.isEmpty
          ? SafeInsets.forCanvas(aspect, width, height)
          : SafeInsets.fromJson(insets),
      maxVideoSeconds: readInt(json['maxVideoSeconds'], 60),
    );
  }

  final MediaAspect aspect;
  final int widthPx;
  final int heightPx;
  final SafeInsets safeInsets;
  final int maxVideoSeconds;

  MediaSpec copyWith({
    MediaAspect? aspect,
    int? widthPx,
    int? heightPx,
    SafeInsets? safeInsets,
    int? maxVideoSeconds,
  }) => MediaSpec(
    aspect: aspect ?? this.aspect,
    widthPx: widthPx ?? this.widthPx,
    heightPx: heightPx ?? this.heightPx,
    safeInsets: safeInsets ?? this.safeInsets,
    maxVideoSeconds: maxVideoSeconds ?? this.maxVideoSeconds,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': modelSchemaVersion,
    'aspect': aspect.name,
    'widthPx': widthPx,
    'heightPx': heightPx,
    'safeInsets': safeInsets.toJson(),
    'maxVideoSeconds': maxVideoSeconds,
  };

  @override
  bool operator ==(Object other) =>
      other is MediaSpec &&
      other.aspect == aspect &&
      other.widthPx == widthPx &&
      other.heightPx == heightPx &&
      other.safeInsets == safeInsets &&
      other.maxVideoSeconds == maxVideoSeconds;

  @override
  int get hashCode =>
      Object.hash(aspect, widthPx, heightPx, safeInsets, maxVideoSeconds);
}
