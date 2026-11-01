import 'package:flutter/widgets.dart';
import 'package:postzera/theme/pz_radii.dart';
import 'package:postzera/theme/pz_sizes.dart';
import 'package:postzera/theme/pz_theme.dart';

/// A circle holding the one or two letters that stand for a platform. It uses
/// no third-party logo and no brand color.
class PzPlatformMark extends StatelessWidget {
  const PzPlatformMark({
    required this.monogram,
    this.size = 32,
    this.name,
    super.key,
  }) : assert(size == 32 || size == 40, 'The mark is 32 or 40 px.');

  final String monogram;

  /// 32 or 40.
  final double size;

  /// Read aloud as the platform's name. Without it the mark is decoration.
  final String? name;

  @override
  Widget build(BuildContext context) {
    final PzThemeData theme = PzTheme.of(context);
    final Widget mark = DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colors.bgTertiary,
        borderRadius: PzRadii.pill(size),
        border: Border.all(
          color: theme.colors.borderSubtle,
          width: PzSizes.hairline,
        ),
      ),
      child: SizedBox.square(
        dimension: size,
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(monogram, style: theme.text.callout),
          ),
        ),
      ),
    );
    return Semantics(
      label: name,
      image: name != null,
      child: ExcludeSemantics(child: mark),
    );
  }
}
