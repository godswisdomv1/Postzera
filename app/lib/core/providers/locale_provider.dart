import 'package:flutter/foundation.dart';
import 'package:postzera/core/models/app_settings.dart';
import 'package:postzera/core/providers/settings_sync.dart';

/// A language the app is translated into.
@immutable
class SupportedLocale {
  const SupportedLocale(this.code, this.nativeName, {this.rtl = false});

  final String code;
  final String nativeName;
  final bool rtl;
}

/// The chosen language, or null to follow the system.
class LocaleProvider extends ValueNotifier<String?> {
  LocaleProvider(this._sync) : super(_sync.current.localeCode) {
    _sync.addListener(_onSettings);
  }

  /// The 11 languages of blueprint section 15, in the order of the picker.
  static const List<SupportedLocale> supported = <SupportedLocale>[
    SupportedLocale('en', 'English'),
    SupportedLocale('es', 'Español'),
    SupportedLocale('fr', 'Français'),
    SupportedLocale('de', 'Deutsch'),
    SupportedLocale('pt', 'Português'),
    SupportedLocale('ar', 'العربية', rtl: true),
    SupportedLocale('hi', 'हिन्दी'),
    SupportedLocale('ja', '日本語'),
    SupportedLocale('ko', '한국어'),
    SupportedLocale('zh', '中文'),
    SupportedLocale('he', 'עברית', rtl: true),
  ];

  final SettingsSync _sync;

  /// A code from [supported], or null for the system language. Anything else
  /// is ignored.
  Future<void> setLocale(String? code) async {
    if (code != null && !supported.any((SupportedLocale l) => l.code == code)) {
      return;
    }
    await _sync.update(
      (AppSettings s) =>
          code == null ? s.copyWith(clearLocale: true) : s.copyWith(localeCode: code),
    );
  }

  /// Whether a language is written right to left.
  static bool isRtl(String code) =>
      supported.any((SupportedLocale l) => l.code == code && l.rtl);

  void _onSettings() => value = _sync.current.localeCode;

  @override
  void dispose() {
    _sync.removeListener(_onSettings);
    super.dispose();
  }
}
