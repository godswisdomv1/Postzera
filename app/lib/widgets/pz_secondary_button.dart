import 'package:flutter/widgets.dart';
import 'package:postzera/theme/pz_motion.dart';
import 'package:postzera/theme/pz_radii.dart';
import 'package:postzera/theme/pz_sizes.dart';
import 'package:postzera/theme/pz_theme.dart';
import 'package:postzera/widgets/foundation/pz_button_content.dart';
import 'package:postzera/widgets/foundation/pz_icons.dart';
import 'package:postzera/widgets/foundation/pz_pressable.dart';

/// The bordered button, for actions that are not the primary one. Outlined
/// always means secondary.
class PzSecondaryButton extends StatelessWidget {
  const PzSecondaryButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.busy = false,
    this.fullWidth = true,
    this.destructive = false,
    this.semanticLabel,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final PzIconData? icon;
  final bool busy;
  final bool fullWidth;

  /// Draws the label in the error color, for deleting things.
  final bool destructive;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final PzThemeData theme = PzTheme.of(context);
    final bool disabled = onPressed == null;
    return PzPressable(
      onTap: busy ? null : onPressed,
      semanticLabel: semanticLabel,
      builder: (BuildContext context, PzPressState state) {
        return Opacity(
          opacity: disabled ? PzMotion.disabledOpacity : 1,
          child: AnimatedScale(
            scale: state.pressed ? PzMotion.pressScale : 1,
            duration: PzMotion.resolve(context, PzMotion.press),
            curve: PzMotion.easeOut,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: state.pressed ? theme.colors.bgTertiary : null,
                borderRadius: PzRadii.buttonRadius,
                border: Border.all(
                  color: theme.colors.borderSubtle,
                  width: PzSizes.hairline,
                ),
              ),
              child: PzButtonContent(
                label: label,
                style: theme.text.callout,
                color: destructive
                    ? theme.colors.error
                    : theme.colors.textPrimary,
                fullWidth: fullWidth,
                busy: busy,
                icon: icon,
              ),
            ),
          ),
        );
      },
    );
  }
}
