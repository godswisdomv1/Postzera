import 'package:flutter_test/flutter_test.dart';
import 'package:postzera/utils/number_format.dart';

void main() {
  test('formatCount joins used and limit', () {
    expect(formatCount(212, 280, locale: 'en'), '212 / 280');
    expect(formatCount(1234, 2200, locale: 'en'), '1,234 / 2,200');
  });

  test('formatPercent renders a fraction', () {
    expect(formatPercent(0.5, locale: 'en'), '50%');
  });

  test('formatBytes picks a readable unit', () {
    expect(formatBytes(0, locale: 'en'), '0 B');
    expect(formatBytes(1023, locale: 'en'), '1023 B');
    expect(formatBytes(1536, locale: 'en'), '1.5 KB');
    expect(formatBytes(5 * 1024 * 1024, locale: 'en'), '5 MB');
  });
}
