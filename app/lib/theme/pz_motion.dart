import 'package:flutter/widgets.dart';

/// Durations and curves (blueprint section 12). No spring or bounce anywhere.
abstract final class PzMotion {
  static const Duration push = Duration(milliseconds: 350);
  static const Duration pop = Duration(milliseconds: 280);
  static const Duration sheet = Duration(milliseconds: 400);
  static const Duration press = Duration(milliseconds: 150);
  static const Duration reveal = Duration(milliseconds: 300);
  static const Duration themeChange = Duration(milliseconds: 200);
  static const Duration dialogFade = Duration(milliseconds: 200);

  /// Horizontal slide distance of a pushed screen.
  static const double pushSlide = 20;

  /// Opacity of a pressed card or chip.
  static const double pressedOpacity = 0.72;

  /// Opacity of a disabled control.
  static const double disabledOpacity = 0.4;

  /// Scale of a pressed button.
  static const double pressScale = 0.97;

  static const Curve easeInOut = Curves.easeInOut;
  static const Curve easeOut = Curves.easeOut;
  static const Curve linear = Curves.linear;

  /// Returns [duration], or zero when Reduce Motion is on, so every animation
  /// becomes an instant change.
  static Duration resolve(BuildContext context, Duration duration) {
    return (MediaQuery.maybeDisableAnimationsOf(context) ?? false)
        ? Duration.zero
        : duration;
  }
}
