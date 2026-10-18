import 'package:flutter_test/flutter_test.dart';
import 'package:postzera/core/ports/clock.dart';

class _FixedClock implements Clock {
  _FixedClock(this.value);

  final DateTime value;

  @override
  DateTime now() => value;
}

void main() {
  test('SystemClock returns the current time', () {
    final DateTime before = DateTime.now();
    final DateTime seen = const SystemClock().now();
    final DateTime after = DateTime.now();
    expect(seen.isBefore(before), isFalse);
    expect(seen.isAfter(after), isFalse);
  });

  test('a Clock can be replaced for tests', () {
    final Clock clock = _FixedClock(DateTime.utc(2026, 10, 18, 9));
    expect(clock.now(), DateTime.utc(2026, 10, 18, 9));
  });
}
