import 'package:flutter/foundation.dart';
import 'package:postzera/core/models/app_error.dart';
import 'package:postzera/core/models/variant.dart';
import 'package:postzera/core/ports/file_store_port.dart';
import 'package:postzera/core/ports/media_renderer_port.dart';
import 'package:postzera/core/ports/video_composer_port.dart';
import 'package:postzera/utils/log.dart';

/// A finished media file.
@immutable
class MediaResult {
  const MediaResult({
    required this.path,
    required this.kind,
    required this.width,
    required this.height,
    required this.durationMs,
  });

  final String path;
  final MediaOutputKind kind;
  final int width;
  final int height;

  /// Zero for an image.
  final int durationMs;
}

/// Thrown by [MediaPipeline.produce] after [MediaPipeline.cancel].
class MediaCancelled implements Exception {
  const MediaCancelled();

  @override
  String toString() => 'MediaCancelled';
}

/// Plans are already made; this turns one plan into one file: check the cache,
/// render, verify, and clean up after any failure. Render one variant at a
/// time: the caller serializes jobs.
class MediaPipeline {
  MediaPipeline({
    required this.files,
    required this.renderer,
    required this.video,
  });

  final FileStorePort files;
  final MediaRendererPort renderer;
  final VideoComposerPort video;

  static const int _clipHookMs = 4000;
  static const int _clipCtaMs = 3000;

  bool _cancelRequested = false;

  /// Asks the running [produce] to stop. It then throws [MediaCancelled].
  Future<void> cancel() async {
    _cancelRequested = true;
    await video.cancel();
  }

  /// The output file of [variant]. The cache key is part of the file name, so
  /// an unchanged variant finds its file again and is never re-rendered.
  Future<MediaResult> produce(
    Variant variant, {
    required String postId,
    void Function(double progress)? onProgress,
  }) async {
    _cancelRequested = false;
    final MediaPlan plan = variant.mediaPlan;
    final bool isVideo = plan.kind == MediaOutputKind.video;
    final String outPath = await files.outputPath(
      postId: postId,
      platformId: variant.platformId,
      extension: isVideo ? 'mp4' : 'png',
      suffix: plan.cacheKey,
    );

    final FileInfo? cached = await files.stat(outPath);
    if (cached != null && cached.sizeBytes > 0) {
      onProgress?.call(1);
      return _result(plan, outPath, _durationOf(plan));
    }

    final List<String> temporaries = <String>[];
    bool succeeded = false;
    try {
      onProgress?.call(0);
      if (!isVideo) {
        await renderer.renderImage(plan, outPath: outPath);
      } else if (plan.slides.isNotEmpty) {
        await _composeSlides(
          plan,
          variant.platformId,
          postId,
          outPath,
          temporaries,
          onProgress,
        );
      } else {
        await _reframeClip(
          plan,
          variant.platformId,
          postId,
          outPath,
          temporaries,
          onProgress,
        );
      }
      _checkCancelled();
      final FileInfo? made = await files.stat(outPath);
      if (made == null || made.sizeBytes <= 0) {
        throw AppError.of(
          AppErrorKind.renderFailed,
          details: 'output missing or empty',
        );
      }
      succeeded = true;
      onProgress?.call(1);
      return _result(plan, outPath, _durationOf(plan));
    } on MediaCancelled {
      rethrow;
    } on AppError {
      rethrow;
    } catch (error) {
      if (_cancelRequested) {
        throw const MediaCancelled();
      }
      Log.e('pipeline', error.runtimeType.toString());
      throw AppError.of(
        AppErrorKind.renderFailed,
        details: error.runtimeType.toString(),
      );
    } finally {
      for (final String path in temporaries) {
        await files.delete(path);
      }
      if (!succeeded) {
        await files.delete(outPath);
      }
    }
  }

