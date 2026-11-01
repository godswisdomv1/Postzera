import 'package:flutter/widgets.dart';
import 'package:postzera/theme/pz_motion.dart';
import 'package:postzera/theme/pz_radii.dart';
import 'package:postzera/theme/pz_sizes.dart';
import 'package:postzera/theme/pz_theme.dart';
import 'package:postzera/widgets/foundation/pz_pressable.dart';

/// An on/off toggle: accent when on. The target is 48 dp, the visible track is
/// 52 x 32. A null [onChanged] disables it.
class PzSwitch extends StatelessWidget {
  const PzSwitch({
    required this.value,
    required this.onChanged,
    required this.semanticLabel,
    super.key,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;

  /// Read aloud with the on/off state. Required.
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final PzThemeData theme = PzTheme.of(context);
    final ValueChanged<bool>? change = onChanged;
    final Duration duration = PzMotion.resolve(context, PzMotion.press);
    return Semantics(
      toggled: value,
      child: PzPressable(
        semanticLabel: semanticLabel,
        haptic: true,
        focusRadius: PzRadii.pill(PzSizes.switchHeight),
        onTap: change == null ? null : () => change(!value),
        builder: (BuildContext context, PzPressState state) {
          return Opacity(
            opacity: change == null ? PzMotion.disabledOpacity : 1,
            child: AnimatedContainer(
              duration: duration,
              curve: PzMotion.easeOut,
              width: PzSizes.switchWidth,
              height: PzSizes.switchHeight,
              padding: const EdgeInsets.all(
                (PzSizes.switchHeight - PzSizes.switchThumb) / 2,
              ),
              decoration: BoxDecoration(
                color: value ? theme.colors.accent : theme.colors.bgTertiary,
                borderRadius: PzRadii.pill(PzSizes.switchHeight),
                border: Border.all(
                  color: value
                      ? theme.colors.accent
                      : theme.colors.borderSubtle,
                  width: PzSizes.hairline,
                ),
              ),
              child: AnimatedAlign(
                duration: duration,
                curve: PzMotion.easeOut,
                alignment: value
                    ? AlignmentDirectional.centerEnd
                    : AlignmentDirectional.centerStart,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: value
                        ? theme.colors.onAccent
                        : theme.colors.textSecondary,
                  ),
                  child: const SizedBox.square(dimension: PzSizes.switchThumb),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
