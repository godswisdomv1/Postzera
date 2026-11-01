import 'package:flutter/widgets.dart';
import 'package:postzera/core/models/app_error.dart';
import 'package:postzera/theme/pz_sizes.dart';
import 'package:postzera/theme/pz_spacing.dart';
import 'package:postzera/theme/pz_theme.dart';
import 'package:postzera/widgets/foundation/pz_icon.dart';
import 'package:postzera/widgets/foundation/pz_icons.dart';
import 'package:postzera/widgets/pz_primary_button.dart';
import 'package:postzera/widgets/pz_secondary_button.dart';

/// An error laid out as an icon, a title, a message and up to two actions.
/// Retry is offered only for an error that can be retried. The caller
/// supplies the localized words.
///
/// With [fatal] it fills its space with the page color and works even above
/// the app's theme, so the error widget never shows a grey screen.
class PzErrorView extends StatelessWidget {
  const PzErrorView({
    required this.error,
    required this.title,
    required this.message,
    this.retryLabel,
    this.onRetry,
    this.supportLabel,
    this.onSupport,
    this.fatal = false,
    super.key,
  });

  final AppError error;
  final String title;
  final String message;
  final String? retryLabel;
  final VoidCallback? onRetry;
  final String? supportLabel;
  final VoidCallback? onSupport;
  final bool fatal;

  @override
  Widget build(BuildContext context) {
    final PzThemeData theme = PzTheme.maybeOf(context) ?? PzThemeData.light;
    final VoidCallback? retry = onRetry;
    final VoidCallback? support = onSupport;
    final String? shownRetry = retryLabel;
    final String? shownSupport = supportLabel;
    Widget content = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: PzSpacing.contentMaxWidth),
        child: Padding(
          padding: const EdgeInsets.all(PzSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              PzIcon(
                PzIcons.error,
                size: PzSizes.iconHero,
                color: theme.colors.error,
              ),
              const SizedBox(height: PzSpacing.md),
              Text(title, textAlign: TextAlign.center, style: theme.text.title1),
              const SizedBox(height: PzSpacing.sm),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.text.body.copyWith(
                  color: theme.colors.textSecondary,
                ),
              ),
              if (error.retriable &&
                  retry != null &&
                  shownRetry != null) ...<Widget>[
                const SizedBox(height: PzSpacing.lg),
                PzPrimaryButton(label: shownRetry, onPressed: retry),
              ],
              if (support != null && shownSupport != null) ...<Widget>[
                const SizedBox(height: PzSpacing.sm),
                PzSecondaryButton(label: shownSupport, onPressed: support),
              ],
            ],
          ),
        ),
      ),
    );
    if (!fatal) {
      return content;
    }
    content = ColoredBox(color: theme.colors.bgPrimary, child: content);
    content = DefaultTextStyle(style: theme.text.body, child: content);
    content = PzTheme(data: theme, child: content);
    if (Directionality.maybeOf(context) == null) {
      content = Directionality(textDirection: TextDirection.ltr, child: content);
    }
    return content;
  }
}
