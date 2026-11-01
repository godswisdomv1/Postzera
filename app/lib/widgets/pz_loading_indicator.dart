import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:postzera/theme/pz_sizes.dart';
import 'package:postzera/theme/pz_theme.dart';

/// An accent arc that turns. It stays invisible, and takes no room, until
/// [delay] has passed, so quick loads never flash a spinner. Under Reduce
/// Motion the arc does not turn.
class PzLoadingIndicator extends StatefulWidget {
  const PzLoadingIndicator({
    this.size = PzSizes.iconNav,
    this.color,
    this.delay = const Duration(milliseconds: 300),
    this.semanticLabel,
    super.key,
  });

  final double size;

  /// Defaults to the accent color.
  final Color? color;
  final Duration delay;
  final String? semanticLabel;

  @override
  State<PzLoadingIndicator> createState() => _PzLoadingIndicatorState();
}

class _PzLoadingIndicatorState extends State<PzLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  Timer? _timer;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _visible = true;
    } else {
      _timer = Timer(widget.delay, () {
        if (mounted) {
          setState(() => _visible = true);
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) {
      return const SizedBox.shrink();
    }
    final bool still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (still) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      unawaited(_controller.repeat());
    }
    final Widget arc = Center(
      widthFactor: 1,
      heightFactor: 1,
      child: SizedBox.square(
        dimension: widget.size,
        child: RepaintBoundary(
          child: RotationTransition(
            turns: _controller,
            child: CustomPaint(
              painter: _ArcPainter(
                widget.color ?? PzTheme.of(context).colors.accent,
              ),
            ),
          ),
        ),
      ),
    );
    return Semantics(
      label: widget.semanticLabel,
      liveRegion: widget.semanticLabel != null,
      child: ExcludeSemantics(child: arc),
    );
  }
}

class _ArcPainter extends CustomPainter {
  const _ArcPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = PzSizes.strokeNav
      ..strokeCap = StrokeCap.round;
    final Rect rect = (Offset.zero & size).deflate(PzSizes.strokeNav / 2);
    canvas.drawArc(rect, -math.pi / 2, math.pi * 1.5, false, paint);
  }

  @override
  bool shouldRepaint(_ArcPainter oldDelegate) => oldDelegate.color != color;
}
