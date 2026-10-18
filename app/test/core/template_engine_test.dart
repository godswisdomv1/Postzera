import 'package:flutter_test/flutter_test.dart';
import 'package:postzera/core/data/default_profiles.dart';
import 'package:postzera/core/models/platform_profile.dart';
import 'package:postzera/core/models/post.dart';
import 'package:postzera/core/models/variant.dart';
import 'package:postzera/core/services/template_engine.dart';
import 'package:postzera/core/services/text_fitter.dart';

import 'test_helpers.dart';

void main() {
  const TemplateEngine engine = TemplateEngine();
  const TextFitter fitter = TextFitter();

  group('block order', () {
    test('Instagram prints hook, body, call to action, hashtags', () {
      final TemplateResult r = engine.build(
        testPost(
          hook: 'H',
          body: 'B',
          cta: 'C',
          tags: const <String>['x', '#y'],
        ),
        profileById('instagram'),
      );
      expect(r.caption, 'H\n\nB\n\nC\n\n#x #y');
      expect(r.warnings, isEmpty);
    });

    test('empty slots are skipped without leaving gaps', () {
      final TemplateResult r = engine.build(
        testPost(hook: 'H', cta: 'C', tags: const <String>['x']),
        profileById('instagram'),
      );
      expect(r.caption, 'H\n\nC\n\n#x');
    });

    test('X puts hashtags straight after the hook, then the link', () {
      final TemplateResult r = engine.build(
        testPost(
          hook: 'Hello world',
          link: 'https://example.com',
          tags: const <String>['a', 'b', 'c'],
        ),
        profileById('x'),
      );
      expect(r.caption, 'Hello world #a #b\n\nhttps://example.com');
      expect(r.warnings, contains(VariantWarning.hashtagsDropped));
    });

    test('platforms without hashtags ignore them', () {
      final TemplateResult r = engine.build(
        testPost(hook: 'H', body: 'B', tags: const <String>['a']),
        profileById('reddit'),
      );
      expect(r.caption, 'B');
      expect(r.warnings, isNot(contains(VariantWarning.hashtagsDropped)));
    });
  });

  group('titles', () {
    test('Reddit uses the hook as the title', () {
      final TemplateResult r = engine.build(
        testPost(hook: 'My title', body: 'Body text'),
        profileById('reddit'),
      );
      expect(r.title, 'My title');
      expect(r.caption, 'Body text');
    });

    test('a long title is cut to the limit', () {
      final TemplateResult r = engine.build(
        testPost(hook: 'a' * 350),
        profileById('reddit'),
      );
      expect(r.title!.length, 300);
      expect(r.title, endsWith('…'));
      expect(r.warnings, contains(VariantWarning.captionTruncated));
    });

    test('platforms without a title give none', () {
      final TemplateResult r = engine.build(
        testPost(hook: 'H'),
        profileById('instagram'),
      );
      expect(r.title, isNull);
    });
  });

  group('fitting', () {
    final String body = 'b' * 20;
    final Post post = testPost(
      hook: 'Hook',
      body: body,
      cta: 'Buy now',
      tags: const <String>['one'],
    );
    // Full caption: 4 + 2 + 20 + 2 + 7 + 2 + 4 = 41 characters.

    test('nothing is dropped when it fits', () {
      final TemplateResult r = engine.build(
        post,
        profileById('instagram').copyWith(captionLimit: 41),
      );
      expect(r.caption, 'Hook\n\n$body\n\nBuy now\n\n#one');
      expect(r.warnings, isEmpty);
    });

    test('hashtags go first', () {
      final TemplateResult r = engine.build(
        post,
        profileById('instagram').copyWith(captionLimit: 40),
      );
      expect(r.caption, 'Hook\n\n$body\n\nBuy now');
      expect(r.warnings, contains(VariantWarning.hashtagsDropped));
    });

    test('then the call to action', () {
      final TemplateResult r = engine.build(
        post,
        profileById('instagram').copyWith(captionLimit: 30),
      );
      expect(r.caption, 'Hook\n\n$body');
      expect(r.warnings, contains(VariantWarning.captionTruncated));
    });

    test('then the body, leaving only the hook', () {
      final TemplateResult r = engine.build(
        post,
        profileById('instagram').copyWith(captionLimit: 10),
      );
      expect(r.caption, 'Hook');
    });

    test('the hook is never dropped, only cut', () {
      final TemplateResult r = engine.build(
        testPost(hook: 'Hello wonderful world'),
        profileById('instagram').copyWith(captionLimit: 10),
      );
      expect(r.caption, 'Hello…');
      expect(r.warnings, contains(VariantWarning.captionTruncated));
    });

    test('Pinterest cuts the body and keeps hashtags and link', () {
      final TemplateResult r = engine.build(
        testPost(
          hook: 'H',
          body: words(1000),
          link: 'https://example.com',
          tags: const <String>['a', 'b'],
        ),
        profileById('pinterest'),
      );
      expect(r.caption.length, lessThanOrEqualTo(500));
      expect(r.caption, contains('#a #b'));
      expect(r.caption, endsWith('https://example.com'));
      expect(r.warnings, contains(VariantWarning.captionTruncated));
    });

    test('a missing link is flagged where the template has a link', () {
      final TemplateResult r = engine.build(
        testPost(hook: 'H', body: 'B'),
        profileById('pinterest'),
      );
      expect(r.warnings, contains(VariantWarning.linkMissing));
    });
  });

  group('every default profile', () {
    final Post long = testPost(
      hook: words(100),
      body: words(1500),
      cta: 'Join us today',
      link: 'https://example.com/path',
      tags: List<String>.generate(40, (int i) => 't$i'),
    );

    for (final PlatformProfile profile in defaultProfiles()) {
      test('${profile.id} stays within its caption limit', () {
        final TemplateResult r = engine.build(long, profile);
        expect(
          fitter.length(r.caption, profile.countingScheme),
          lessThanOrEqualTo(profile.captionLimit),
        );
        final int? titleLimit = profile.titleLimit;
        if (titleLimit != null) {
          expect(r.title!.length, lessThanOrEqualTo(titleLimit));
        }
      });
    }
  });
}
