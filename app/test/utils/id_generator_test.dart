import 'package:flutter_test/flutter_test.dart';
import 'package:postzera/utils/id_generator.dart';

void main() {
  test('ids are 22 URL-safe characters', () {
    final RegExp pattern = RegExp(r'^[A-Za-z0-9_-]{22}$');
    for (int i = 0; i < 200; i++) {
      expect(pattern.hasMatch(newId()), isTrue);
    }
  });

  test('ids do not repeat', () {
    final Set<String> seen = <String>{};
    for (int i = 0; i < 2000; i++) {
      seen.add(newId());
    }
    expect(seen.length, 2000);
  });
}
