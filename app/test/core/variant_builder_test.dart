import 'package:flutter_test/flutter_test.dart';
import 'package:postzera/core/data/builtin_card_themes.dart';
import 'package:postzera/core/data/default_profiles.dart';
import 'package:postzera/core/models/app_error.dart';
import 'package:postzera/core/models/platform_profile.dart';
import 'package:postzera/core/models/variant.dart';
import 'package:postzera/core/services/variant_builder.dart';

import 'test_helpers.dart';

void main() {
  const VariantBuilder builder = VariantBuilder();

  test('one post gives nine variants in display order', () {
    final List<Variant> variants = builder.buildAll(
      testPost(hook: 'Hello', body: 'Body', cta: 'Go'),
      defaultProfiles(),
      cardThemeById('paper'),
    );
    expect(variants.map((Variant v) => v.platformId).toList(), <String>[
      'x',
      'instagram',
      'facebook',
      'linkedin',
      'tiktok',
      'pinterest',
      'reddit',
      'medium',
      'quora',
    ]);
  });

  test('disabled platforms are skipped', () {
    final List<PlatformProfile> profiles = defaultProfiles()
        .map(
          (PlatformProfile p) =>
              p.id == 'tiktok' ? p.copyWith(enabled: false) : p,
        )
        .toList();
    final List<Variant> variants = builder.buildAll(
      testPost(),
      profiles,
      cardThemeById('paper'),
    );
    expect(variants.length, 8);
    expect(variants.any((Variant v) => v.platformId == 'tiktok'), isFalse);
  });

  test('an empty hook cannot be built', () {
    expect(
      () => builder.buildAll(
        testPost(hook: '   '),
        defaultProfiles(),
        cardThemeById('paper'),
      ),
      throwsA(
        isA<AppError>().having(
          (AppError e) => e.kind,
          'kind',
          AppErrorKind.validation,
        ),
      ),
    );
  });

  test('the hashtag cap of each platform is applied', () {
    final List<String> tags = List<String>.generate(40, (int i) => 'tag$i');
    final Variant instagram = builder.build(
      testPost(tags: tags),
      profileById('instagram'),
      cardThemeById('paper'),
    );
    final Variant x = builder.build(
      testPost(tags: tags),
      profileById('x'),
      cardThemeById('paper'),
    );
    expect('#'.allMatches(instagram.caption).length, 30);
    expect('#'.allMatches(x.caption).length, 2);
    expect(instagram.warnings, contains(VariantWarning.hashtagsDropped));
    expect(x.warnings, contains(VariantWarning.hashtagsDropped));
  });

  test('card text that had to be shortened is flagged', () {
    final Variant v = builder.build(
      testPost(body: words(60)),
      profileById('instagram'),
      cardThemeById('paper'),
    );
    expect(v.warnings, contains(VariantWarning.cardTextShortened));
  });

  test('the media plan carries the platform canvas and the chosen theme', () {
    final Variant v = builder.build(
      testPost(),
      profileById('pinterest'),
      cardThemeById('ink'),
    );
    expect(v.mediaPlan.spec.widthPx, 1000);
    expect(v.mediaPlan.spec.heightPx, 1500);
    expect(v.mediaPlan.theme.id, 'ink');
  });

  test('the same post builds the same variants twice', () {
    final List<Variant> a = builder.buildAll(
      testPost(hook: 'Hello', body: 'Body'),
      defaultProfiles(),
      cardThemeById('paper'),
    );
    final List<Variant> b = builder.buildAll(
      testPost(hook: 'Hello', body: 'Body'),
      defaultProfiles(),
      cardThemeById('paper'),
    );
    expect(a, b);
  });
}
