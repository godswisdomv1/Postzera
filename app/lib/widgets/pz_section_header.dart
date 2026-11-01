import 'package:flutter/widgets.dart';
import 'package:postzera/theme/pz_spacing.dart';
import 'package:postzera/theme/pz_theme.dart';

/// A small uppercase, tracked heading for a group: 24 above and 8 below.
class PzSectionHeader extends StatelessWidget {
  const PzSectionHeader(this.text, {this.topSpacing = PzSpacing.lg, super.key});

  final String text;

  /// Space above. The first header of a screen can set it to zero.
  final double topSpacing;

  @override
  Widget build(BuildContext context) {
    final PzThemeData theme = PzTheme.of(context);
    return Semantics(
      header: true,
      child: Padding(
        padding: EdgeInsets.only(top: topSpacing, bottom: PzSpacing.sm),
        child: Text(
          text.toUpperCase(),
          style: theme.text.sectionHeader.copyWith(
            color: theme.colors.textTertiary,
          ),
        ),
      ),
    );
  }
}
