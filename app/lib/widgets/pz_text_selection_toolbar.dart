import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:postzera/theme/pz_radii.dart';
import 'package:postzera/theme/pz_sizes.dart';
import 'package:postzera/theme/pz_spacing.dart';
import 'package:postzera/theme/pz_theme.dart';
import 'package:postzera/widgets/pz_chip.dart';

/// The words on the toolbar buttons, localized by the caller.
@immutable
class PzToolbarLabels {
  const PzToolbarLabels({
    required this.cut,
    required this.copy,
    required this.paste,
    required this.selectAll,
  });

  final String cut;
  final String copy;
  final String paste;
  final String selectAll;
}

/// Cut, copy, paste and select all as small chips floating above the
/// selection (or below it when there is no room above). It replaces the
/// framework's toolbar, which belongs to Material and Cupertino.
class PzTextSelectionToolbar extends StatelessWidget {
  const PzTextSelectionToolbar({
    required this.state,
    required this.labels,
    super.key,
  });

  final EditableTextState state;
  final PzToolbarLabels labels;

  String? _labelFor(ContextMenuButtonType type) {
    return switch (type) {
      ContextMenuButtonType.cut => labels.cut,
      ContextMenuButtonType.copy => labels.copy,
      ContextMenuButtonType.paste => labels.paste,
      ContextMenuButtonType.selectAll => labels.selectAll,
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final PzThemeData theme = PzTheme.of(context);
    final TextSelectionToolbarAnchors anchors = state.contextMenuAnchors;
    final List<Widget> chips = <Widget>[
      for (final ContextMenuButtonItem item in state.contextMenuButtonItems)
        if (_labelFor(item.type) != null && item.onPressed != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: PzSpacing.xs),
            child: PzChip(
              label: _labelFor(item.type) ?? '',
              onTap: item.onPressed,
            ),
          ),
    ];
    if (chips.isEmpty) {
      return const SizedBox.shrink();
    }
    return CustomSingleChildLayout(
      delegate: _ToolbarLayout(
        primary: anchors.primaryAnchor,
        secondary: anchors.secondaryAnchor ?? anchors.primaryAnchor,
        margin: PzSpacing.sm,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colors.bgSecondary,
          borderRadius: PzRadii.cardRadius,
          border: Border.all(
            color: theme.colors.borderSubtle,
            width: PzSizes.hairline,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(PzSpacing.xs),
          child: Row(mainAxisSize: MainAxisSize.min, children: chips),
        ),
      ),
    );
  }
}

class _ToolbarLayout extends SingleChildLayoutDelegate {
  const _ToolbarLayout({
    required this.primary,
    required this.secondary,
    required this.margin,
  });

  final Offset primary;
  final Offset secondary;
  final double margin;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    return BoxConstraints(maxWidth: constraints.maxWidth - 2 * margin);
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final double maxX = size.width - childSize.width - margin;
    final double x = (primary.dx - childSize.width / 2).clamp(
      margin,
      maxX < margin ? margin : maxX,
    );
    double y = primary.dy - childSize.height - margin;
    if (y < margin) {
      y = secondary.dy + margin;
    }
    return Offset(x, y);
  }

  @override
  bool shouldRelayout(_ToolbarLayout oldDelegate) =>
      oldDelegate.primary != primary || oldDelegate.secondary != secondary;
}
