import 'package:flutter/widgets.dart';
import 'package:postzera/theme/pz_radii.dart';
import 'package:postzera/theme/pz_sizes.dart';
import 'package:postzera/theme/pz_spacing.dart';
import 'package:postzera/theme/pz_theme.dart';
import 'package:postzera/widgets/foundation/pz_icon.dart';
import 'package:postzera/widgets/foundation/pz_icons.dart';
import 'package:postzera/widgets/foundation/pz_pressable.dart';

/// A transparent row: a leading icon, a label with an optional second line and
/// a trailing chevron or widget. Pressing it tints it.
class PzRow extends StatelessWidget {
  const PzRow({
    required this.label,
    this.subtitle,
    this.icon,
    this.trailing,
    this.showChevron,
    this.onTap,
    this.semanticLabel,
    this.destructive = false,
    this.padding = const EdgeInsets.symmetric(
      horizontal: PzSpacing.md,
      vertical: PzSpacing.sm,
    ),
    super.key,
  });

  final String label;
  final String? subtitle;
  final PzIconData? icon;

  /// Replaces the chevron.
  final Widget? trailing;

  /// Defaults to true for a tappable row without a [trailing] widget.
  final bool? showChevron;
  final VoidCallback? onTap;
  final String? semanticLabel;

  /// Draws the row in the error color, for deleting things.
  final bool destructive;
  final EdgeInsetsGeometry padding;

  Widget _content(BuildContext context, {required bool pressed}) {
    final PzThemeData theme = PzTheme.of(context);
    final Color labelColor = destructive
        ? theme.colors.error
        : theme.colors.textPrimary;
    final PzIconData? shownIcon = icon;
    final String? shownSubtitle = subtitle;
    final Widget? shownTrailing = trailing;
    final bool chevron =
        shownTrailing == null && (showChevron ?? onTap != null);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: pressed ? theme.colors.bgTertiary : null,
        borderRadius: PzRadii.buttonRadius,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: PzSizes.rowMinHeight),
        child: Padding(
          padding: padding,
          child: Row(
            children: <Widget>[
              if (shownIcon != null) ...<Widget>[
                PzIcon(shownIcon, color: labelColor),
                const SizedBox(width: PzSpacing.md),
              ],
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      label,
                      style: theme.text.title2.copyWith(color: labelColor),
                    ),
                    if (shownSubtitle != null)
                      Text(
                        shownSubtitle,
                        style: theme.text.footnote.copyWith(
                          color: theme.colors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              if (shownTrailing != null) ...<Widget>[
                const SizedBox(width: PzSpacing.sm),
                shownTrailing,
              ],
              if (chevron) ...<Widget>[
                const SizedBox(width: PzSpacing.sm),
                PzIcon(
                  PzIcons.forward(Directionality.of(context)),
                  size: PzSizes.iconChevron,
                  color: theme.colors.textTertiary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (onTap == null) {
      return _content(context, pressed: false);
    }
    return PzPressable(
      onTap: onTap,
      semanticLabel: semanticLabel,
      focusRadius: PzRadii.buttonRadius,
      builder: (BuildContext context, PzPressState state) =>
          _content(context, pressed: state.pressed),
    );
  }
}
