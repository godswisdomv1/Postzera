import 'package:flutter_test/flutter_test.dart';
import 'package:postzera/core/data/builtin_card_themes.dart';
import 'package:postzera/core/models/media_source.dart';
import 'package:postzera/core/models/media_spec.dart';
import 'package:postzera/core/models/platform_profile.dart';
import 'package:postzera/core/models/post.dart';
import 'package:postzera/core/models/variant.dart';
import 'package:postzera/core/services/media_planner.dart';

import 'test_helpers.dart';

void main() {
  const MediaPlanner planner = MediaPlanner();
  final theme = cardThemeById('paper');

  MediaPlanResult plan(Post post, PlatformProfile profile, {DateTime? mod}) =>
      planner.plan(post, profile, 'caption', theme: theme, sourceModified: mod);

  const MediaSource video = MediaSource(
    kind: MediaSourceKind.video,
    path: '/v/clip.mp4',
    durationMs: 12000,
  );
  const MediaSource photo =
      MediaSource(kind: MediaSourceKind.photo, path: '/v/pic.jpg');

  group('fnv1a64Hex', () {
    test('matches the published test vectors', () {
      expect(fnv1a64Hex(''), 'cbf29ce484222325');
      expect(fnv1a64Hex('a'), 'af63dc4c8601ec8c');
      expect(fnv1a64Hex('foobar'), '85944171f73967e8');
    });
  });

  group('kind', () {
    test('an auto source follows the platform preference', () {
      expect(plan(testPost(), profileById('x')).plan.kind, MediaOutputKind.image);
      expect(
        plan(testPost(), profileById('instagram')).plan.kind,
        MediaOutputKind.image,
      );
      expect(
        plan(testPost(), profileById('pinterest')).plan.kind,
        MediaOutputKind.image,
      );
      expect(
        plan(testPost(), profileById('tiktok')).plan.kind,
        MediaOutputKind.video,
      );
    });

    test('a photo gives an image, except on TikTok', () {
      expect(
        plan(testPost(media: photo), profileById('instagram')).plan.kind,
        MediaOutputKind.image,
      );
      expect(
        plan(testPost(media: photo), profileById('tiktok')).plan.kind,
        MediaOutputKind.video,
      );
    });

    test('a video source always gives a video', () {
      for (final String id in <String>['x', 'instagram', 'pinterest', 'tiktok']) {
        expect(
          plan(testPost(media: video), profileById(id)).plan.kind,
          MediaOutputKind.video,
          reason: id,
        );
      }
    });

    test('a photo or video with no file is treated as auto', () {
      const MediaSource lost = MediaSource(kind: MediaSourceKind.video);
      final MediaPlan p = plan(testPost(media: lost), profileById('x')).plan;
      expect(p.kind, MediaOutputKind.image);
      expect(p.sourceKind, MediaSourceKind.auto);
      expect(p.sourcePath, isNull);
    });

    test('the plan carries the source path and the clip length', () {
      final MediaPlan p = plan(testPost(media: video), profileById('x')).plan;
      expect(p.sourcePath, '/v/clip.mp4');
      expect(p.sourceDurationMs, 12000);
      expect(p.slides, isEmpty);
    });
  });

  group('text on the media', () {
    test('Instagram prints the hook and a body excerpt, no pill', () {
      final MediaPlan p = plan(
        testPost(hook: 'Hello', body: 'Body text', cta: 'Buy'),
        profileById('instagram'),
      ).plan;
      expect(p.blocks.map((CardTextBlock b) => b.role).toList(), <CardTextRole>[
        CardTextRole.hook,
        CardTextRole.body,
      ]);
    });

    test('Pinterest prints the hook and the call to action', () {
      final MediaPlan p = plan(
        testPost(hook: 'Hello', body: 'Body text', cta: 'Buy'),
        profileById('pinterest'),
      ).plan;
      expect(p.blocks.map((CardTextBlock b) => b.role).toList(), <CardTextRole>[
        CardTextRole.hook,
        CardTextRole.cta,
      ]);
    });

    test('a long body is cut with an ellipsis and flagged', () {
      final MediaPlanResult r = plan(
        testPost(body: words(60)),
        profileById('instagram'),
      );
      final String body = r.plan.blocks
          .firstWhere((CardTextBlock b) => b.role == CardTextRole.body)
          .text;
      expect(body.length, 220);
      expect(body, endsWith('…'));
      expect(r.cardTextShortened, isTrue);
    });

    test('a short body is untouched', () {
      final MediaPlanResult r = plan(
        testPost(body: 'Short'),
        profileById('instagram'),
      );
      expect(r.cardTextShortened, isFalse);
    });
  });

  group('slides', () {
    test('TikTok splits the body into slides of at most 150 characters', () {
      final MediaPlan p = plan(
        testPost(hook: 'Hook', body: words(60), cta: 'Buy now'),
        profileById('tiktok'),
      ).plan;
      expect(p.slides.length, 4);
      expect(
        p.slides.map((SlidePlan s) => s.blocks.single.role).toList(),
        <CardTextRole>[
          CardTextRole.hook,
          CardTextRole.body,
          CardTextRole.body,
          CardTextRole.cta,
        ],
      );
      expect(p.slides[1].blocks.single.text.length, 149);
      expect(p.slides[2].blocks.single.text.length, 149);
    });

    test('timing follows 1200 ms + 55 ms per character, 2.5 to 6 seconds', () {
      final MediaPlan p = plan(
        testPost(hook: 'Hook', body: words(60), cta: 'Buy now'),
        profileById('tiktok'),
      ).plan;
      expect(
        p.slides.map((SlidePlan s) => s.durationMs).toList(),
        <int>[3000, 6000, 6000, 3000],
      );
      expect(p.slidesDurationMs, 18000);

      final MediaPlan short = plan(
        testPost(hook: 'Hook', body: 'Short text here'),
        profileById('tiktok'),
      ).plan;
      expect(short.slides[1].durationMs, 2500);
    });

    test('there are never more than four body slides', () {
      final PlatformProfile unlimited = profileById('tiktok').copyWith(
        template: profileById('tiktok').template.copyWith(mediaBodyMaxChars: 0),
      );
      final MediaPlanResult r = plan(
        testPost(hook: 'Hook', body: words(400)),
        unlimited,
      );
      final int bodySlides = r.plan.slides
          .where((SlidePlan s) => s.blocks.single.role == CardTextRole.body)
          .length;
      expect(bodySlides, 4);
      expect(r.cardTextShortened, isTrue);
    });

    test('the total never exceeds the platform maximum', () {
      final PlatformProfile tenSeconds = profileById('tiktok').copyWith(
        media: MediaSpec.forAspect(MediaAspect.ratio9x16, maxVideoSeconds: 10),
      );
      final MediaPlan p = plan(
        testPost(hook: 'Hook', body: words(60), cta: 'Buy now'),
        tenSeconds,
      ).plan;
      expect(p.slidesDurationMs, lessThanOrEqualTo(10000));
      expect(
        p.slides.every((SlidePlan s) => s.durationMs > 0),
        isTrue,
      );
    });

    test('a photo source still gets slides, and keeps its path', () {
      final MediaPlan p = plan(
        testPost(hook: 'Hook', body: 'Body', media: photo),
        profileById('tiktok'),
      ).plan;
      expect(p.slides, isNotEmpty);
      expect(p.sourcePath, '/v/pic.jpg');
    });

    test('image variants have no slides', () {
      expect(plan(testPost(), profileById('instagram')).plan.slides, isEmpty);
    });
  });

  group('cache key', () {
    test('is 16 hex digits and stable', () {
      final String a = plan(testPost(), profileById('x')).plan.cacheKey;
      final String b = plan(testPost(), profileById('x')).plan.cacheKey;
      expect(a, b);
      expect(RegExp(r'^[0-9a-f]{16}$').hasMatch(a), isTrue);
    });

    test('changes with the text, the theme, the platform and the source file', () {
      final String base = plan(testPost(), profileById('x')).plan.cacheKey;
      expect(plan(testPost(hook: 'Other'), profileById('x')).plan.cacheKey, isNot(base));
      expect(
        planner
            .plan(testPost(), profileById('x'), 'caption', theme: cardThemeById('ink'))
            .plan
            .cacheKey,
        isNot(base),
      );
      expect(plan(testPost(), profileById('instagram')).plan.cacheKey, isNot(base));

      final String v1 = plan(
        testPost(media: video),
        profileById('x'),
        mod: DateTime.utc(2026, 10, 1),
      ).plan.cacheKey;
      final String v2 = plan(
        testPost(media: video),
        profileById('x'),
        mod: DateTime.utc(2026, 10, 2),
      ).plan.cacheKey;
      expect(v1, isNot(v2));
    });

    test('does not change with the post id or timestamps', () {
      final Post a = testPost();
      final Post b = a.copyWith(
        id: 'other',
        updatedAt: DateTime.utc(2030),
        status: PostStatus.scheduled,
      );
      expect(
        plan(a, profileById('x')).plan.cacheKey,
        plan(b, profileById('x')).plan.cacheKey,
      );
    });
  });
}
