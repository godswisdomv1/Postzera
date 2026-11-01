import 'package:flutter/widgets.dart';
import 'package:postzera/theme/pz_motion.dart';
import 'package:postzera/theme/pz_radii.dart';
import 'package:postzera/theme/pz_sizes.dart';
import 'package:postzera/theme/pz_spacing.dart';
import 'package:postzera/theme/pz_theme.dart';
import 'package:postzera/widgets/foundation/pz_icon.dart';
import 'package:postzera/widgets/foundation/pz_icons.dart';
import 'package:postzera/widgets/foundation/pz_pressable.dart';

/// What a status chip says. Status is always an icon plus a label, never a
/// color alone.
enum PzChipTone { neutral, success, warning, error }

/// A pill, 32 dp high. Selected chips get a check and an accent tint; status
/// chips get a matching icon.
class PzChip extends StatelessWidget {
  const PzChip({
    required this.label,
    this.icon,
    this.selected = false,
    this.tone = PzChipTone.neutral,
    this.onTap,
    this.semanticLabel,
    super.key,
  });

  final String label;
  final PzIconData? icon;
  final bool selected;
  final PzChipTone tone;
  final VoidCallback? onTap;
  final String? semanticLabel;

  Widget _body(BuildContext context, {required double opacity}) {
    final PzThemeData theme = PzTheme.of(context);
    final PzIconData? shownIcon =
        icon ??
        switch (tone) {
          PzChipTone.success => PzIcons.checkCircle,
          PzChipTone.warning => PzIcons.warning,
          PzChipTone.error => PzIcons.error,
          PzChipTone.neutral => selected ? PzIcons.check : null,
        };
    final Color foreground = switch (tone) {
      PzChipTone.success => theme.colors.success,
      PzChipTone.warning => theme.colors.warning,
      PzChipTone.error => theme.colors.error,
      PzChipTone.neutral =>
        selected ? theme.colors.textPrimary : theme.colors.textSecondary,
    };
    return AnimatedOpacity(
      opacity: opacity,
      duration: PzMotion.resolve(context, PzMotion.press),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected ? theme.accentTint : theme.colors.bgTertiary,
          borderRadius: PzRadii.pill(PzSizes.chipHeight),
          border: Border.all(
            color: selected ? theme.colors.accent : theme.colors.borderSubtle,
            width: PzSizes.hairline,
          ),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: PzSizes.chipHeight),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: PzSpacing.sm + PzSpacing.xs,
              vertical: PzSpacing.xs,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (shownIcon != null) ...<Widget>[
                  PzIcon(
                    shownIcon,
                    size: PzSizes.iconInline,
                    color: selected && tone == PzChipTone.neutral
                        ? theme.colors.accent
                        : foreground,
                  ),
                  const SizedBox(width: PzSpacing.xs),
                ],
                Flexible(
                  child: Text(
                    label,
                    style: theme.text.callout.copyWith(color: foreground),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (onTap == null) {
      return _body(context, opacity: 1);
    }
    return PzPressable(
      onTap: onTap,
      semanticLabel: semanticLabel,
      focusRadius: PzRadii.pill(PzSizes.chipHeight),
      builder: (BuildContext context, PzPressState state) =>
          _body(context, opacity: state.pressed ? PzMotion.pressedOpacity : 1),
    );
  }
}
