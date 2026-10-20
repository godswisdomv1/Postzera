import 'dart:convert';

import 'package:characters/characters.dart';
import 'package:flutter/foundation.dart';
import 'package:postzera/core/models/card_theme.dart';
import 'package:postzera/core/models/media_source.dart';
import 'package:postzera/core/models/platform_profile.dart';
import 'package:postzera/core/models/platform_template.dart';
import 'package:postzera/core/models/post.dart';
import 'package:postzera/core/models/variant.dart';
import 'package:postzera/core/services/text_fitter.dart';

/// 64-bit FNV-1a hash of [input] (as UTF-8), written as 16 hex digits. Pure
/// Dart, so it is identical on every launch and every device.
String fnv1a64Hex(String input) {
  int hash = (0xcbf29ce4 << 32) | 0x84222325;
  for (final int byte in utf8.encode(input)) {
    hash ^= byte;
    hash = hash * 0x100000001b3;
  }
  final int high = (hash >>> 32) & 0xFFFFFFFF;
  final int low = hash & 0xFFFFFFFF;
  return high.toRadixString(16).padLeft(8, '0') +
      low.toRadixString(16).padLeft(8, '0');
}

/// A media plan and whether text had to be shortened to build it.
@immutable
class MediaPlanResult {
  const MediaPlanResult({required this.plan, required this.cardTextShortened});

  final MediaPlan plan;
  final bool cardTextShortened;
}

/// Decides, without touching a device, what media one platform gets.
class MediaPlanner {
  const MediaPlanner({this.fitter = const TextFitter()});

  final TextFitter fitter;

  /// Longest body text on one video slide, in characters.
  static const int slideBodyChars = 150;

  /// Most body slides in a text-card video.
  static const int maxBodySlides = 4;

  static const int hookSlideMs = 3000;
  static const int ctaSlideMs = 3000;
  static const int minBodySlideMs = 2500;
  static const int maxBodySlideMs = 6000;

  /// Plans the media for [post] on [profile]. [caption] is the finished
  /// caption and takes part in the cache key. Pass [sourceModified] (the
  /// source file's modification time) so an edited file is re-rendered.
  ///
  /// Kind rules: a video source always gives a video. Otherwise the profile's
  /// preferred kind decides, and "follow source" gives an image.
  MediaPlanResult plan(
    Post post,
    PlatformProfile profile,
    String caption, {
    required MediaCardTheme theme,
    DateTime? sourceModified,
  }) {
    final PlatformTemplate template = profile.template;
    final MediaSource source = post.mediaSource;
    final MediaSourceKind sourceKind = source.path == null
        ? MediaSourceKind.auto
        : source.kind;
    final MediaOutputKind kind = _resolveKind(
      profile.preferredKind,
      sourceKind,
    );

    bool shortened = false;
    final bool useHook = template.mediaTextSlots.contains(TemplateSlot.hook);
    final bool useBody = template.mediaTextSlots.contains(TemplateSlot.body);
    final bool useCta = template.mediaTextSlots.contains(TemplateSlot.cta);

    final String hook = useHook ? post.hook.trim() : '';
    String body = useBody ? post.body.trim() : '';
    final int bodyMax = template.mediaBodyMaxChars;
    if (body.isNotEmpty && bodyMax > 0) {
      final FitResult cut = fitter.fit(body, bodyMax, CountingScheme.plain);
      body = cut.text;
      shortened = shortened || cut.truncated;
    }
    final String cta = useCta ? post.cta.trim() : '';

    final List<CardTextBlock> blocks = <CardTextBlock>[
      if (hook.isNotEmpty) CardTextBlock(role: CardTextRole.hook, text: hook),
      if (body.isNotEmpty) CardTextBlock(role: CardTextRole.body, text: body),
      if (cta.isNotEmpty) CardTextBlock(role: CardTextRole.cta, text: cta),
    ];

    List<SlidePlan> slides = const <SlidePlan>[];
    if (kind == MediaOutputKind.video && sourceKind != MediaSourceKind.video) {
      final ({List<SlidePlan> slides, bool overflow}) built = _buildSlides(
        hook: hook,
        body: body,
        cta: cta,
        maxSeconds: profile.media.maxVideoSeconds,
      );
      slides = built.slides;
      shortened = shortened || built.overflow;
    }

    final String key = _cacheKey(
      kind: kind,
      profile: profile,
      theme: theme,
      caption: caption,
      blocks: blocks,
      slides: slides,
      sourceKind: sourceKind,
      source: source,
      sourceModified: sourceModified,
    );

    return MediaPlanResult(
      plan: MediaPlan(
        kind: kind,
        spec: profile.media,
        theme: theme,
        blocks: blocks,
        sourceKind: sourceKind,
        sourcePath: sourceKind == MediaSourceKind.auto ? null : source.path,
        sourceDurationMs: sourceKind == MediaSourceKind.video
            ? source.durationMs
            : null,
        slides: slides,
        cacheKey: key,
      ),
      cardTextShortened: shortened,
    );
  }

