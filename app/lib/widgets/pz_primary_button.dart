import 'package:flutter/widgets.dart';
import 'package:postzera/theme/pz_motion.dart';
import 'package:postzera/theme/pz_radii.dart';
import 'package:postzera/theme/pz_theme.dart';
import 'package:postzera/widgets/foundation/pz_button_content.dart';
import 'package:postzera/widgets/foundation/pz_icons.dart';
import 'package:postzera/widgets/foundation/pz_pressable.dart';

/// The filled accent button, for the one primary action of a screen. Pressing
/// it darkens it and scales it to 97%. A null [onPressed] disables it, and
/// [busy] shows a spinner and ignores taps.
class PzPrimaryButton extends StatelessWidget {
  const PzPrimaryButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.busy = false,
    this.fullWidth = true,
    this.semanticLabel,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final PzIconData? icon;
  final bool busy;
  final bool fullWidth;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final PzThemeData theme = PzTheme.of(context);
    final bool disabled = onPressed == null;
    return PzPressable(
      onTap: busy ? null : onPressed,
      haptic: true,
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
                color: state.pressed
                    ? theme.colors.accentDim
                    : theme.colors.accent,
                borderRadius: PzRadii.buttonRadius,
              ),
              child: PzButtonContent(
                label: label,
                style: theme.text.callout,
                color: theme.colors.onAccent,
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
