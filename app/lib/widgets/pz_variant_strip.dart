import 'package:flutter/widgets.dart';
import 'package:postzera/l10n/app_localizations.dart';
import 'package:postzera/theme/pz_radii.dart';
import 'package:postzera/theme/pz_sizes.dart';
import 'package:postzera/theme/pz_spacing.dart';
import 'package:postzera/theme/pz_theme.dart';

/// The signature element of the variants screen: a horizontal pager of cards
/// that lets the next one peek, with page dots below. It fills the height it is
/// given, and a card taller than that scrolls inside its own page. Swiping
/// follows the reading direction, so it reverses in Arabic and Hebrew.
class PzVariantStrip extends StatefulWidget {
  const PzVariantStrip({
    required this.itemCount,
    required this.itemBuilder,
    this.initialPage = 0,
    this.onPageChanged,
    super.key,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final int initialPage;
  final ValueChanged<int>? onPageChanged;

  @override
  State<PzVariantStrip> createState() => _PzVariantStripState();
}

class _PzVariantStripState extends State<PzVariantStrip> {
  late final PageController _controller = PageController(
    initialPage: widget.initialPage,
    viewportFraction: PzSizes.stripViewportFraction,
  );
  late int _page = widget.initialPage;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final PzThemeData theme = PzTheme.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Column(
      children: <Widget>[
        Expanded(
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.itemCount,
            onPageChanged: (int index) {
              setState(() => _page = index);
              widget.onPageChanged?.call(index);
            },
            itemBuilder: (BuildContext context, int index) {
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: PzSpacing.xs + PzSpacing.xs,
                ),
                child: widget.itemBuilder(context, index),
              );
            },
          ),
        ),
        if (widget.itemCount > 1)
          Semantics(
            label: l10n.variant_pageOf(_page + 1, widget.itemCount),
            child: ExcludeSemantics(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: PzSpacing.md),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    for (int i = 0; i < widget.itemCount; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: PzSpacing.xs / 2,
                        ),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: PzRadii.pill(PzSizes.pageDot),
                            color: i == _page
                                ? theme.colors.accent
                                : theme.colors.textTertiary,
                          ),
                          child: const SizedBox.square(
                            dimension: PzSizes.pageDot,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
