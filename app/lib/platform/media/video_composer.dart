import 'dart:async';
import 'dart:ui' show Color, Offset, Size;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:postzera/core/models/app_error.dart';
import 'package:postzera/core/models/media_spec.dart';
import 'package:postzera/core/models/variant.dart';
import 'package:postzera/core/ports/video_composer_port.dart';
import 'package:postzera/core/services/error_classifier.dart';
import 'package:postzera/utils/id_generator.dart';
import 'package:postzera/utils/log.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

/// Makes video with the phone's own encoders (Media3 on Android, AVFoundation
/// on iPhone) through `pro_video_editor`. Output is an MP4 at the canvas size.
///
/// Only this file knows the plugin. If a clip's scale cannot be forced to the
/// exact canvas, the composition below is where it changes.
class VideoComposer implements VideoComposerPort {
  VideoComposer({
    ProVideoEditor? editor,
    this.classifier = const ErrorClassifier(),
  }) : _editor = editor ?? ProVideoEditor.instance;

  final ProVideoEditor _editor;
  final ErrorClassifier classifier;

  /// 8 Mbps, the plugin's 1080p preset, for every canvas.
  static const int bitrate = 8000000;
  static const double frameRate = 30;

  String? _activeId;

  @override
  Future<void> composeSlides(
    List<SlideFile> slides,
    MediaSpec spec, {
    required String outPath,
    void Function(double progress)? onProgress,
  }) {
    final StopMotionRenderData data = slideData(slides, spec);
    return _run(
      data.id,
      onProgress,
      () => _editor.renderStopMotionToFile(outPath, data),
    );
  }

  @override
  Future<void> reframeWithOverlay(
    String source,
    MediaPlan plan, {
    required List<TimedOverlay> overlays,
    required String outPath,
    void Function(double progress)? onProgress,
  }) async {
    int? knownMs = plan.sourceDurationMs;
    if (knownMs == null) {
      try {
        final VideoMetadata meta = await _editor.getMetadata(
          EditorVideo.file(source),
        );
        knownMs = meta.duration.inMilliseconds;
      } catch (error) {
        throw _classify(error);
      }
    }
    final VideoRenderData data = reframeData(
      source,
      plan,
      overlays,
      sourceMs: knownMs,
    );
    return _run(
      data.id,
      onProgress,
      () => _editor.renderVideoToFile(outPath, data),
    );
  }

  @override
  Future<void> cancel() async {
    final String? id = _activeId;
    if (id == null) {
      return;
    }
    try {
      await _editor.cancel(id);
    } catch (error) {
      Log.w('video', 'cancel failed: ${error.runtimeType}');
    }
  }

  /// One frame per slide, each held for its own duration, scaled to cover the
  /// canvas.
  @visibleForTesting
  static StopMotionRenderData slideData(
    List<SlideFile> slides,
    MediaSpec spec,
  ) {
    return StopMotionRenderData(
      id: newId(),
      frames: <StopMotionFrame>[
        for (final SlideFile s in slides)
          StopMotionFrame(
            image: EditorLayerImage.file(s.path),
            duration: Duration(milliseconds: s.durationMs),
          ),
      ],
      frameRate: frameRate,
      resolution: Size(spec.widthPx.toDouble(), spec.heightPx.toDouble()),
      fit: StopMotionFit.cover,
      bitrate: bitrate,
    );
  }

  /// A one-layer composition on a canvas of exactly the platform's size. The
  /// clip is scaled to cover it, which crops the overflow evenly (a center
  /// crop). Overlays are timed image layers the size of the canvas. The clip
  /// is trimmed to the platform maximum.
  @visibleForTesting
  static VideoRenderData reframeData(
    String source,
    MediaPlan plan,
    List<TimedOverlay> overlays, {
    required int sourceMs,
  }) {
    final Size canvas = Size(
      plan.spec.widthPx.toDouble(),
      plan.spec.heightPx.toDouble(),
    );
    final int capMs = plan.spec.maxVideoSeconds * 1000;
    return VideoRenderData(
      id: newId(),
      composition: VideoComposition(
        canvasSize: canvas,
        backgroundColor: const Color(0xFF000000),
        layers: <VideoLayer>[
          VideoLayer(
            transform: SegmentTransform(
              offset: Offset.zero,
              size: canvas,
              fit: SegmentFit.cover,
            ),
            clips: <VideoSegment>[
              VideoSegment(
                video: EditorVideo.file(source),
                endTime: sourceMs > capMs
                    ? Duration(milliseconds: capMs)
                    : null,
              ),
            ],
          ),
        ],
      ),
      imageLayers: <ImageLayer>[
        for (final TimedOverlay o in overlays)
          ImageLayer(
            image: EditorLayerImage.file(o.path),
            offset: Offset.zero,
            size: canvas,
            startTime: Duration(milliseconds: o.startMs),
            endTime: Duration(milliseconds: o.endMs),
          ),
      ],
      bitrate: bitrate,
      maxFrameRate: frameRate.toInt(),
    );
  }

  Future<void> _run(
    String id,
    void Function(double)? onProgress,
    Future<void> Function() render,
  ) async {
    _activeId = id;
    StreamSubscription<ProgressModel>? subscription;
    if (onProgress != null) {
      subscription = _editor
          .progressStreamById(id)
          .listen(
            (ProgressModel m) => onProgress(m.progress.clamp(0, 1).toDouble()),
          );
    }
    try {
      await render();
    } on RenderCanceledException {
      rethrow;
    } catch (error) {
      throw _classify(error);
    } finally {
      _activeId = null;
      await subscription?.cancel();
    }
  }

  AppError _classify(Object error) {
    if (error is AppError) {
      return error;
    }
    if (error is PlatformException) {
      final NativeFailureDetails? details = NativeFailureDetails.of(error);
      if (details != null && details.isOutOfStorage) {
        return AppError.of(AppErrorKind.storageFull, details: 'out of storage');
      }
    }
    return classifier.classify(error, fallback: AppErrorKind.renderFailed);
  }
}
