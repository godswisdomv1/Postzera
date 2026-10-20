import 'package:flutter_test/flutter_test.dart';
import 'package:postzera/core/data/builtin_card_themes.dart';
import 'package:postzera/core/models/media_source.dart';
import 'package:postzera/core/models/variant.dart';
import 'package:postzera/core/ports/video_composer_port.dart';
import 'package:postzera/core/services/variant_builder.dart';
import 'package:postzera/platform/media/video_composer.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

import '../core/test_helpers.dart';

void main() {
  const VariantBuilder builder = VariantBuilder();

  MediaPlan clipPlan({String platform = 'tiktok', int durationMs = 12000}) =>
      builder
          .build(
            testPost(
              hook: 'Hook',
              cta: 'Go',
              media: MediaSource(
                kind: MediaSourceKind.video,
                path: '/v/clip.mp4',
                durationMs: durationMs,
              ),
            ),
            profileById(platform),
            cardThemeById('paper'),
          )
          .mediaPlan;

  group('slide video', () {
    test(
      'has one frame per slide, held for its duration, covering the canvas',
      () {
        final MediaPlan plan = builder
            .build(
              testPost(hook: 'Hook', body: 'Body text', cta: 'Go'),
              profileById('tiktok'),
              cardThemeById('paper'),
            )
            .mediaPlan;
        final List<SlideFile> files = <SlideFile>[
          for (int i = 0; i < plan.slides.length; i++)
            SlideFile(path: '/s/$i.png', durationMs: plan.slides[i].durationMs),
        ];
        final StopMotionRenderData data = VideoComposer.slideData(
          files,
          plan.spec,
        );
        expect(data.frames.length, plan.slides.length);
        expect(
          data.frames
              .map((StopMotionFrame f) => f.duration!.inMilliseconds)
              .toList(),
          plan.slides.map((SlidePlan s) => s.durationMs).toList(),
        );
        expect(data.resolution!.width, 1080);
        expect(data.resolution!.height, 1920);
        expect(data.fit, StopMotionFit.cover);
        expect(data.bitrate, 8000000);
      },
    );
  });

  group('clip reframe', () {
    test('is a one-layer composition on exactly the canvas size', () {
      final MediaPlan plan = clipPlan();
      final VideoRenderData data = VideoComposer.reframeData(
        '/v/clip.mp4',
        plan,
        const <TimedOverlay>[],
        sourceMs: 12000,
      );
      expect(data.composition!.canvasSize!.width, 1080);
      expect(data.composition!.canvasSize!.height, 1920);
      expect(data.composition!.layers.length, 1);
      final SegmentTransform t = data.composition!.layers.single.transform!;
      expect(t.fit, SegmentFit.cover);
      expect(t.size!.width, 1080);
      expect(t.size!.height, 1920);
    });

    test('a clip within the limit is not trimmed', () {
      final VideoRenderData data = VideoComposer.reframeData(
        '/v/clip.mp4',
        clipPlan(),
        const <TimedOverlay>[],
        sourceMs: 12000,
      );
      expect(data.composition!.layers.single.clips.single.endTime, isNull);
    });

    test('a clip over 60 seconds is trimmed to 60', () {
      final VideoRenderData data = VideoComposer.reframeData(
        '/v/clip.mp4',
        clipPlan(durationMs: 90000),
        const <TimedOverlay>[],
        sourceMs: 90000,
      );
      expect(
        data.composition!.layers.single.clips.single.endTime,
        const Duration(seconds: 60),
      );
    });

    test('overlays become timed image layers the size of the canvas', () {
      final VideoRenderData data = VideoComposer.reframeData(
        '/v/clip.mp4',
        clipPlan(),
        const <TimedOverlay>[
          TimedOverlay(path: '/o/h.png', startMs: 0, endMs: 4000),
          TimedOverlay(path: '/o/c.png', startMs: 9000, endMs: 12000),
        ],
        sourceMs: 12000,
      );
      final List<ImageLayer> layers = data.imageLayers!;
      expect(layers.length, 2);
      expect(layers[0].startTime, Duration.zero);
      expect(layers[0].endTime, const Duration(seconds: 4));
      expect(layers[1].startTime, const Duration(seconds: 9));
      expect(layers[1].endTime, const Duration(seconds: 12));
      expect(layers[0].size!.width, 1080);
      expect(layers[0].size!.height, 1920);
    });
  });
}
