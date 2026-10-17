import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:postzera/utils/date_format.dart';

void main() {
  setUpAll(() => initializeDateFormatting('en'));

  test('isSameLocalDay compares calendar days', () {
    expect(
      isSameLocalDay(DateTime(2026, 10, 17, 0, 1), DateTime(2026, 10, 17, 23, 59)),
      isTrue,
    );
    expect(
      isSameLocalDay(DateTime(2026, 10, 17, 23, 59), DateTime(2026, 10, 18, 0, 1)),
      isFalse,
    );
  });

  test('formatMinutesOfDay shows hour and minute', () {
    final String text = formatMinutesOfDay(545, 'en');
    expect(text, contains('9:05'));
  });

  test('formatMinutesOfDay clamps out-of-range values', () {
    expect(formatMinutesOfDay(-5, 'en'), contains('12:00'));
    expect(formatMinutesOfDay(5000, 'en'), contains('11:59'));
  });

  test('formatDay and formatDateTime include the year', () {
    final DateTime d = DateTime(2026, 10, 17, 9, 0);
    expect(formatDay(d, 'en'), contains('2026'));
    expect(formatDateTime(d, 'en'), contains('2026'));
  });
}
