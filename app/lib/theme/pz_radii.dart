import 'package:flutter/widgets.dart';

/// Corner radii (blueprint section 12).
abstract final class PzRadii {
  static const double card = 16;
  static const double hero = 24;
  static const double button = 12;
  static const double input = 12;
  static const double sheet = 20;
  static const double dialog = 16;

  static const BorderRadius cardRadius =
      BorderRadius.all(Radius.circular(card));
  static const BorderRadius heroRadius =
      BorderRadius.all(Radius.circular(hero));
  static const BorderRadius buttonRadius =
      BorderRadius.all(Radius.circular(button));
  static const BorderRadius inputRadius =
      BorderRadius.all(Radius.circular(input));
  static const BorderRadius sheetRadius = BorderRadius.vertical(
    top: Radius.circular(sheet),
  );
  static const BorderRadius dialogRadius =
      BorderRadius.all(Radius.circular(dialog));

  /// Chips and pills use half their height.
  static BorderRadius pill(double height) =>
      BorderRadius.all(Radius.circular(height / 2));
}
