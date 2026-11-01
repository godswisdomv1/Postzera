import 'package:flutter/widgets.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:postzera/theme/pz_sizes.dart';
import 'package:postzera/theme/pz_theme.dart';
import 'package:postzera/widgets/foundation/pz_icons.dart';

/// Draws a semantic icon at a token size and stroke. Decorative unless it is
/// given a [semanticLabel].
class PzIcon extends StatelessWidget {
  const PzIcon(
    this.icon, {
    this.size = PzSizes.iconRow,
    this.strokeWidth = PzSizes.stroke,
    this.color,
    this.semanticLabel,
    super.key,
  });

  final PzIconData icon;
  final double size;
  final double strokeWidth;

  /// Defaults to the primary text color.
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final Widget drawn = ExcludeSemantics(
      child: HugeIcon(
        icon: icon,
        size: size,
        strokeWidth: strokeWidth,
        color: color ?? PzTheme.of(context).colors.textPrimary,
      ),
    );
    if (semanticLabel == null) {
      return drawn;
    }
    return Semantics(label: semanticLabel, image: true, child: drawn);
  }
}
