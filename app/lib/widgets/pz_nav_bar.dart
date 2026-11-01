import 'package:flutter/widgets.dart';
import 'package:postzera/theme/pz_spacing.dart';
import 'package:postzera/theme/pz_theme.dart';
import 'package:postzera/widgets/foundation/pz_icon_chip.dart';
import 'package:postzera/widgets/foundation/pz_icons.dart';

/// One icon button at the right of the navigation bar.
@immutable
class PzNavAction {
  const PzNavAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final PzIconData icon;

  /// Read aloud. Required, because an icon alone says nothing.
  final String label;
  final VoidCallback onTap;
}

/// The bar at the top of every screen. A back chip or, on the queue screen
/// only, the wordmark sits at the start; the title follows; icon chips sit at
/// the end. It reserves the top safe area itself, and its content stays
/// within the 600 dp content width on wide screens.
class PzNavBar extends StatelessWidget {
  const PzNavBar({
    this.title,
    this.brand,
    this.onBack,
    this.backLabel,
    this.actions = const <PzNavAction>[],
    super.key,
  }) : assert(
         onBack == null || backLabel != null,
         'A back button needs a semantic label.',
       );

  final String? title;

  /// The wordmark, for the queue screen only.
  final String? brand;
  final VoidCallback? onBack;
  final String? backLabel;
  final List<PzNavAction> actions;

  @override
  Widget build(BuildContext context) {
    final PzThemeData theme = PzTheme.of(context);
    final String? shownTitle = title;
    final String? shownBrand = brand;
    final VoidCallback? back = onBack;
    final double top = MediaQuery.paddingOf(context).top;
    return Padding(
      padding: EdgeInsets.only(top: top),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: PzSpacing.contentMaxWidth,
            minHeight: 56,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: PzSpacing.screenPadding,
              vertical: PzSpacing.xs,
            ),
            child: Row(
              children: <Widget>[
                if (back != null) ...<Widget>[
                  PzIconChip(
                    icon: PzIcons.back(Directionality.of(context)),
                    semanticLabel: backLabel,
                    onTap: back,
                  ),
                  const SizedBox(width: PzSpacing.sm),
                ] else if (shownBrand != null)
                  Semantics(
                    header: true,
                    child: Text(shownBrand, style: theme.text.wordmark),
                  ),
                Expanded(
                  child: shownTitle == null
                      ? const SizedBox.shrink()
                      : Semantics(
                          header: true,
                          child: Text(
                            shownTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.text.title2,
                          ),
                        ),
                ),
                for (final PzNavAction action in actions) ...<Widget>[
                  const SizedBox(width: PzSpacing.sm),
                  PzIconChip(
                    icon: action.icon,
                    semanticLabel: action.label,
                    onTap: action.onTap,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
