import 'package:flutter_test/flutter_test.dart';
import 'package:postzera/core/data/builtin_card_themes.dart';
import 'package:postzera/core/data/default_profiles.dart';
import 'package:postzera/core/models/app_settings.dart';
import 'package:postzera/core/models/card_theme.dart';
import 'package:postzera/core/models/entitlement.dart';
import 'package:postzera/core/models/media_source.dart';
import 'package:postzera/core/models/media_spec.dart';
import 'package:postzera/core/models/platform_profile.dart';
import 'package:postzera/core/models/platform_template.dart';
import 'package:postzera/core/models/post.dart';
import 'package:postzera/core/models/send_record.dart';

import 'test_helpers.dart';

/// Adds a field a future version might write.
Map<String, Object?> withFuture(Map<String, Object?> json) => <String, Object?>{
  ...json,
  'fieldFromTheFuture': <String>['x'],
};

void main() {
  test('MediaSource', () {
    for (final MediaSource s in <MediaSource>[
      const MediaSource.auto(),
      const MediaSource(kind: MediaSourceKind.photo, path: '/a.jpg'),
      const MediaSource(
        kind: MediaSourceKind.video,
        path: '/a.mp4',
        durationMs: 9000,
      ),
    ]) {
      expect(MediaSource.fromJson(s.toJson()), s);
      expect(MediaSource.fromJson(withFuture(s.toJson())), s);
    }
  });

  test('MediaCardTheme for all six built-in themes', () {
    for (final MediaCardTheme t in builtinCardThemes) {
      expect(MediaCardTheme.fromJson(t.toJson()), t);
      expect(MediaCardTheme.fromJson(withFuture(t.toJson())), t);
    }
  });

  test('MediaSpec and SafeInsets for every shape', () {
    for (final MediaAspect a in MediaAspect.values) {
      final MediaSpec spec = MediaSpec.forAspect(a, maxVideoSeconds: 45);
      expect(MediaSpec.fromJson(spec.toJson()), spec);
      expect(MediaSpec.fromJson(withFuture(spec.toJson())), spec);
      expect(SafeInsets.fromJson(spec.safeInsets.toJson()), spec.safeInsets);
    }
  });

  test('PlatformTemplate and TemplateBlock', () {
    const PlatformTemplate t = PlatformTemplate(
      blocks: <TemplateBlock>[
        TemplateBlock(slot: TemplateSlot.hook, required: true),
        TemplateBlock(
          slot: TemplateSlot.body,
          prefix: '> ',
          suffix: '!',
          maxChars: 100,
        ),
        TemplateBlock(slot: TemplateSlot.hashtags),
      ],
      joiner: '\n',
      titleSlot: TemplateSlot.hook,
      hashtagStyle: HashtagStyle.inline,
      trim: TrimStrategy.cutWords,
      mediaTextSlots: <TemplateSlot>[TemplateSlot.hook, TemplateSlot.cta],
      mediaBodyMaxChars: 77,
    );
    expect(PlatformTemplate.fromJson(t.toJson()), t);
    expect(PlatformTemplate.fromJson(withFuture(t.toJson())), t);
    for (final TemplateBlock b in t.blocks) {
      expect(TemplateBlock.fromJson(b.toJson()), b);
    }
  });

  test('a template without a title slot keeps it null', () {
    const PlatformTemplate t = PlatformTemplate(
      blocks: <TemplateBlock>[TemplateBlock(slot: TemplateSlot.hook)],
    );
    expect(PlatformTemplate.fromJson(t.toJson()).titleSlot, isNull);
  });

  test('all nine default PlatformProfiles', () {
    for (final PlatformProfile p in defaultProfiles()) {
      expect(PlatformProfile.fromJson(p.toJson()), p, reason: p.id);
      expect(PlatformProfile.fromJson(withFuture(p.toJson())), p);
    }
  });

  test('a custom PlatformProfile', () {
    final PlatformProfile p = PlatformProfile(
      id: 'custom-1',
      name: 'My site',
      monogram: 'MS',
      isCustom: true,
      enabled: false,
      sortOrder: 12,
      captionLimit: 400,
      titleLimit: 80,
      maxHashtags: 4,
      preferredKind: PreferredKind.video,
      countingScheme: CountingScheme.x,
      openUrl: 'https://example.com',
      template: const PlatformTemplate(
        blocks: <TemplateBlock>[TemplateBlock(slot: TemplateSlot.hook)],
      ),
      media: MediaSpec.forAspect(MediaAspect.ratio2x3),
    );
    expect(PlatformProfile.fromJson(p.toJson()), p);
  });

  test('Post with every field set', () {
    final Post p =
        testPost(
          hook: 'H',
          body: 'B',
          cta: 'C',
          link: 'https://example.com',
          tags: const <String>['#a'],
          media: const MediaSource(
            kind: MediaSourceKind.video,
            path: '/v.mp4',
            durationMs: 5000,
          ),
          theme: 'midnight',
        ).copyWith(
          status: PostStatus.scheduled,
          scheduledAt: DateTime.utc(2026, 11, 1, 9),
        );
    expect(Post.fromJson(p.toJson()), p);
    expect(Post.fromJson(withFuture(p.toJson())), p);
  });

  test('SendRecord', () {
    final SendRecord r = SendRecord(
      postId: 'p',
      platformId: 'x',
      status: SendStatus.done,
      doneAt: DateTime.utc(2026, 10, 18, 9),
    );
    expect(SendRecord.fromJson(r.toJson()), r);
    expect(SendRecord.fromJson(withFuture(r.toJson())), r);
    const SendRecord pending = SendRecord(
      postId: 'p',
      platformId: 'x',
      status: SendStatus.pending,
    );
    expect(SendRecord.fromJson(pending.toJson()), pending);
  });

  test('AppSettings', () {
    const AppSettings s = AppSettings(
      themeMode: ThemeModeSetting.dark,
      localeCode: 'ar',
      defaultCardThemeId: 'seed',
      remindersEnabled: false,
      reminderMinutes: 1200,
      onboardingDone: true,
    );
    expect(AppSettings.fromJson(s.toJson()), s);
    expect(AppSettings.fromJson(withFuture(s.toJson())), s);
    expect(
      AppSettings.fromJson(const <String, Object?>{}),
      const AppSettings(),
    );
  });

  test('AppSettings clamps a damaged reminder time', () {
    expect(
      AppSettings.fromJson(const <String, Object?>{'reminderMinutes': 99999})
          .reminderMinutes,
      1439,
    );
  });

  test('Entitlement', () {
    final Entitlement e = Entitlement(
      state: EntitlementState.pro,
      source: EntitlementSource.store,
      updatedAt: DateTime.utc(2026, 10, 18),
    );
    expect(Entitlement.fromJson(e.toJson()), e);
    expect(Entitlement.fromJson(withFuture(e.toJson())), e);
    expect(
      Entitlement.fromJson(const <String, Object?>{}).state,
      EntitlementState.unknown,
    );
  });

  test('every persisted model writes a schema version', () {
    expect(const MediaSource.auto().toJson()['schemaVersion'], 1);
    expect(testPost().toJson()['schemaVersion'], 1);
    expect(defaultProfiles().first.toJson()['schemaVersion'], 1);
    expect(const AppSettings().toJson()['schemaVersion'], 1);
  });
}
