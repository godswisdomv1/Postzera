import 'package:flutter_test/flutter_test.dart';
import 'package:postzera/core/data/builtin_card_themes.dart';
import 'package:postzera/core/data/default_profiles.dart';
import 'package:postzera/core/models/app_error.dart';
import 'package:postzera/core/models/media_source.dart';
import 'package:postzera/core/models/media_spec.dart';
import 'package:postzera/core/models/platform_profile.dart';
import 'package:postzera/core/models/post.dart';

void main() {
  group('AppError', () {
    test('every kind has a message key matching its ARB name', () {
      for (final AppErrorKind kind in AppErrorKind.values) {
        expect(AppError.of(kind).messageKey, 'error_${kind.name}');
      }
    });

    test('flags follow the blueprint table', () {
      final AppError full = AppError.of(AppErrorKind.storageFull);
      expect(full.recoverable, isTrue);
      expect(full.retriable, isTrue);
      expect(full.cause, AppErrorCause.system);
      final AppError down = AppError.of(AppErrorKind.dbDowngrade);
      expect(down.recoverable, isFalse);
      expect(down.retriable, isFalse);
      expect(AppError.of(AppErrorKind.validation).cause, AppErrorCause.user);
    });
  });

  group('built-in data', () {
    test('six card themes with paper as the default', () {
      expect(builtinCardThemes.map((t) => t.id).toList(), <String>[
        'paper',
        'ink',
        'seed',
        'sand',
        'midnight',
        'signal',
      ]);
      expect(cardThemeById(defaultCardThemeId).name, 'Paper');
      expect(cardThemeById('missing').id, 'paper');
    });

    test('nine default profiles in display order', () {
      final List<PlatformProfile> profiles = defaultProfiles();
      expect(profiles.map((p) => p.id).toList(), <String>[
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
      expect(profiles.map((p) => p.sortOrder).toList(), <int>[
        0,
        1,
        2,
        3,
        4,
        5,
        6,
        7,
        8,
      ]);
      expect(profiles.every((p) => p.enabled && !p.isCustom), isTrue);
    });

    test('limits and shapes match section 7', () {
      final Map<String, PlatformProfile> by = <String, PlatformProfile>{
        for (final PlatformProfile p in defaultProfiles()) p.id: p,
      };
      expect(by['x']!.captionLimit, 280);
      expect(by['x']!.countingScheme, CountingScheme.x);
      expect(by['x']!.media.widthPx, 1600);
      expect(by['instagram']!.captionLimit, 2200);
      expect(by['instagram']!.maxHashtags, 30);
      expect(by['tiktok']!.preferredKind, PreferredKind.video);
      expect(by['tiktok']!.media.aspect, MediaAspect.ratio9x16);
      expect(by['pinterest']!.titleLimit, 100);
      expect(by['pinterest']!.media.heightPx, 1500);
      expect(by['reddit']!.captionLimit, 40000);
      expect(by['reddit']!.titleLimit, 300);
      expect(by['medium']!.titleLimit, 100);
      expect(by['quora']!.titleLimit, 150);
    });
  });

  group('media geometry', () {
    test('9:16 uses the combined safe window', () {
      final SafeInsets s = SafeInsets.forCanvas(
        MediaAspect.ratio9x16,
        1080,
        1920,
      );
      expect(s, const SafeInsets(top: 270, bottom: 672, left: 64, right: 227));
      expect(1080 - s.left - s.right, 789);
      expect(1920 - s.top - s.bottom, 978);
    });

    test('other shapes use 6% margins', () {
      final SafeInsets s = SafeInsets.forCanvas(
        MediaAspect.ratio4x5,
        1080,
        1350,
      );
      expect(s.left, 65);
      expect(s.top, 81);
    });
  });

  group('Post', () {
    final Post post = Post(
      id: 'abc',
      hook: 'Hello',
      body: 'Body',
      hashtags: const <String>['#a', '#b'],
      mediaSource: const MediaSource(
        kind: MediaSourceKind.video,
        path: '/x/y.mp4',
        durationMs: 5000,
      ),
      cardThemeId: 'ink',
      scheduledAt: DateTime.utc(2026, 10, 20, 9),
      status: PostStatus.scheduled,
      createdAt: DateTime.utc(2026, 10, 18),
      updatedAt: DateTime.utc(2026, 10, 19),
    );

    test('survives a JSON round trip', () {
      expect(Post.fromJson(post.toJson()), post);
    });

    test('copyWith can clear the schedule', () {
      expect(post.copyWith(clearScheduledAt: true).scheduledAt, isNull);
      expect(post.copyWith(hook: 'New').hook, 'New');
      expect(post.copyWith(hook: 'New').body, 'Body');
    });

    test('a damaged JSON value gives safe defaults instead of throwing', () {
      final Post p = Post.fromJson(<String, Object?>{
        'hook': 5,
        'status': 'nonsense',
        'hashtags': 'x',
      });
      expect(p.hook, '');
      expect(p.status, PostStatus.draft);
      expect(p.hashtags, isEmpty);
      expect(p.cardThemeId, 'paper');
    });
  });
}
