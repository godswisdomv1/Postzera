import 'package:flutter/widgets.dart';
import 'package:postzera/theme/pz_sizes.dart';
import 'package:postzera/theme/pz_spacing.dart';
import 'package:postzera/theme/pz_theme.dart';
import 'package:postzera/widgets/foundation/pz_icon.dart';
import 'package:postzera/widgets/foundation/pz_icons.dart';

/// What a list shows when it has nothing: a 40 px icon, a title, an optional
/// line of explanation and an optional [action]. It is the content, so it is
/// never an empty box.
class PzEmptyState extends StatelessWidget {
  const PzEmptyState({
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
    super.key,
  });

  final PzIconData icon;
  final String title;
  final String? subtitle;

  /// Usually a primary button.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final PzThemeData theme = PzTheme.of(context);
    final String? shownSubtitle = subtitle;
    final Widget? shownAction = action;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // Centered when there is room; scrolls when large text or a short
        // space leaves none, so nothing is ever cut off.
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.hasBoundedHeight
                  ? constraints.maxHeight
                  : 0,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: PzSpacing.contentMaxWidth,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(PzSpacing.lg),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      PzIcon(
                        icon,
                        size: PzSizes.iconHero,
                        color: theme.colors.textTertiary,
                      ),
                      const SizedBox(height: PzSpacing.md),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: theme.text.title1,
                      ),
                      if (shownSubtitle != null) ...<Widget>[
                        const SizedBox(height: PzSpacing.sm),
                        Text(
                          shownSubtitle,
                          textAlign: TextAlign.center,
                          style: theme.text.footnote.copyWith(
                            color: theme.colors.textSecondary,
                          ),
                        ),
                      ],
                      if (shownAction != null) ...<Widget>[
                        const SizedBox(height: PzSpacing.lg),
                        shownAction,
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
