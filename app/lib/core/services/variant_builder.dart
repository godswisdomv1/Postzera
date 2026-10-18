import 'package:postzera/core/models/app_error.dart';
import 'package:postzera/core/models/card_theme.dart';
import 'package:postzera/core/models/platform_profile.dart';
import 'package:postzera/core/models/post.dart';
import 'package:postzera/core/models/variant.dart';
import 'package:postzera/core/services/media_planner.dart';
import 'package:postzera/core/services/template_engine.dart';

/// Builds every platform's variant from one post.
class VariantBuilder {
  const VariantBuilder({
    this.engine = const TemplateEngine(),
    this.planner = const MediaPlanner(),
  });

  final TemplateEngine engine;
  final MediaPlanner planner;

  /// Builds the variant of one platform. A post with an empty hook cannot be
  /// built and throws an `AppError` of kind `validation`.
  Variant build(
    Post post,
    PlatformProfile profile,
    MediaCardTheme theme, {
    DateTime? sourceModified,
  }) {
    if (post.hook.trim().isEmpty) {
      throw AppError.of(AppErrorKind.validation, details: 'empty hook');
    }
    final TemplateResult text = engine.build(post, profile);
    final MediaPlanResult media = planner.plan(
      post,
      profile,
      text.caption,
      theme: theme,
      sourceModified: sourceModified,
    );
    return Variant(
      platformId: profile.id,
      caption: text.caption,
      title: text.title,
      mediaPlan: media.plan,
      warnings: <VariantWarning>{
        ...text.warnings,
        if (media.cardTextShortened) VariantWarning.cardTextShortened,
      },
    );
  }

  /// Builds a variant for each enabled profile, in display order.
  List<Variant> buildAll(
    Post post,
    List<PlatformProfile> profiles,
    MediaCardTheme theme, {
    DateTime? sourceModified,
  }) {
    final List<PlatformProfile> enabled = profiles
        .where((PlatformProfile p) => p.enabled)
        .toList()
      ..sort(
        (PlatformProfile a, PlatformProfile b) =>
            a.sortOrder.compareTo(b.sortOrder),
      );
    return <Variant>[
      for (final PlatformProfile p in enabled)
        build(post, p, theme, sourceModified: sourceModified),
    ];
  }
}
