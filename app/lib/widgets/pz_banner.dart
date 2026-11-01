import 'package:flutter/widgets.dart';
import 'package:postzera/core/models/app_error.dart';
import 'package:postzera/core/providers/banner_provider.dart';
import 'package:postzera/core/providers/undo_provider.dart';
import 'package:postzera/l10n/app_localizations.dart';
import 'package:postzera/l10n/localized_text.dart';
import 'package:postzera/theme/pz_motion.dart';
import 'package:postzera/theme/pz_radii.dart';
import 'package:postzera/theme/pz_sizes.dart';
import 'package:postzera/theme/pz_spacing.dart';
import 'package:postzera/theme/pz_theme.dart';
import 'package:postzera/widgets/foundation/pz_icon.dart';
import 'package:postzera/widgets/foundation/pz_icons.dart';
import 'package:postzera/widgets/foundation/pz_pressable.dart';

/// Shows the app's feedback banners under the navigation bar: sticky ones
/// that stay until the problem is gone, and either an undo banner or the
/// latest transient one. Each is an icon plus words, announced to screen
/// readers, never color alone.
class PzBannerHost extends StatelessWidget {
  const PzBannerHost({
    required this.banners,
    required this.undo,
    required this.child,
    this.onRetry,
    super.key,
  });

  final BannerProvider banners;
  final UndoProvider undo;

  /// Called when the user taps Retry on a banner whose error can be retried.
  final void Function(BannerItem item)? onRetry;

  /// The app below the banners.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final double top = MediaQuery.paddingOf(context).top + PzSizes.navBarHeight;
    return Stack(
      children: <Widget>[
        child,
        Positioned(
          top: top,
          left: 0,
          right: 0,
          child: ListenableBuilder(
            listenable: Listenable.merge(<Listenable>[banners, undo]),
            builder: (BuildContext context, Widget? _) {
              final AppLocalizations l10n = AppLocalizations.of(context);
              final BannerState state = banners.value;
              final UndoAction? action = undo.value;
              final BannerItem? transient = state.transient;
              final List<Widget> shown = <Widget>[
                for (final BannerItem item in state.sticky)
                  _BannerCard(
                    key: ValueKey<String>(item.id),
                    kind: item.kind,
                    text: bannerText(l10n, item),
                    retry: _retryFor(item),
                  ),
                if (action != null)
                  _BannerCard(
                    key: ValueKey<String>('undo-${action.label.name}'),
                    kind: BannerKind.success,
                    text: undoText(l10n, action.label),
                    actionLabel: l10n.common_undo,
                    onAction: () => undo.undo(),
                  )
                else if (transient != null)
                  _BannerCard(
                    key: ValueKey<String>(transient.id),
                    kind: transient.kind,
                    text: bannerText(l10n, transient),
                    retry: _retryFor(transient),
                  ),
              ];
              if (shown.isEmpty) {
                return const SizedBox.shrink();
              }
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: PzSpacing.contentMaxWidth,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: PzSpacing.screenPadding,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: shown,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  VoidCallback? _retryFor(BannerItem item) {
    final AppError? error = item.error;
    final void Function(BannerItem item)? retry = onRetry;
    if (error == null || !error.retriable || retry == null) {
      return null;
    }
    return () => retry(item);
  }
}

class _BannerCard extends StatelessWidget {
  const _BannerCard({
    required this.kind,
    required this.text,
    this.actionLabel,
    this.onAction,
    this.retry,
    super.key,
  });

  final BannerKind kind;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback? retry;

  @override
  Widget build(BuildContext context) {
    final PzThemeData theme = PzTheme.of(context);
    final PzIconData icon = switch (kind) {
      BannerKind.success => PzIcons.checkCircle,
      BannerKind.failure => PzIcons.error,
      BannerKind.warning => PzIcons.warning,
    };
    final Color tone = switch (kind) {
      BannerKind.success => theme.colors.success,
      BannerKind.failure => theme.colors.error,
      BannerKind.warning => theme.colors.warning,
    };
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String? action =
        actionLabel ?? (retry != null ? l10n.common_retry : null);
    final VoidCallback? onTap = onAction ?? retry;
    return Padding(
      padding: const EdgeInsets.only(top: PzSpacing.sm),
      child: Semantics(
        liveRegion: true,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colors.bgSecondary,
            borderRadius: PzRadii.cardRadius,
            border: Border.all(
              color: theme.colors.borderSubtle,
              width: PzSizes.hairline,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: PzSpacing.md,
              vertical: PzSpacing.xs,
            ),
            child: Row(
              children: <Widget>[
                PzIcon(icon, color: tone),
                const SizedBox(width: PzSpacing.sm),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: PzSpacing.sm),
                    child: Text(
                      text,
                      style: theme.text.footnote.copyWith(
                        color: theme.colors.textPrimary,
                      ),
                    ),
                  ),
                ),
                if (action != null && onTap != null)
                  PzPressable(
                    onTap: onTap,
                    builder: (BuildContext context, PzPressState state) {
                      return AnimatedOpacity(
                        opacity: state.pressed ? PzMotion.pressedOpacity : 1,
                        duration: PzMotion.resolve(context, PzMotion.press),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: PzSpacing.sm,
                          ),
                          child: Text(
                            action,
                            style: theme.text.callout.copyWith(
                              color: theme.colors.accent,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
