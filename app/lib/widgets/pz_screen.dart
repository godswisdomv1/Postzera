import 'package:flutter/widgets.dart';
import 'package:postzera/theme/pz_spacing.dart';
import 'package:postzera/theme/pz_theme.dart';

/// The frame every screen shares: the page color, a navigation bar at the top,
/// the content filling the middle (centered and at most 600 dp wide), and an
/// optional fixed [bottom] area, such as the primary action, that sits on the
/// bottom safe area and moves up with the keyboard.
class PzScreen extends StatelessWidget {
  const PzScreen({
    required this.navBar,
    required this.body,
    this.bottom,
    super.key,
  });

  final Widget navBar;
  final Widget body;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    final PzThemeData theme = PzTheme.of(context);
    final MediaQueryData media = MediaQuery.of(context);
    final Widget? fixed = bottom;
    final double inset = media.viewInsets.bottom > media.padding.bottom
        ? media.viewInsets.bottom
        : media.padding.bottom;
    return ColoredBox(
      color: theme.colors.bgPrimary,
      child: Column(
        children: <Widget>[
          navBar,
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: PzSpacing.contentMaxWidth,
                ),
                child: body,
              ),
            ),
          ),
          if (fixed != null)
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: PzSpacing.contentMaxWidth,
                ),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    PzSpacing.screenPadding,
                    PzSpacing.sm,
                    PzSpacing.screenPadding,
                    inset + PzSpacing.sm,
                  ),
                  child: fixed,
                ),
              ),
            )
          else
            SizedBox(height: inset),
        ],
      ),
    );
  }
}
