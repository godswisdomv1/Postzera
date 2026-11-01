import 'package:flutter/widgets.dart';
import 'package:postzera/theme/pz_radii.dart';
import 'package:postzera/theme/pz_sizes.dart';
import 'package:postzera/theme/pz_spacing.dart';
import 'package:postzera/theme/pz_theme.dart';
import 'package:postzera/widgets/foundation/pz_icon.dart';
import 'package:postzera/widgets/foundation/pz_icons.dart';
import 'package:postzera/widgets/foundation/pz_pressable.dart';

/// One choice of a segmented control.
@immutable
class PzSegment<T> {
  const PzSegment({required this.value, required this.label, this.icon});

  final T value;
  final String label;
  final PzIconData? icon;
}

/// A row of two to four choices of which exactly one is selected, for theme
/// mode and media source. Each segment has a 48 dp target.
class PzSegmentedControl<T> extends StatelessWidget {
  const PzSegmentedControl({
    required this.segments,
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final List<PzSegment<T>> segments;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final PzThemeData theme = PzTheme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colors.bgTertiary,
        borderRadius: PzRadii.buttonRadius,
      ),
      child: Padding(
        padding: const EdgeInsets.all(PzSpacing.xs),
        child: Row(
          children: <Widget>[
            for (final PzSegment<T> segment in segments)
              Expanded(
                child: Semantics(
                  selected: segment.value == selected,
                  child: PzPressable(
                    onTap: () => onChanged(segment.value),
                    haptic: true,
                    builder: (BuildContext context, PzPressState state) {
                      final bool on = segment.value == selected;
                      final PzIconData? icon = segment.icon;
                      return SizedBox(
                        width: double.infinity,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: on ? theme.colors.bgSecondary : null,
                            borderRadius: PzRadii.buttonRadius,
                            border: on
                                ? Border.all(
                                    color: theme.colors.borderSubtle,
                                    width: PzSizes.hairline,
                                  )
                                : null,
                          ),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              minHeight: PzSizes.touchTarget,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: PzSpacing.sm,
                                vertical: PzSpacing.xs,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: <Widget>[
                                  if (icon != null) ...<Widget>[
                                    PzIcon(
                                      icon,
                                      size: PzSizes.iconInline,
                                      color: on
                                          ? theme.colors.textPrimary
                                          : theme.colors.textSecondary,
                                    ),
                                    const SizedBox(width: PzSpacing.xs),
                                  ],
                                  Flexible(
                                    child: Text(
                                      segment.label,
                                      textAlign: TextAlign.center,
                                      style: theme.text.callout.copyWith(
                                        color: on
                                            ? theme.colors.textPrimary
                                            : theme.colors.textSecondary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
