import 'package:intl/intl.dart';

/// Locale-aware date helpers. All inputs are converted to local time first.
///
/// [locale] is a language tag such as `en` or `ar`. Locale data for languages
/// other than English must be loaded once at startup with
/// `initializeDateFormatting()`.

/// Weekday, month, day and year, for example "Sat, Oct 17, 2026".
String formatDay(DateTime value, String locale) =>
    DateFormat.yMMMEd(locale).format(value.toLocal());

/// Time of day, for example "9:00 AM" or "09:00".
String formatTime(DateTime value, String locale) =>
    DateFormat.jm(locale).format(value.toLocal());

/// Date and time together.
String formatDateTime(DateTime value, String locale) =>
    DateFormat.yMMMd(locale).add_jm().format(value.toLocal());

/// Formats a time given as minutes from midnight, such as the reminder time.
String formatMinutesOfDay(int minutes, String locale) {
  final int clamped = minutes.clamp(0, 1439);
  return DateFormat.jm(locale)
      .format(DateTime(2000, 1, 1, clamped ~/ 60, clamped % 60));
}

/// True when both instants fall on the same calendar day in local time.
bool isSameLocalDay(DateTime a, DateTime b) {
  final DateTime la = a.toLocal();
  final DateTime lb = b.toLocal();
  return la.year == lb.year && la.month == lb.month && la.day == lb.day;
}