  Future<void> _composeSlides(
    MediaPlan plan,
    String platformId,
    String postId,
    String outPath,
    List<String> temporaries,
    void Function(double)? onProgress,
  ) async {
    final List<SlideFile> slideFiles = <SlideFile>[];
    final int count = plan.slides.length;
    for (int i = 0; i < count; i++) {
      _checkCancelled();
      final String path = await files.outputPath(
        postId: postId,
        platformId: platformId,
        extension: 'png',
        suffix: '${plan.cacheKey}_s$i',
      );
      temporaries.add(path);
      await renderer.renderSlide(plan.slides[i], plan, outPath: path);
      slideFiles.add(
        SlideFile(path: path, durationMs: plan.slides[i].durationMs),
      );
      onProgress?.call(0.2 * (i + 1) / count);
    }
    _checkCancelled();
    await video.composeSlides(
      slideFiles,
      plan.spec,
      outPath: outPath,
      onProgress: (double v) => onProgress?.call(0.2 + 0.8 * v),
    );
  }

  Future<void> _reframeClip(
    MediaPlan plan,
    String platformId,
    String postId,
    String outPath,
    List<String> temporaries,
    void Function(double)? onProgress,
  ) async {
    final String? source = plan.sourcePath;
    if (source == null) {
      throw AppError.of(
        AppErrorKind.sourceUnreadable,
        details: 'video source missing',
      );
    }
    final int clipMs = _clipLength(plan);
    final List<TimedOverlay> overlays = <TimedOverlay>[];

    final List<CardTextBlock> hook = plan.blocks
        .where((CardTextBlock b) => b.role == CardTextRole.hook)
        .toList();
    final List<CardTextBlock> cta = plan.blocks
        .where((CardTextBlock b) => b.role == CardTextRole.cta)
        .toList();

    if (hook.isNotEmpty) {
      _checkCancelled();
      final String path = await files.outputPath(
        postId: postId,
        platformId: platformId,
        extension: 'png',
        suffix: '${plan.cacheKey}_oh',
      );
      temporaries.add(path);
      await renderer.renderOverlay(plan, blocks: hook, outPath: path);
      overlays.add(
        TimedOverlay(
          path: path,
          startMs: 0,
          endMs: clipMs < _clipHookMs ? clipMs : _clipHookMs,
        ),
      );
    }
    if (cta.isNotEmpty && clipMs > _clipHookMs) {
      _checkCancelled();
      final String path = await files.outputPath(
        postId: postId,
        platformId: platformId,
        extension: 'png',
        suffix: '${plan.cacheKey}_oc',
      );
      temporaries.add(path);
      await renderer.renderOverlay(plan, blocks: cta, outPath: path);
      final int start = clipMs - _clipCtaMs;
      overlays.add(
        TimedOverlay(
          path: path,
          startMs: start < _clipHookMs ? _clipHookMs : start,
          endMs: clipMs,
        ),
      );
    }
    onProgress?.call(0.1);
    _checkCancelled();
    await video.reframeWithOverlay(
      source,
      plan,
      overlays: overlays,
      outPath: outPath,
      onProgress: (double v) => onProgress?.call(0.1 + 0.9 * v),
    );
  }

  int _clipLength(MediaPlan plan) {
    final int cap = plan.spec.maxVideoSeconds * 1000;
    final int? source = plan.sourceDurationMs;
    return source == null || source > cap ? cap : source;
  }

  int _durationOf(MediaPlan plan) {
    if (plan.kind == MediaOutputKind.image) {
      return 0;
    }
    return plan.slides.isNotEmpty ? plan.slidesDurationMs : _clipLength(plan);
  }

  MediaResult _result(MediaPlan plan, String path, int durationMs) =>
      MediaResult(
        path: path,
        kind: plan.kind,
        width: plan.spec.widthPx,
        height: plan.spec.heightPx,
        durationMs: durationMs,
      );

  void _checkCancelled() {
    if (_cancelRequested) {
      throw const MediaCancelled();
    }
  }
}
