import 'dart:ui' show Brightness;

import 'package:flutter/widgets.dart';
import 'package:postzera/theme/pz_colors.dart';
import 'package:postzera/theme/pz_typography.dart';

/// The tokens of one brightness.
@immutable
class PzThemeData {
  const PzThemeData._(this.brightness, this.colors, this.text);

  factory PzThemeData.of(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;

  static final PzThemeData light = PzThemeData._(
    Brightness.light,
    PzColors.light,
    PzTypography.of(PzColors.light),
  );

  static final PzThemeData dark = PzThemeData._(
    Brightness.dark,
    PzColors.dark,
    PzTypography.of(PzColors.dark),
  );

  final Brightness brightness;
  final PzColors colors;
  final PzTypography text;

  bool get isDark => brightness == Brightness.dark;

  @override
  bool operator ==(Object other) =>
      other is PzThemeData && other.brightness == brightness;

  @override
  int get hashCode => brightness.hashCode;
}

/// Carries [PzThemeData] down the tree. `PzTheme.of(context)` is the only way
/// a widget reads a token.
class PzTheme extends InheritedWidget {
  const PzTheme({required this.data, required super.child, super.key});

  final PzThemeData data;

  static PzThemeData of(BuildContext context) {
    final PzThemeData? found = maybeOf(context);
    assert(found != null, 'No PzTheme found above this context.');
    return found!;
  }

  static PzThemeData? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PzTheme>()?.data;

  @override
  bool updateShouldNotify(PzTheme oldWidget) => data != oldWidget.data;
}
