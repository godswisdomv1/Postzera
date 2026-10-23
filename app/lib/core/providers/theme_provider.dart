import 'package:flutter/foundation.dart';
import 'package:postzera/core/models/app_settings.dart';
import 'package:postzera/core/providers/settings_sync.dart';

/// The chosen theme mode.
class ThemeProvider extends ValueNotifier<ThemeModeSetting> {
  ThemeProvider(this._sync) : super(_sync.current.themeMode) {
    _sync.addListener(_onSettings);
  }

  final SettingsSync _sync;

  /// Whether the dark theme applies, given whether the system is dark.
  bool isDark({required bool systemIsDark}) => switch (value) {
        ThemeModeSetting.system => systemIsDark,
        ThemeModeSetting.light => false,
        ThemeModeSetting.dark => true,
      };

  Future<void> setMode(ThemeModeSetting mode) async {
    await _sync.update((AppSettings s) => s.copyWith(themeMode: mode));
  }

  void _onSettings() => value = _sync.current.themeMode;

  @override
  void dispose() {
    _sync.removeListener(_onSettings);
    super.dispose();
  }
}
