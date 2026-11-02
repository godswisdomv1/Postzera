import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:postzera/core/models/app_error.dart';
import 'package:postzera/core/models/variant.dart';
import 'package:postzera/core/providers/media_jobs_provider.dart';
import 'package:postzera/l10n/app_localizations.dart';
import 'package:postzera/l10n/localized_text.dart';
import 'package:postzera/theme/pz_radii.dart';
import 'package:postzera/theme/pz_sizes.dart';
import 'package:postzera/theme/pz_spacing.dart';
import 'package:postzera/theme/pz_theme.dart';
import 'package:postzera/utils/number_format.dart';
import 'package:postzera/widgets/foundation/pz_icon.dart';
import 'package:postzera/widgets/foundation/pz_icons.dart';
import 'package:postzera/widgets/pz_card.dart';
import 'package:postzera/widgets/pz_chip.dart';
import 'package:postzera/widgets/pz_loading_indicator.dart';
import 'package:postzera/widgets/pz_platform_mark.dart';
import 'package:postzera/widgets/pz_primary_button.dart';
import 'package:postzera/widgets/pz_progress_bar.dart';
import 'package:postzera/widgets/pz_secondary_button.dart';

/// One platform's result: the media at its true aspect ratio, the platform
/// mark and name, warning chips, a caption excerpt and, while the file is not
/// ready, its progress, or a retry and a plain-card fallback if it failed.
///
/// Until the file exists, the media area shows a live preview drawn from the
/// plan itself: the card theme's colors and the hook text.
class PzVariantCard extends StatelessWidget {
  const PzVariantCard({
    required this.variant,
    required this.platformName,
    required this.monogram,
    this.job,
    this.sent = false,
    this.onTap,
    this.onRetry,
    this.onUseAutoCard,
    super.key,
  });

  final Variant variant;
  final String platformName;
  final String monogram;

  /// The render job of this variant. Null means it has not started.
  final MediaJob? job;

  /// The platform was marked as posted.
  final bool sent;
  final VoidCallback? onTap;
  final VoidCallback? onRetry;
  final VoidCallback? onUseAutoCard;

  static String _warningText(AppLocalizations l, VariantWarning w) {
    return switch (w) {
      VariantWarning.captionTruncated => l.variant_warning_captionTruncated,
      VariantWarning.hashtagsDropped => l.variant_warning_hashtagsDropped,
      VariantWarning.linkMissing => l.variant_warning_linkMissing,
      VariantWarning.cardTextShortened => l.variant_warning_cardTextShortened,
    };
  }

  @override
  Widget build(BuildContext context) {
    final PzThemeData theme = PzTheme.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context);
    final MediaPlan plan = variant.mediaPlan;
    final double aspect = plan.spec.widthPx / plan.spec.heightPx;
    final MediaJob? current = job;
    final bool failed = current?.status == MediaJobStatus.failed;
    final bool busy =
        current != null &&
        (current.status == MediaJobStatus.queued ||
            current.status == MediaJobStatus.rendering);
    final AppError? error = current?.error;
    final bool isVideo = plan.kind == MediaOutputKind.video;
    final int? videoMs = isVideo
        ? (current?.result?.durationMs ?? plan.sourceDurationMs)
        : null;

