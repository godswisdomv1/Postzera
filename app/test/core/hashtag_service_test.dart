import 'package:flutter_test/flutter_test.dart';
import 'package:postzera/core/services/hashtag_service.dart';

void main() {
  const HashtagService service = HashtagService();

  test('parse splits on spaces and commas and adds one hash', () {
    expect(service.parse('a, #b  ##c\td'), <String>['#a', '#b', '#c', '#d']);
  });

  test('duplicates are removed ignoring case, keeping the first spelling', () {
    expect(service.normalize(<String>['Tag', '#tag', 'TAG', 'other']), <String>[
      '#Tag',
      '#other',
    ]);
  });

  test('spaces inside an entry are stripped', () {
    expect(service.normalize(<String>['hello world']), <String>['#helloworld']);
  });

  test('empty entries are dropped', () {
    expect(service.parse('  , ,#, '), isEmpty);
    expect(service.parse(''), isEmpty);
  });

  test('cap keeps the first tags and reports what was dropped', () {
    final ({List<String> tags, bool dropped}) r = service.cap(<String>[
      '#a',
      '#b',
      '#c',
    ], 2);
    expect(r.tags, <String>['#a', '#b']);
    expect(r.dropped, isTrue);
    expect(service.cap(<String>['#a'], 2).dropped, isFalse);
    expect(service.cap(<String>['#a'], 0).tags, isEmpty);
    expect(service.cap(<String>['#a'], 0).dropped, isTrue);
    expect(service.cap(const <String>[], 0).dropped, isFalse);
  });
}
