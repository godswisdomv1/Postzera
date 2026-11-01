import 'package:flutter/widgets.dart';
import 'package:postzera/theme/pz_motion.dart';
import 'package:postzera/theme/pz_radii.dart';
import 'package:postzera/theme/pz_sizes.dart';
import 'package:postzera/theme/pz_theme.dart';
import 'package:postzera/widgets/foundation/pz_icon.dart';
import 'package:postzera/widgets/foundation/pz_icons.dart';
import 'package:postzera/widgets/foundation/pz_pressable.dart';

/// The 40 x 40 chip that holds an icon. With an [onTap] it is a button with a
/// 48 dp target and needs a [semanticLabel]; without one it is decoration.
class PzIconChip extends StatelessWidget {
  const PzIconChip({
    required this.icon,
    this.onTap,
    this.semanticLabel,
    this.iconSize = PzSizes.iconNav,
    this.strokeWidth = PzSizes.strokeNav,
    this.color,
    super.key,
  }) : assert(
         onTap == null || semanticLabel != null,
         'A tappable icon chip needs a semantic label.',
       );

  final PzIconData icon;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final double iconSize;
  final double strokeWidth;

  /// Defaults to the primary text color.
  final Color? color;

  Widget _body(BuildContext context, {required double opacity}) {
    final PzThemeData theme = PzTheme.of(context);
    return AnimatedOpacity(
      opacity: opacity,
      duration: PzMotion.resolve(context, PzMotion.press),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colors.bgSecondary,
          borderRadius: PzRadii.pill(PzSizes.iconChip),
          border: Border.all(
            color: theme.colors.borderSubtle,
            width: PzSizes.hairline,
          ),
        ),
        child: SizedBox.square(
          dimension: PzSizes.iconChip,
          child: Center(
            child: PzIcon(
              icon,
              size: iconSize,
              strokeWidth: strokeWidth,
              color: color,
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
      focusRadius: PzRadii.pill(PzSizes.iconChip),
      builder: (BuildContext context, PzPressState state) =>
          _body(context, opacity: state.pressed ? PzMotion.pressedOpacity : 1),
    );
  }
}
