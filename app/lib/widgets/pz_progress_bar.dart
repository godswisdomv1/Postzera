import 'package:flutter/widgets.dart';
import 'package:postzera/theme/pz_radii.dart';
import 'package:postzera/theme/pz_sizes.dart';
import 'package:postzera/theme/pz_theme.dart';

/// A thin determinate bar in the accent color. [value] runs from 0 to 1 and
/// fills from the start edge, so it fills right to left in Arabic and Hebrew.
class PzProgressBar extends StatelessWidget {
  const PzProgressBar({required this.value, this.semanticLabel, super.key});

  final double value;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final PzThemeData theme = PzTheme.of(context);
    final double clamped = value.clamp(0, 1);
    return Semantics(
      label: semanticLabel,
      value: '${(clamped * 100).round()}%',
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colors.bgTertiary,
            borderRadius: PzRadii.pill(PzSizes.progressHeight),
          ),
          child: SizedBox(
            height: PzSizes.progressHeight,
            width: double.infinity,
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: FractionallySizedBox(
                widthFactor: clamped,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: theme.colors.accent,
                    borderRadius: PzRadii.pill(PzSizes.progressHeight),
                  ),
                  child: const SizedBox(height: PzSizes.progressHeight),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
