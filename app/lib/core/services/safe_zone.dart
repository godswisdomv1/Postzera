import 'package:flutter/foundation.dart';
import 'package:postzera/core/models/media_spec.dart';

/// A plain rectangle in canvas pixels.
@immutable
class PxRect {
  const PxRect({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final int left;
  final int top;
  final int width;
  final int height;

  int get right => left + width;
  int get bottom => top + height;

  @override
  bool operator ==(Object other) =>
      other is PxRect &&
      other.left == left &&
      other.top == top &&
      other.width == width &&
      other.height == height;

  @override
  int get hashCode => Object.hash(left, top, width, height);

  @override
  String toString() => 'PxRect($left, $top, $width x $height)';
}

/// Where text may sit on a canvas: the insets and the clear window inside them.
@immutable
class SafeZone {
  const SafeZone({required this.insets, required this.window});

  /// 9:16 uses 270 / 672 / 64 / 227 px (a 789 x 978 window on 1080 x 1920);
  /// every other shape uses 6% margins.
  factory SafeZone.forCanvas(MediaAspect aspect, int width, int height) {
    final SafeInsets insets = SafeInsets.forCanvas(aspect, width, height);
    return SafeZone(
      insets: insets,
      window: PxRect(
        left: insets.left,
        top: insets.top,
        width: width - insets.left - insets.right,
        height: height - insets.top - insets.bottom,
      ),
    );
  }

  final SafeInsets insets;
  final PxRect window;
}
