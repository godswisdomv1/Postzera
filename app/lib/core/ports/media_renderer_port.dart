import 'package:postzera/core/models/variant.dart';

/// Draws still images: cards, photo-backed cards, slides and the transparent
/// text layers laid over a video. Implemented with `dart:ui`.
abstract class MediaRendererPort {
  /// Writes a PNG of the whole variant image to [outPath].
  Future<void> renderImage(MediaPlan plan, {required String outPath});

  /// Writes a PNG of one slide of a text-card video.
  Future<void> renderSlide(
    SlidePlan slide,
    MediaPlan plan, {
    required String outPath,
  });

  /// Writes a transparent PNG holding only [blocks] in their caption panel,
  /// to be laid over a video.
  Future<void> renderOverlay(
    MediaPlan plan, {
    required List<CardTextBlock> blocks,
    required String outPath,
  });
}
