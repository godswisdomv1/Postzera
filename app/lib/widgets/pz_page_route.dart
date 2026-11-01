import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:postzera/theme/pz_motion.dart';
import 'package:postzera/widgets/pz_back_gesture.dart';

/// The one page transition of the app: a fade plus a 20 px slide, 350 ms in
/// and 280 ms out, instant when Reduce Motion is on. On iPhone an edge swipe
/// goes back; on Android the system back gesture does.
class PzPageRoute<T> extends PageRoute<T> {
  PzPageRoute({
    required this.builder,
    super.settings,
    this.reduceMotion = false,
    super.fullscreenDialog,
  });

  final WidgetBuilder builder;

  /// Captured when the route is made, because durations have no context.
  final bool reduceMotion;

  @override
  Duration get transitionDuration =>
      reduceMotion ? Duration.zero : PzMotion.push;

  @override
  Duration get reverseTransitionDuration =>
      reduceMotion ? Duration.zero : PzMotion.pop;

  @override
  bool get maintainState => true;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  bool get _swipeBackEnabled {
    if (defaultTargetPlatform != TargetPlatform.iOS) {
      return false;
    }
    if (isFirst || willHandlePopInternally || !popGestureEnabledNow) {
      return false;
    }
    final NavigatorState? nav = navigator;
    return nav != null && !nav.userGestureInProgress;
  }

  /// True while this route is fully shown and nothing is moving.
  @visibleForTesting
  bool get popGestureEnabledNow {
    return animation?.status == AnimationStatus.completed &&
        secondaryAnimation?.status == AnimationStatus.dismissed &&
        popDisposition == RoutePopDisposition.pop;
  }

  PzBackGestureController _startBackGesture() {
    return PzBackGestureController(
      navigator: navigator!,
      controller: controller!,
    );
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      child: builder(context),
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final Animation<double> eased = CurvedAnimation(
      parent: animation,
      curve: PzMotion.easeInOut,
      reverseCurve: PzMotion.easeInOut,
    );
    final double sign = Directionality.of(context) == TextDirection.rtl
        ? -1
        : 1;
    final Widget moving = FadeTransition(
      opacity: eased,
      child: AnimatedBuilder(
        animation: eased,
        builder: (BuildContext context, Widget? content) => Transform.translate(
          offset: Offset(sign * (1 - eased.value) * PzMotion.pushSlide, 0),
          child: content,
        ),
        child: child,
      ),
    );
    return PzBackGesture(
      enabledCallback: () => _swipeBackEnabled,
      onStartPopGesture: _startBackGesture,
      child: moving,
    );
  }
}
