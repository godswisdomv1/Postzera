import 'package:flutter/widgets.dart';
import 'package:postzera/core/models/card_theme.dart';
import 'package:postzera/theme/pz_radii.dart';
import 'package:postzera/theme/pz_sizes.dart';
import 'package:postzera/theme/pz_spacing.dart';
import 'package:postzera/theme/pz_theme.dart';
import 'package:postzera/widgets/foundation/pz_icon.dart';
import 'package:postzera/widgets/foundation/pz_icons.dart';
import 'package:postzera/widgets/foundation/pz_pressable.dart';

/// A selectable swatch of one card theme: its background with a sample of its
/// text color and its accent. Selected swatches get a thicker border and a
/// check, so the choice never rests on color alone.
class PzThemeSwatch extends StatelessWidget {
  const PzThemeSwatch({
    required this.theme,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final MediaCardTheme theme;
  final bool selected;
  final VoidCallback onTap;

  /// A type specimen, not a message, so it is never translated.
  static const String _specimen = 'Aa';

  @override
  Widget build(BuildContext context) {
    final PzThemeData app = PzTheme.of(context);
    final Color accent = Color(theme.accent);
    return Semantics(
      selected: selected,
      child: PzPressable(
        onTap: onTap,
        semanticLabel: theme.name,
        builder: (BuildContext context, PzPressState state) {
          return DecoratedBox(
            decoration: BoxDecoration(
              color: Color(theme.background),
              borderRadius: PzRadii.buttonRadius,
              border: Border.all(
                color: selected
                    ? app.colors.borderFocus
                    : app.colors.borderSubtle,
                width: selected ? PzSizes.stroke : PzSizes.hairline,
              ),
            ),
            child: SizedBox(
              width: PzSizes.swatchWidth,
              height: PzSizes.swatchHeight,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    _specimen,
                    style: app.text.title1.copyWith(color: Color(theme.text)),
                  ),
                  const SizedBox(width: PzSpacing.xs),
                  if (selected)
                    PzIcon(
                      PzIcons.check,
                      size: PzSizes.iconInline,
                      color: accent,
                    )
                  else
                    DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: accent,
                      ),
                      child: const SizedBox.square(
                        dimension: PzSizes.swatchDot,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
