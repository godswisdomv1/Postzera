import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:postzera/l10n/app_localizations.dart';
import 'package:postzera/theme/pz_motion.dart';
import 'package:postzera/theme/pz_radii.dart';
import 'package:postzera/theme/pz_sizes.dart';
import 'package:postzera/theme/pz_spacing.dart';
import 'package:postzera/theme/pz_theme.dart';

/// Shows a bottom sheet over a scrim: it slides up in 400 ms, can be dragged
/// down by its handle or dismissed by tapping the scrim, keeps clear of the
/// keyboard and the bottom safe area, and scrolls when its content is tall.
/// Resolves with the value the sheet pops with.
Future<T?> showPzSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  String? semanticLabel,
  bool dismissible = true,
}) {
  final PzThemeData theme = PzTheme.of(context);
  return Navigator.of(context, rootNavigator: true).push<T>(
    _PzSheetRoute<T>(
      builder: builder,
      theme: theme,
      barrierColor: theme.colors.scrim,
      barrierLabel: AppLocalizations.of(context).common_close,
      semanticLabel: semanticLabel,
      dismissible: dismissible,
      reduceMotion: MediaQuery.maybeDisableAnimationsOf(context) ?? false,
    ),
  );
}

class _PzSheetRoute<T> extends PopupRoute<T> {
  _PzSheetRoute({
    required this.builder,
    required this.theme,
    required this.barrierColor,
    required this.barrierLabel,
    required this.semanticLabel,
    required this.dismissible,
    required this.reduceMotion,
  });

  final WidgetBuilder builder;
  final PzThemeData theme;
  final String? semanticLabel;
  final bool dismissible;
  final bool reduceMotion;

  @override
  final Color barrierColor;

  @override
  final String barrierLabel;

  @override
  bool get barrierDismissible => dismissible;

  @override
  Duration get transitionDuration =>
      reduceMotion ? Duration.zero : PzMotion.sheet;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return PzTheme(
      data: theme,
      child: Semantics(
        scopesRoute: true,
        namesRoute: true,
        explicitChildNodes: true,
        label: semanticLabel,
        child: _SheetBody(
          dismissible: dismissible,
          onDismiss: () => navigator?.maybePop(),
          child: Builder(builder: builder),
        ),
      ),
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return SlideTransition(
      position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
          .animate(
            CurvedAnimation(
              parent: animation,
              curve: PzMotion.easeOut,
              reverseCurve: PzMotion.easeInOut,
            ),
          ),
      child: child,
    );
  }
}

class _SheetBody extends StatefulWidget {
  const _SheetBody({
    required this.child,
    required this.dismissible,
    required this.onDismiss,
  });

  final Widget child;
  final bool dismissible;
  final VoidCallback onDismiss;

  @override
  State<_SheetBody> createState() => _SheetBodyState();
}

class _SheetBodyState extends State<_SheetBody>
    with SingleTickerProviderStateMixin {
  late final AnimationController _snap = AnimationController(
    vsync: this,
    duration: PzMotion.press,
  );
  double _dy = 0;
  double _from = 0;

  static const double _dismissDistance = 96;
  static const double _dismissVelocity = 700;

  @override
  void initState() {
    super.initState();
    _snap.addListener(() {
      setState(() => _dy = _from * (1 - _snap.value));
    });
  }

  @override
  void dispose() {
    _snap.dispose();
    super.dispose();
  }

  void _dragUpdate(DragUpdateDetails details) {
    setState(() => _dy = (_dy + details.delta.dy).clamp(0, double.infinity));
  }

  void _dragEnd(DragEndDetails details) {
    if (_dy > _dismissDistance ||
        details.velocity.pixelsPerSecond.dy > _dismissVelocity) {
      widget.onDismiss();
      return;
    }
    _from = _dy;
    unawaited(_snap.forward(from: 0));
  }

  @override
  Widget build(BuildContext context) {
    final PzThemeData theme = PzTheme.of(context);
    final MediaQueryData media = MediaQuery.of(context);
    final double bottom = media.viewInsets.bottom > media.padding.bottom
        ? media.viewInsets.bottom
        : media.padding.bottom;
    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: PzSpacing.contentMaxWidth,
          maxHeight: media.size.height * 0.9,
        ),
        child: Transform.translate(
          offset: Offset(0, _dy),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colors.bgSecondary,
              borderRadius: PzRadii.sheetRadius,
              border: Border.all(
                color: theme.colors.borderSubtle,
                width: PzSizes.hairline,
              ),
            ),
            child: Padding(
              padding: EdgeInsets.only(bottom: bottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onVerticalDragUpdate: widget.dismissible
                        ? _dragUpdate
                        : null,
                    onVerticalDragEnd: widget.dismissible ? _dragEnd : null,
                    child: SizedBox(
                      height: PzSizes.touchTarget,
                      width: double.infinity,
                      child: Center(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: theme.colors.borderSubtle,
                            borderRadius: PzRadii.pill(
                              PzSizes.sheetHandleHeight,
                            ),
                          ),
                          child: const SizedBox(
                            width: PzSizes.sheetHandleWidth,
                            height: PzSizes.sheetHandleHeight,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(
                        PzSpacing.screenPadding,
                        0,
                        PzSpacing.screenPadding,
                        PzSpacing.md,
                      ),
                      child: widget.child,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
