import 'package:flutter/foundation.dart';
import 'package:postzera/core/models/json_read.dart';

enum ThemeModeSetting { system, light, dark }

/// User settings, stored as one JSON value.
@immutable
class AppSettings {
  const AppSettings({
    this.themeMode = ThemeModeSetting.system,
    this.localeCode,
    this.defaultCardThemeId = 'paper',
    this.remindersEnabled = true,
    this.reminderMinutes = 540,
    this.onboardingDone = false,
  });

  factory AppSettings.fromJson(Map<String, Object?> json) => AppSettings(
        themeMode: readEnum(
          ThemeModeSetting.values,
          json['themeMode'],
          ThemeModeSetting.system,
        ),
        localeCode: readStringOrNull(json['localeCode']),
        defaultCardThemeId: readString(json['defaultCardThemeId'], 'paper'),
        remindersEnabled: readBool(json['remindersEnabled'], true),
        reminderMinutes: readInt(json['reminderMinutes'], 540).clamp(0, 1439),
        onboardingDone: readBool(json['onboardingDone']),
      );

  final ThemeModeSetting themeMode;

  /// Null follows the system language.
  final String? localeCode;
  final String defaultCardThemeId;
  final bool remindersEnabled;

  /// Minutes from midnight. 540 is 09:00.
  final int reminderMinutes;
  final bool onboardingDone;

  AppSettings copyWith({
    ThemeModeSetting? themeMode,
    String? localeCode,
    bool clearLocale = false,
    String? defaultCardThemeId,
    bool? remindersEnabled,
    int? reminderMinutes,
    bool? onboardingDone,
  }) =>
      AppSettings(
        themeMode: themeMode ?? this.themeMode,
        localeCode: clearLocale ? null : (localeCode ?? this.localeCode),
        defaultCardThemeId: defaultCardThemeId ?? this.defaultCardThemeId,
        remindersEnabled: remindersEnabled ?? this.remindersEnabled,
        reminderMinutes: reminderMinutes ?? this.reminderMinutes,
        onboardingDone: onboardingDone ?? this.onboardingDone,
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'schemaVersion': modelSchemaVersion,
        'themeMode': themeMode.name,
        'localeCode': localeCode,
        'defaultCardThemeId': defaultCardThemeId,
        'remindersEnabled': remindersEnabled,
        'reminderMinutes': reminderMinutes,
        'onboardingDone': onboardingDone,
      };

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.themeMode == themeMode &&
      other.localeCode == localeCode &&
      other.defaultCardThemeId == defaultCardThemeId &&
      other.remindersEnabled == remindersEnabled &&
      other.reminderMinutes == reminderMinutes &&
      other.onboardingDone == onboardingDone;

  @override
  int get hashCode => Object.hash(
        themeMode,
        localeCode,
        defaultCardThemeId,
        remindersEnabled,
        reminderMinutes,
        onboardingDone,
      );
}
