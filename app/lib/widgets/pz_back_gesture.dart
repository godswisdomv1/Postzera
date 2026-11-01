import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:postzera/theme/pz_sizes.dart';

/// Drives a route's animation while the finger drags it away, then settles it
/// forward or back by velocity and position. Calls the navigator's
/// user-gesture hooks so nothing else navigates meanwhile.
class PzBackGestureController {
  PzBackGestureController({required this.navigator, required this.controller}) {
    navigator.didStartUserGesture();
  }

  final NavigatorState navigator;
  final AnimationController controller;

  /// Moves the route by [delta], a fraction of the screen width.
  void dragUpdate(double delta) {
    controller.value -= delta;
  }

  /// Ends the drag. [velocity] is in screen widths per second, positive when
  /// moving toward closing the route.
  void dragEnd(double velocity) {
    const Curve curve = Curves.easeOut;
    final bool settleOpen;
    if (velocity.abs() >= 1.0) {
      settleOpen = velocity <= 0;
    } else {
      settleOpen = controller.value > 0.5;
    }
    if (settleOpen) {
      final int ms = math.min(lerpDouble(800, 0, controller.value)!.floor(), 300);
      controller.animateTo(
        1,
        duration: Duration(milliseconds: ms),
        curve: curve,
      );
    } else {
      navigator.pop();
      if (controller.isAnimating) {
        final int ms = lerpDouble(0, 800, controller.value)!.floor();
        controller.animateBack(
          0,
          duration: Duration(milliseconds: ms),
          curve: curve,
        );
      }
    }
    if (controller.isAnimating) {
      late AnimationStatusListener listener;
      listener = (AnimationStatus status) {
        navigator.didStopUserGesture();
        controller.removeStatusListener(listener);
      };
      controller.addStatusListener(listener);
    } else {
      navigator.didStopUserGesture();
    }
  }
}

/// Listens for a horizontal drag that starts in a narrow strip at the leading
/// edge of the screen, which is the left in left-to-right languages and the
/// right in right-to-left ones, and hands it to a [PzBackGestureController].
class PzBackGesture extends StatefulWidget {
  const PzBackGesture({
    required this.enabledCallback,
    required this.onStartPopGesture,
    required this.child,
    super.key,
  });

  final Widget child;

  /// Whether a back swipe may start right now.
  final ValueGetter<bool> enabledCallback;
  final ValueGetter<PzBackGestureController> onStartPopGesture;

  @override
  State<PzBackGesture> createState() => _PzBackGestureState();
}

class _PzBackGestureState extends State<PzBackGesture> {
  late final HorizontalDragGestureRecognizer _recognizer =
      HorizontalDragGestureRecognizer(debugOwner: this)
        ..onStart = _onStart
        ..onUpdate = _onUpdate
        ..onEnd = _onEnd
        ..onCancel = _onCancel;
  PzBackGestureController? _active;

  @override
  void dispose() {
    _recognizer.dispose();
    super.dispose();
  }

  double _logical(double value) =>
      Directionality.of(context) == TextDirection.rtl ? -value : value;

  void _onStart(DragStartDetails details) {
    _active = widget.onStartPopGesture();
  }

  void _onUpdate(DragUpdateDetails details) {
    final double width = context.size?.width ?? 1;
    _active?.dragUpdate(_logical((details.primaryDelta ?? 0) / width));
  }

  void _onEnd(DragEndDetails details) {
    final double width = context.size?.width ?? 1;
    _active?.dragEnd(
      _logical(details.velocity.pixelsPerSecond.dx / width),
    );
    _active = null;
  }

  void _onCancel() {
    _active?.dragEnd(0);
    _active = null;
  }

  void _onPointerDown(PointerDownEvent event) {
    if (widget.enabledCallback()) {
      _recognizer.addPointer(event);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.passthrough,
      children: <Widget>[
        widget.child,
        PositionedDirectional(
          start: 0,
          width: PzSizes.backGestureEdge,
          top: 0,
          bottom: 0,
          child: Listener(
            onPointerDown: _onPointerDown,
            behavior: HitTestBehavior.translucent,
          ),
        ),
      ],
    );
  }
}
