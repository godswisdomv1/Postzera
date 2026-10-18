import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:postzera/core/data/builtin_card_themes.dart';
import 'package:postzera/core/models/app_error.dart';
import 'package:postzera/core/models/media_source.dart';
import 'package:postzera/core/models/media_spec.dart';
import 'package:postzera/core/models/variant.dart';
import 'package:postzera/core/ports/file_store_port.dart';
import 'package:postzera/core/ports/media_renderer_port.dart';
import 'package:postzera/core/ports/video_composer_port.dart';
import 'package:postzera/core/services/media_pipeline.dart';
import 'package:postzera/core/services/variant_builder.dart';

import 'test_helpers.dart';

class FakeFiles implements FileStorePort {
  final Map<String, int> sizes = <String, int>{};

  @override
  Future<String> outputPath({
    required String postId,
    required String platformId,
    required String extension,
    String? suffix,
  }) async =>
      '/out/$postId/$platformId${suffix == null ? '' : '_$suffix'}.$extension';

  @override
  Future<FileInfo?> stat(String path) async {
    final int? size = sizes[path];
    return size == null
        ? null
        : FileInfo(sizeBytes: size, modified: DateTime.utc(2026));
  }

  @override
  Future<void> delete(String path) async {
    sizes.remove(path);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeRenderer implements MediaRendererPort {
  FakeRenderer(this.files);

  final FakeFiles files;
  int images = 0;
  int slides = 0;
  int overlays = 0;
  int writeSize = 100;
  Object? failWith;

  void _write(String path) {
    final Object? error = failWith;
    if (error != null) {
      throw error;
    }
    files.sizes[path] = writeSize;
  }

  @override
  Future<void> renderImage(MediaPlan plan, {required String outPath}) async {
    images++;
    _write(outPath);
  }

  @override
  Future<void> renderSlide(
    SlidePlan slide,
    MediaPlan plan, {
    required String outPath,
  }) async {
    slides++;
    _write(outPath);
  }

  @override
  Future<void> renderOverlay(
    MediaPlan plan, {
    required List<CardTextBlock> blocks,
    required String outPath,
  }) async {
    overlays++;
    _write(outPath);
  }
}

class FakeVideo implements VideoComposerPort {
  FakeVideo(this.files);

  final FakeFiles files;
  int composes = 0;
  int reframes = 0;
  bool cancelled = false;
  Completer<void>? gate;
  final Completer<void> started = Completer<void>();
  List<TimedOverlay> lastOverlays = <TimedOverlay>[];

  @override
  Future<void> composeSlides(
    List<SlideFile> slides,
    MediaSpec spec, {
    required String outPath,
    void Function(double progress)? onProgress,
  }) async {
    composes++;
    if (!started.isCompleted) {
      started.complete();
    }
    final Completer<void>? g = gate;
    if (g != null) {
      await g.future;
    }
    if (cancelled) {
      throw StateError('cancelled');
    }
    files.sizes[outPath] = 1000;
    onProgress?.call(1);
  }

  @override
  Future<void> reframeWithOverlay(
    String source,
    MediaPlan plan, {
    required List<TimedOverlay> overlays,
    required String outPath,
    void Function(double progress)? onProgress,
  }) async {
    reframes++;
    lastOverlays = overlays;
    files.sizes[outPath] = 1000;
  }

  @override
  Future<void> cancel() async {
    cancelled = true;
    final Completer<void>? g = gate;
    if (g != null && !g.isCompleted) {
      g.complete();
    }
  }
}

void main() {
  const VariantBuilder builder = VariantBuilder();
  late FakeFiles files;
  late FakeRenderer renderer;
  late FakeVideo video;
  late MediaPipeline pipeline;

  setUp(() {
    files = FakeFiles();
    renderer = FakeRenderer(files);
    video = FakeVideo(files);
    pipeline = MediaPipeline(files: files, renderer: renderer, video: video);
  });

  Variant variant(String platform, {MediaSource? media}) => builder.build(
        testPost(hook: 'Hook', body: 'Body text', cta: 'Go', media: media),
        profileById(platform),
        cardThemeById('paper'),
      );

  test('an image variant is rendered once and verified', () async {
    final List<double> progress = <double>[];
    final MediaResult r = await pipeline.produce(
      variant('instagram'),
      postId: 'p1',
      onProgress: progress.add,
    );
    expect(r.path, endsWith('.png'));
    expect(r.kind, MediaOutputKind.image);
    expect(r.width, 1080);
    expect(r.height, 1350);
    expect(r.durationMs, 0);
    expect(renderer.images, 1);
    expect(files.sizes[r.path], greaterThan(0));
    expect(progress.first, 0);
    expect(progress.last, 1);
  });

  test('an unchanged variant is served from the cache', () async {
    final Variant v = variant('instagram');
    final MediaResult first = await pipeline.produce(v, postId: 'p1');
    final MediaResult second = await pipeline.produce(v, postId: 'p1');
    expect(second.path, first.path);
    expect(renderer.images, 1);
  });

  test('a changed variant gets its own file', () async {
    final MediaResult a = await pipeline.produce(variant('instagram'), postId: 'p1');
    final MediaResult b = await pipeline.produce(
      builder.build(
        testPost(hook: 'Different'),
        profileById('instagram'),
        cardThemeById('paper'),
      ),
      postId: 'p1',
    );
    expect(b.path, isNot(a.path));
    expect(renderer.images, 2);
  });

  test('text-card slides become one video and the slide files are removed',
      () async {
    final Variant v = variant('tiktok');
    final MediaResult r = await pipeline.produce(v, postId: 'p1');
    expect(r.path, endsWith('.mp4'));
    expect(r.kind, MediaOutputKind.video);
    expect(r.width, 1080);
    expect(r.height, 1920);
    expect(renderer.slides, v.mediaPlan.slides.length);
    expect(video.composes, 1);
    expect(r.durationMs, v.mediaPlan.slidesDurationMs);
    expect(files.sizes.keys.where((String k) => k.endsWith('.png')), isEmpty);
    expect(files.sizes.keys.where((String k) => k.endsWith('.mp4')).length, 1);
  });

  test('a clip gets a hook overlay for 4 s and a call to action for 3 s',
      () async {
    final Variant v = variant(
      'tiktok',
      media: const MediaSource(
        kind: MediaSourceKind.video,
        path: '/v/clip.mp4',
        durationMs: 12000,
      ),
    );
    final MediaResult r = await pipeline.produce(v, postId: 'p1');
    expect(video.reframes, 1);
    expect(renderer.overlays, 2);
    expect(video.lastOverlays.length, 2);
    expect(video.lastOverlays[0].startMs, 0);
    expect(video.lastOverlays[0].endMs, 4000);
    expect(video.lastOverlays[1].startMs, 9000);
    expect(video.lastOverlays[1].endMs, 12000);
    expect(r.durationMs, 12000);
    expect(files.sizes.keys.where((String k) => k.endsWith('.png')), isEmpty);
  });

  test('an unexpected renderer failure becomes renderFailed and leaves no file',
      () async {
    renderer.failWith = StateError('boom');
    await expectLater(
      pipeline.produce(variant('instagram'), postId: 'p1'),
      throwsA(
        isA<AppError>().having(
          (AppError e) => e.kind,
          'kind',
          AppErrorKind.renderFailed,
        ),
      ),
    );
    expect(files.sizes, isEmpty);
  });

  test('a classified error from an adapter passes through unchanged', () async {
    renderer.failWith = AppError.of(AppErrorKind.storageFull);
    await expectLater(
      pipeline.produce(variant('instagram'), postId: 'p1'),
      throwsA(
        isA<AppError>().having(
          (AppError e) => e.kind,
          'kind',
          AppErrorKind.storageFull,
        ),
      ),
    );
  });

  test('an empty output file counts as a failure and is removed', () async {
    renderer.writeSize = 0;
    await expectLater(
      pipeline.produce(variant('instagram'), postId: 'p1'),
      throwsA(
        isA<AppError>().having(
          (AppError e) => e.kind,
          'kind',
          AppErrorKind.renderFailed,
        ),
      ),
    );
    expect(files.sizes, isEmpty);
  });

  test('cancel stops a render in progress and cleans up', () async {
    video.gate = Completer<void>();
    final Future<MediaResult> running =
        pipeline.produce(variant('tiktok'), postId: 'p1');
    final Future<void> check = expectLater(running, throwsA(isA<MediaCancelled>()));
    await video.started.future;
    await pipeline.cancel();
    await check;
    expect(files.sizes, isEmpty);
  });
}
