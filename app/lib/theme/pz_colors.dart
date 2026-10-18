import 'package:flutter/widgets.dart';

/// Every color token of the design system (blueprint section 12), for one
/// brightness. No raw color value may appear anywhere else in the app.
@immutable
class PzColors {
  const PzColors({
    required this.bgPrimary,
    required this.bgSecondary,
    required this.bgTertiary,
    required this.accent,
    required this.accentDim,
    required this.onAccent,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.borderSubtle,
    required this.borderFocus,
    required this.error,
    required this.success,
    required this.warning,
    required this.scrim,
  });

  static const PzColors light = PzColors(
    bgPrimary: Color(0xFFF7F5F1),
    bgSecondary: Color(0xFFFFFFFF),
    bgTertiary: Color(0xFFEFECE6),
    accent: Color(0xFF0B6B55),
    accentDim: Color(0xFF095645),
    onAccent: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF16130F),
    textSecondary: Color(0xFF554F48),
    textTertiary: Color(0xFF6B645C),
    borderSubtle: Color(0xFFE3DFD7),
    borderFocus: Color(0xFF0B6B55),
    error: Color(0xFFB42318),
    success: Color(0xFF166F3C),
    warning: Color(0xFF8F5206),
    scrim: Color(0x66000000),
  );

  static const PzColors dark = PzColors(
    bgPrimary: Color(0xFF0E0D0C),
    bgSecondary: Color(0xFF181614),
    bgTertiary: Color(0xFF242120),
    accent: Color(0xFF3FCF9D),
    accentDim: Color(0xFF2FB085),
    onAccent: Color(0xFF07140F),
    textPrimary: Color(0xFFF4F1EC),
    textSecondary: Color(0xFFB8B1A7),
    textTertiary: Color(0xFF968F85),
    borderSubtle: Color(0xFF2E2A27),
    borderFocus: Color(0xFF3FCF9D),
    error: Color(0xFFF97066),
    success: Color(0xFF4ADE80),
    warning: Color(0xFFFDB022),
    scrim: Color(0x99000000),
  );

  /// Scaffold.
  final Color bgPrimary;

  /// Cards, sheets, dialogs.
  final Color bgSecondary;

  /// Inputs, empty and disabled states, row press tint.
  final Color bgTertiary;

  /// Primary actions, active navigation.
  final Color accent;

  /// Pressed primary.
  final Color accentDim;

  /// Label on an accent fill.
  final Color onAccent;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color borderSubtle;
  final Color borderFocus;
  final Color error;

  /// Check icon plus label only, never a filled surface.
  final Color success;
  final Color warning;

  /// Behind sheets and dialogs.
  final Color scrim;

  static PzColors of(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;
}