  static MediaOutputKind _resolveKind(
    PreferredKind preferred,
    MediaSourceKind source,
  ) {
    if (source == MediaSourceKind.video) {
      return MediaOutputKind.video;
    }
    return switch (preferred) {
      PreferredKind.video => MediaOutputKind.video,
      PreferredKind.image => MediaOutputKind.image,
      PreferredKind.followSource => MediaOutputKind.image,
    };
  }

  ({List<SlidePlan> slides, bool overflow}) _buildSlides({
    required String hook,
    required String body,
    required String cta,
    required int maxSeconds,
  }) {
    final List<SlidePlan> slides = <SlidePlan>[];
    bool overflow = false;

    if (hook.isNotEmpty) {
      slides.add(
        SlidePlan(
          blocks: <CardTextBlock>[
            CardTextBlock(role: CardTextRole.hook, text: hook),
          ],
          durationMs: hookSlideMs,
        ),
      );
    }

    if (body.isNotEmpty) {
      final ({List<String> chunks, bool overflow}) split = _splitBody(body);
      overflow = split.overflow;
      for (final String chunk in split.chunks) {
        slides.add(
          SlidePlan(
            blocks: <CardTextBlock>[
              CardTextBlock(role: CardTextRole.body, text: chunk),
            ],
            durationMs: _bodySlideMs(chunk.characters.length),
          ),
        );
      }
    }

    if (cta.isNotEmpty) {
      slides.add(
        SlidePlan(
          blocks: <CardTextBlock>[
            CardTextBlock(role: CardTextRole.cta, text: cta),
          ],
          durationMs: ctaSlideMs,
        ),
      );
    }

    // Cap the total length.
    final int cap = maxSeconds * 1000;
    final int total = slides.fold<int>(
      0,
      (int sum, SlidePlan s) => sum + s.durationMs,
    );
    if (total > cap && total > 0) {
      return (
        slides: <SlidePlan>[
          for (final SlidePlan s in slides)
            SlidePlan(
              blocks: s.blocks,
              durationMs: s.durationMs * cap ~/ total,
            ),
        ],
        overflow: overflow,
      );
    }
    return (slides: slides, overflow: overflow);
  }

  ({List<String> chunks, bool overflow}) _splitBody(String body) {
    final List<String> words = body
        .split(RegExp(r'\s+'))
        .where((String w) => w.isNotEmpty)
        .toList();
    final List<String> chunks = <String>[];
    String current = '';
    for (final String word in words) {
      final String candidate = current.isEmpty ? word : '$current $word';
      if (current.isEmpty || candidate.characters.length <= slideBodyChars) {
        current = candidate;
      } else {
        chunks.add(current);
        current = word;
      }
    }
    if (current.isNotEmpty) {
      chunks.add(current);
    }
    if (chunks.length > maxBodySlides) {
      final List<String> kept = chunks.sublist(0, maxBodySlides);
      kept[maxBodySlides - 1] = '${kept[maxBodySlides - 1]}…';
      return (chunks: kept, overflow: true);
    }
    return (chunks: chunks, overflow: false);
  }

  static int _bodySlideMs(int characters) {
    final int ms = 1200 + 55 * characters;
    if (ms < minBodySlideMs) {
      return minBodySlideMs;
    }
    if (ms > maxBodySlideMs) {
      return maxBodySlideMs;
    }
    return ms;
  }

  String _cacheKey({
    required MediaOutputKind kind,
    required PlatformProfile profile,
    required MediaCardTheme theme,
    required String caption,
    required List<CardTextBlock> blocks,
    required List<SlidePlan> slides,
    required MediaSourceKind sourceKind,
    required MediaSource source,
    required DateTime? sourceModified,
  }) {
    final String material = jsonEncode(<Object?>[
      'v1',
      kind.name,
      profile.media.toJson(),
      theme.toJson(),
      caption,
      <Object?>[
        for (final CardTextBlock b in blocks) <Object?>[b.role.name, b.text],
      ],
      <Object?>[
        for (final SlidePlan s in slides)
          <Object?>[
            s.durationMs,
            for (final CardTextBlock b in s.blocks)
              <Object?>[b.role.name, b.text],
          ],
      ],
      sourceKind.name,
      source.path,
      source.durationMs,
      sourceModified?.toUtc().millisecondsSinceEpoch,
    ]);
    return fnv1a64Hex(material);
  }
}
