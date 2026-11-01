import 'package:flutter/widgets.dart';
import 'package:postzera/theme/pz_sizes.dart';
import 'package:postzera/theme/pz_spacing.dart';
import 'package:postzera/widgets/foundation/pz_icon.dart';
import 'package:postzera/widgets/foundation/pz_icons.dart';
import 'package:postzera/widgets/pz_loading_indicator.dart';

/// The inside of a button: an optional icon or busy indicator and the label,
/// centered. Shared by the primary and secondary buttons.
class PzButtonContent extends StatelessWidget {
  const PzButtonContent({
    required this.label,
    required this.style,
    required this.color,
    required this.fullWidth,
    required this.busy,
    this.icon,
    super.key,
  });

  final String label;
  final TextStyle style;
  final Color color;
  final bool fullWidth;
  final bool busy;
  final PzIconData? icon;

  @override
  Widget build(BuildContext context) {
    final PzIconData? shownIcon = icon;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: PzSizes.touchTarget),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: PzSpacing.lg,
          vertical: PzSpacing.sm,
        ),
        child: Row(
          mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            if (busy) ...<Widget>[
              PzLoadingIndicator(
                size: PzSizes.iconInline,
                color: color,
                delay: Duration.zero,
              ),
              const SizedBox(width: PzSpacing.sm),
            ] else if (shownIcon != null) ...<Widget>[
              PzIcon(shownIcon, size: PzSizes.iconInline, color: color),
              const SizedBox(width: PzSpacing.sm),
            ],
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: style.copyWith(color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