    final Widget media = ClipRRect(
      borderRadius: PzRadii.buttonRadius,
      child: AspectRatio(
        aspectRatio: aspect,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            _Media(plan: plan, job: current),
            if (isVideo)
              PositionedDirectional(
                top: PzSpacing.sm,
                start: PzSpacing.sm,
                child: _VideoBadge(
                  label: videoMs == null || videoMs <= 0
                      ? null
                      : formatClock(videoMs),
                ),
              ),
            if (busy)
              PositionedDirectional(
                start: PzSpacing.sm,
                end: PzSpacing.sm,
                bottom: PzSpacing.sm,
                child: Row(
                  children: <Widget>[
                    const PzLoadingIndicator(
                      size: PzSizes.iconInline,
                      delay: Duration.zero,
                    ),
                    const SizedBox(width: PzSpacing.sm),
                    Expanded(
                      child: PzProgressBar(
                        value: current.progress,
                        semanticLabel: l10n.variant_rendering,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );

    return Semantics(
      label: platformName,
      child: PzCard(
        onTap: failed ? null : onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                PzPlatformMark(monogram: monogram, size: 40),
                const SizedBox(width: PzSpacing.md),
                Expanded(child: Text(platformName, style: theme.text.title2)),
                if (sent)
                  PzChip(
                    label: l10n.variant_posted,
                    tone: PzChipTone.success,
                  ),
              ],
            ),
            const SizedBox(height: PzSpacing.md),
            media,
            if (failed) ...<Widget>[
              const SizedBox(height: PzSpacing.md),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  PzIcon(
                    PzIcons.error,
                    size: PzSizes.iconInline,
                    color: theme.colors.error,
                  ),
                  const SizedBox(width: PzSpacing.sm),
                  Expanded(
                    child: Text(
                      error == null
                          ? l10n.error_renderFailed
                          : errorText(l10n, error),
                      style: theme.text.footnote.copyWith(
                        color: theme.colors.error,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: PzSpacing.sm),
              PzPrimaryButton(label: l10n.common_retry, onPressed: onRetry),
              const SizedBox(height: PzSpacing.sm),
              PzSecondaryButton(
                label: l10n.variant_useAutoCard,
                onPressed: onUseAutoCard,
              ),
            ],
            if (variant.warnings.isNotEmpty) ...<Widget>[
              const SizedBox(height: PzSpacing.md),
              Wrap(
                spacing: PzSpacing.sm,
                runSpacing: PzSpacing.sm,
                children: <Widget>[
                  for (final VariantWarning w in variant.warnings)
                    PzChip(
                      label: _warningText(l10n, w),
                      tone: PzChipTone.warning,
                    ),
                ],
              ),
            ],
            if (variant.caption.isNotEmpty) ...<Widget>[
              const SizedBox(height: PzSpacing.md),
              Text(
                variant.caption,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: theme.text.footnote.copyWith(
                  color: theme.colors.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Media extends StatelessWidget {
  const _Media({required this.plan, required this.job});

  final MediaPlan plan;
  final MediaJob? job;

  @override
  Widget build(BuildContext context) {
    final MediaJob? current = job;
    final bool readyImage =
        current?.status == MediaJobStatus.ready &&
        current?.result?.kind == MediaOutputKind.image;
    final Widget preview = _PlanPreview(plan: plan);
    if (!readyImage) {
      return preview;
    }
    final double pixelRatio = MediaQuery.devicePixelRatioOf(context);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return Image.file(
          File(current!.result!.path),
          fit: BoxFit.cover,
          gaplessPlayback: true,
          cacheWidth: (constraints.maxWidth * pixelRatio).round(),
          errorBuilder:
              (BuildContext context, Object error, StackTrace? stack) =>
                  preview,
        );
      },
    );
  }
}

/// A themed stand-in for the media, from the plan: its background color and
/// its hook text, scaled to fit.
class _PlanPreview extends StatelessWidget {
  const _PlanPreview({required this.plan});

  final MediaPlan plan;

  String _hook() {
    final List<CardTextBlock> blocks = plan.slides.isNotEmpty
        ? plan.slides.first.blocks
        : plan.blocks;
    for (final CardTextBlock b in blocks) {
      if (b.role == CardTextRole.hook) {
        return b.text;
      }
    }
    return blocks.isEmpty ? '' : blocks.first.text;
  }

  @override
  Widget build(BuildContext context) {
    final PzThemeData theme = PzTheme.of(context);
    return ColoredBox(
      color: Color(plan.theme.background),
      child: Padding(
        padding: const EdgeInsets.all(PzSpacing.md),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 260),
              child: Text(
                _hook(),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: theme.text.display.copyWith(
                  color: Color(plan.theme.text),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _VideoBadge extends StatelessWidget {
  const _VideoBadge({required this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    final PzThemeData theme = PzTheme.of(context);
    final String? shown = label;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colors.bgSecondary,
        borderRadius: PzRadii.pill(PzSizes.chipHeight),
        border: Border.all(
          color: theme.colors.borderSubtle,
          width: PzSizes.hairline,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: PzSpacing.sm,
          vertical: PzSpacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const PzIcon(PzIcons.video, size: PzSizes.iconInline),
            if (shown != null) ...<Widget>[
              const SizedBox(width: PzSpacing.xs),
              Text(shown, style: theme.text.counter),
            ],
          ],
        ),
      ),
    );
  }
}
