import 'package:flutter/foundation.dart';
import 'package:postzera/core/models/media_spec.dart';
import 'package:postzera/core/models/variant.dart';

/// A rendered slide and how long it shows.
@immutable
class SlideFile {
  const SlideFile({required this.path, required this.durationMs});

  final String path;
  final int durationMs;
}

/// A transparent image shown over a video between [startMs] and [endMs].
@immutable
class TimedOverlay {
  const TimedOverlay({
    required this.path,
    required this.startMs,
    required this.endMs,
  });

  final String path;
  final int startMs;
  final int endMs;
}

/// Encodes video with the platform's native encoders. Silent output only.
/// Progress is reported from 0 to 1.
abstract class VideoComposerPort {
  /// Joins [slides] into one MP4 at the size of [spec].
  Future<void> composeSlides(
    List<SlideFile> slides,
    MediaSpec spec, {
    required String outPath,
    void Function(double progress)? onProgress,
  });

  /// Center-crops and scales [source] to the plan's canvas, trims it to the
  /// platform maximum, and lays [overlays] on top.
  Future<void> reframeWithOverlay(
    String source,
    MediaPlan plan, {
    required List<TimedOverlay> overlays,
    required String outPath,
    void Function(double progress)? onProgress,
  });

  /// Stops a render in progress.
  Future<void> cancel();
}
