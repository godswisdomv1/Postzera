import 'package:flutter/widgets.dart';
import 'package:postzera/theme/pz_sizes.dart';
import 'package:postzera/theme/pz_theme.dart';

/// Round accent handles at the ends of a text selection. They are drawn here
/// because the framework's handles belong to Material and Cupertino. The
/// toolbar is separate: see `PzTextSelectionToolbar`.
class PzSelectionHandles extends TextSelectionControls {
  @override
  Widget buildHandle(
    BuildContext context,
    TextSelectionHandleType type,
    double textLineHeight, [
    VoidCallback? onTap,
  ]) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: onTap,
      child: SizedBox.square(
        dimension: PzSizes.selectionHandle,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: PzTheme.of(context).colors.accent,
          ),
        ),
      ),
    );
  }

  @override
  Offset getHandleAnchor(TextSelectionHandleType type, double textLineHeight) {
    return const Offset(PzSizes.selectionHandle / 2, 0);
  }

  @override
  Size getHandleSize(double textLineHeight) =>
      const Size.square(PzSizes.selectionHandle);
}
