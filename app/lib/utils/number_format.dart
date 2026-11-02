import 'package:intl/intl.dart';

/// Counter text such as "212 / 280". Pass [locale] to localize the digits.
String formatCount(int used, int limit, {String? locale}) {
  final NumberFormat f = NumberFormat.decimalPattern(locale);
  return '${f.format(used)} / ${f.format(limit)}';
}

/// A fraction such as 0.5 as a percentage, "50%".
String formatPercent(double fraction, {String? locale}) =>
    NumberFormat.percentPattern(locale).format(fraction);

/// A byte count as "512 B", "1.5 KB", "5 MB" (1024-based).
String formatBytes(int bytes, {String? locale}) {
  if (bytes < 1024) {
    return '$bytes B';
  }
  const List<String> units = <String>['KB', 'MB', 'GB', 'TB'];
  double value = bytes / 1024;
  int unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  return '${NumberFormat('0.#', locale).format(value)} ${units[unit]}';
}

/// A duration in milliseconds as "m:ss", for example 12 000 gives "0:12".
String formatClock(int milliseconds) {
  final int total = milliseconds < 0 ? 0 : milliseconds ~/ 1000;
  final int minutes = total ~/ 60;
  final int seconds = total % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}
