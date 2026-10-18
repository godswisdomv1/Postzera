import 'package:flutter/foundation.dart';
import 'package:postzera/core/models/card_theme.dart';
import 'package:postzera/core/models/media_source.dart';
import 'package:postzera/core/models/media_spec.dart';

/// Image or video: what a variant produces.
enum MediaOutputKind { image, video }

enum VariantWarning {
  captionTruncated,
  hashtagsDropped,
  linkMissing,
  cardTextShortened,
}

/// Which slot a piece of text on the media came from.
enum CardTextRole { hook, body, cta }

@immutable
class CardTextBlock {
  const CardTextBlock({required this.role, required this.text});

  final CardTextRole role;
  final String text;

  @override
  bool operator ==(Object other) =>
      other is CardTextBlock && other.role == role && other.text == text;

  @override
  int get hashCode => Object.hash(role, text);

  @override
  String toString() => 'CardTextBlock(${role.name})';
}

/// One slide of a video made from text cards.
@immutable
class SlidePlan {
  const SlidePlan({required this.blocks, required this.durationMs});

  final List<CardTextBlock> blocks;
  final int durationMs;

  @override
  bool operator ==(Object other) =>
      other is SlidePlan &&
      listEquals(other.blocks, blocks) &&
      other.durationMs == durationMs;

  @override
  int get hashCode => Object.hash(Object.hashAll(blocks), durationMs);
}

/// Everything the renderer needs to make one file. Computed, never stored.
@immutable
class MediaPlan {
  const MediaPlan({
    required this.kind,
    required this.spec,
    required this.theme,
    required this.blocks,
    required this.sourceKind,
    required this.cacheKey,
    this.sourcePath,
    this.slides = const <SlidePlan>[],
  });

  final MediaOutputKind kind;
  final MediaSpec spec;
  final MediaCardTheme theme;

  /// Text printed on a still image or the overlay.
  final List<CardTextBlock> blocks;
  final MediaSourceKind sourceKind;

  /// The user's photo or video, when there is one.
  final String? sourcePath;

  /// Slides of a text-card video. Empty for an image or a clip overlay.
  final List<SlidePlan> slides;

  /// Stable hash of everything that affects the output.
  final String cacheKey;

  /// Total length of the slides, in milliseconds.
  int get slidesDurationMs =>
      slides.fold<int>(0, (int sum, SlidePlan s) => sum + s.durationMs);

  @override
  bool operator ==(Object other) =>
      other is MediaPlan &&
      other.kind == kind &&
      other.spec == spec &&
      other.theme == theme &&
      listEquals(other.blocks, blocks) &&
      other.sourceKind == sourceKind &&
      other.sourcePath == sourcePath &&
      listEquals(other.slides, slides) &&
      other.cacheKey == cacheKey;

  @override
  int get hashCode => Object.hash(
        kind,
        spec,
        theme,
        Object.hashAll(blocks),
        sourceKind,
        sourcePath,
        Object.hashAll(slides),
        cacheKey,
      );
}

/// One platform's finished text and media plan. Computed, never stored.
@immutable
class Variant {
  const Variant({
    required this.platformId,
    required this.caption,
    required this.mediaPlan,
    this.title,
    this.warnings = const <VariantWarning>{},
  });

  final String platformId;
  final String caption;

  /// Null when the platform has no title.
  final String? title;
  final MediaPlan mediaPlan;
  final Set<VariantWarning> warnings;

  @override
  bool operator ==(Object other) =>
      other is Variant &&
      other.platformId == platformId &&
      other.caption == caption &&
      other.title == title &&
      other.mediaPlan == mediaPlan &&
      setEquals(other.warnings, warnings);

  @override
  int get hashCode => Object.hash(
        platformId,
        caption,
        title,
        mediaPlan,
        Object.hashAll(warnings.toList()..sort(_byName)),
      );

  static int _byName(VariantWarning a, VariantWarning b) =>
      a.name.compareTo(b.name);
}
