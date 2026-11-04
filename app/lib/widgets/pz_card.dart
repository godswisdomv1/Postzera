import 'package:flutter/widgets.dart';
import 'package:postzera/theme/pz_motion.dart';
import 'package:postzera/theme/pz_radii.dart';
import 'package:postzera/theme/pz_sizes.dart';
import 'package:postzera/theme/pz_spacing.dart';
import 'package:postzera/theme/pz_theme.dart';
import 'package:postzera/widgets/foundation/pz_icon.dart';
import 'package:postzera/widgets/foundation/pz_icon_chip.dart';
import 'package:postzera/widgets/foundation/pz_icons.dart';
import 'package:postzera/widgets/foundation/pz_pressable.dart';

/// A solid card with a hairline border and no shadow. Pressing it, when it
/// has an [onTap], dims it to 72% opacity.
class PzCard extends StatelessWidget {
  const PzCard({
    required this.child,
    this.onTap,
    this.semanticLabel,
    this.padding = const EdgeInsets.all(PzSizes.cardPadding),
    super.key,
  });

  /// A card with an optional leading icon chip, a label, a value and, when it
  /// can be tapped, a chevron.
  factory PzCard.summary({
    required String label,
    String? value,
    PzIconData? icon,
    VoidCallback? onTap,
    String? semanticLabel,
    Key? key,
  }) {
    return PzCard(
      key: key,
      onTap: onTap,
      semanticLabel: semanticLabel,
      child: _Summary(
        label: label,
        value: value,
        icon: icon,
        showChevron: onTap != null,
      ),
    );
  }

  final Widget child;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final EdgeInsetsGeometry padding;

  Widget _box(BuildContext context, {required double opacity}) {
    final PzThemeData theme = PzTheme.of(context);
    return AnimatedOpacity(
      opacity: opacity,
      duration: PzMotion.resolve(context, PzMotion.press),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colors.bgSecondary,
          borderRadius: PzRadii.cardRadius,
          border: Border.all(
            color: theme.colors.borderSubtle,
            width: PzSizes.hairline,
          ),
        ),
        child: Padding(padding: padding, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (onTap == null) {
      return _box(context, opacity: 1);
    }
    return PzPressable(
      onTap: onTap,
      semanticLabel: semanticLabel,
      focusRadius: PzRadii.cardRadius,
      builder: (BuildContext context, PzPressState state) =>
          _box(context, opacity: state.pressed ? PzMotion.pressedOpacity : 1),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.label,
    required this.value,
    required this.icon,
    required this.showChevron,
  });

  final String label;
  final String? value;
  final PzIconData? icon;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final PzThemeData theme = PzTheme.of(context);
    final String? shownValue = value;
    final PzIconData? shownIcon = icon;
    return Row(
      children: <Widget>[
        if (shownIcon != null) ...<Widget>[
          PzIconChip(
            icon: shownIcon,
            iconSize: PzSizes.iconRow,
            strokeWidth: PzSizes.stroke,
          ),
          const SizedBox(width: PzSpacing.md),
        ],
        // The label and the value share a line when they fit. When they do not
        // (large text, long words) the value drops under the label instead of
        // squeezing the label until it breaks in the middle of a word.
        Expanded(
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: PzSpacing.sm,
            runSpacing: PzSpacing.xs,
            children: <Widget>[
              Text(label, style: theme.text.title2),
              if (shownValue != null)
                Text(
                  shownValue,
                  style: theme.text.footnote.copyWith(
                    color: theme.colors.textSecondary,
                  ),
                ),
            ],
          ),
        ),
        if (showChevron) ...<Widget>[
          const SizedBox(width: PzSpacing.sm),
          PzIcon(
            PzIcons.forward(Directionality.of(context)),
            size: PzSizes.iconChevron,
            color: theme.colors.textTertiary,
          ),
        ],
      ],
    );
  }
}
