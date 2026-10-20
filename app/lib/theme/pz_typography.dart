import 'package:flutter/widgets.dart';
import 'package:postzera/theme/pz_colors.dart';

/// Family names declared in pubspec.yaml.
abstract final class PzFonts {
  static const String inter = 'Inter';
  static const String newsreader = 'Newsreader';
  static const String mono = 'JetBrainsMono';
}

/// Inter's optical-size axis: 14 for text up to 17 px, 32 from 28 px,
/// interpolated in between.
double interOpticalSize(double fontSize) {
  if (fontSize <= 17) {
    return 14;
  }
  if (fontSize >= 28) {
    return 32;
  }
  return 14 + (fontSize - 17) / (28 - 17) * (32 - 14);
}

/// One [TextStyle] per role (blueprint section 12). Weights and optical sizes
/// come from variable-font axes, not from separate font files. Styles carry
/// the primary text color; use `copyWith(color: ...)` for other colors.
@immutable
class PzTypography {
  const PzTypography._({
    required this.display,
    required this.headline,
    required this.title1,
    required this.title2,
    required this.body,
    required this.callout,
    required this.footnote,
    required this.caption,
    required this.sectionHeader,
    required this.counter,
  });

  factory PzTypography.of(PzColors colors) {
    return PzTypography._(
      display: _newsreader(
        size: 34,
        weight: 600,
        height: 1.1,
        color: colors.textPrimary,
      ),
      headline: _inter(
        size: 28,
        weight: 600,
        height: 1.2,
        color: colors.textPrimary,
      ),
      title1: _inter(
        size: 22,
        weight: 600,
        height: 1.3,
        color: colors.textPrimary,
      ),
      title2: _inter(
        size: 17,
        weight: 600,
        height: 1.3,
        color: colors.textPrimary,
      ),
      body: _inter(
        size: 17,
        weight: 400,
        height: 1.5,
        color: colors.textPrimary,
      ),
      callout: _inter(
        size: 16,
        weight: 500,
        height: 1.4,
        color: colors.textPrimary,
      ),
      footnote: _inter(
        size: 13,
        weight: 400,
        height: 1.4,
        color: colors.textSecondary,
      ),
      caption: _inter(
        size: 12,
        weight: 400,
        height: 1.3,
        color: colors.textTertiary,
      ),
      sectionHeader: _inter(
        size: 12,
        weight: 600,
        height: 1.3,
        color: colors.textTertiary,
        letterSpacing: 0.8,
      ),
      counter: TextStyle(
        fontFamily: PzFonts.mono,
        fontSize: 13,
        fontWeight: _weight(500),
        height: 1.3,
        color: colors.textTertiary,
        fontVariations: const <FontVariation>[FontVariation('wght', 500)],
      ),
    );
  }

  /// Screen hero titles and the card hook. Newsreader, with Inter as the
  /// fallback family for Greek and Cyrillic.
  final TextStyle display;

  /// Empty-state and paywall headlines.
  final TextStyle headline;

  /// Section titles.
  final TextStyle title1;

  /// Navigation titles and row labels.
  final TextStyle title2;

  /// Reading text and inputs.
  final TextStyle body;

  /// Buttons, chips and tab labels.
  final TextStyle callout;

  /// Secondary row lines.
  final TextStyle footnote;

  /// Hints and status.
  final TextStyle caption;

  /// Group headings. Callers apply upper case.
  final TextStyle sectionHeader;

  /// Counters such as "212 / 280".
  final TextStyle counter;

  static FontWeight _weight(int value) => FontWeight.values[(value ~/ 100) - 1];

  static TextStyle _inter({
    required double size,
    required int weight,
    required double height,
    required Color color,
    double letterSpacing = 0,
  }) {
    return TextStyle(
      fontFamily: PzFonts.inter,
      fontSize: size,
      fontWeight: _weight(weight),
      height: height,
      color: color,
      letterSpacing: letterSpacing,
      fontVariations: <FontVariation>[
        FontVariation('wght', weight.toDouble()),
        FontVariation('opsz', interOpticalSize(size)),
      ],
    );
  }

  static TextStyle _newsreader({
    required double size,
    required int weight,
    required double height,
    required Color color,
  }) {
    return TextStyle(
      fontFamily: PzFonts.newsreader,
      fontFamilyFallback: const <String>[PzFonts.inter],
      fontSize: size,
      fontWeight: _weight(weight),
      height: height,
      color: color,
      fontVariations: <FontVariation>[
        FontVariation('wght', weight.toDouble()),
        FontVariation('opsz', size.clamp(6, 72).toDouble()),
      ],
    );
  }
}
