import 'package:postzera/core/models/card_theme.dart';

/// The default card theme.
const String defaultCardThemeId = 'paper';

/// The six themes of blueprint section 8.
const List<MediaCardTheme> builtinCardThemes = <MediaCardTheme>[
  MediaCardTheme(
    id: 'paper',
    name: 'Paper',
    background: 0xFFF7F5F1,
    text: 0xFF16130F,
    accent: 0xFF0B6B55,
    ctaFill: 0xFF0B6B55,
    ctaLabel: 0xFFFFFFFF,
  ),
  MediaCardTheme(
    id: 'ink',
    name: 'Ink',
    background: 0xFF0E0D0C,
    text: 0xFFF4F1EC,
    accent: 0xFF3FCF9D,
    ctaFill: 0xFF3FCF9D,
    ctaLabel: 0xFF07140F,
  ),
  MediaCardTheme(
    id: 'seed',
    name: 'Seed',
    background: 0xFF0B6B55,
    text: 0xFFFFFFFF,
    accent: 0xFFF7F5F1,
    ctaFill: 0xFFF7F5F1,
    ctaLabel: 0xFF0B6B55,
  ),
  MediaCardTheme(
    id: 'sand',
    name: 'Sand',
    background: 0xFFE9DFCF,
    text: 0xFF1D1812,
    accent: 0xFF0B6B55,
    ctaFill: 0xFF0B6B55,
    ctaLabel: 0xFFFFFFFF,
  ),
  MediaCardTheme(
    id: 'midnight',
    name: 'Midnight',
    background: 0xFF14213D,
    text: 0xFFF5F7FA,
    accent: 0xFFFCA311,
    ctaFill: 0xFFFCA311,
    ctaLabel: 0xFF14213D,
  ),
  MediaCardTheme(
    id: 'signal',
    name: 'Signal',
    background: 0xFFF2C94C,
    text: 0xFF14110A,
    accent: 0xFF14110A,
    ctaFill: 0xFF14110A,
    ctaLabel: 0xFFF2C94C,
  ),
];

/// Finds a theme by id, falling back to the default when the id is unknown.
MediaCardTheme cardThemeById(String id) {
  for (final MediaCardTheme theme in builtinCardThemes) {
    if (theme.id == id) {
      return theme;
    }
  }
  return builtinCardThemes.first;
}
