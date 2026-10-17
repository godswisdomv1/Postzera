import 'package:flutter_test/flutter_test.dart';
import 'package:postzera/utils/log.dart';

void main() {
  setUp(Log.clear);

  test('keeps at most 200 entries and drops the oldest', () {
    for (int i = 0; i < 250; i++) {
      Log.i('test', 'message $i');
    }
    expect(Log.length, Log.capacity);
    final List<String> all = Log.recent(1000);
    expect(all.length, 200);
    expect(all.first, contains('message 50'));
    expect(all.last, contains('message 249'));
  });

  test('recent returns the last entries, oldest first', () {
    Log.d('t', 'one');
    Log.w('t', 'two');
    Log.e('t', 'three');
    final List<String> two = Log.recent(2);
    expect(two.length, 2);
    expect(two.first, contains('two'));
    expect(two.last, contains('three'));
    expect(two.last, contains('ERROR'));
  });

  test('recent with a non-positive count is empty', () {
    Log.i('t', 'x');
    expect(Log.recent(0), isEmpty);
  });
}
