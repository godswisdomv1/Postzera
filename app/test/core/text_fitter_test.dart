import 'package:flutter_test/flutter_test.dart';
import 'package:postzera/core/models/platform_profile.dart';
import 'package:postzera/core/services/text_fitter.dart';

void main() {
  const TextFitter fitter = TextFitter();

  group('plain length', () {
    test('counts graphemes, not code units', () {
      expect(fitter.length('hello', CountingScheme.plain), 5);
      expect(fitter.length('😀', CountingScheme.plain), 1);
      expect(fitter.length('e\u0301', CountingScheme.plain), 1);
      expect(fitter.length('👨‍👩‍👧', CountingScheme.plain), 1);
    });
  });

  group('X length', () {
    test('ordinary letters count once', () {
      expect(fitter.length('hi', CountingScheme.x), 2);
    });

    test('an emoji counts twice, however long its sequence', () {
      expect(fitter.length('😀', CountingScheme.x), 2);
      expect(fitter.length('👨‍👩‍👧', CountingScheme.x), 2);
    });

    test('Chinese, Japanese and Korean characters count twice', () {
      expect(fitter.length('日本', CountingScheme.x), 4);
      expect(fitter.length('한글', CountingScheme.x), 4);
    });

    test('a link counts 23 whatever its length', () {
      expect(
        fitter.length(
          'https://example.com/very/long/path?x=1',
          CountingScheme.x,
        ),
        23,
      );
      expect(fitter.length('a https://x.co b', CountingScheme.x), 27);
    });

    test('a combining accent adds nothing', () {
      expect(fitter.length('e\u0301', CountingScheme.x), 1);
    });
  });

  group('fit', () {
    test('text that fits is returned unchanged', () {
      final FitResult r = fitter.fit('hello world', 20, CountingScheme.plain);
      expect(r.text, 'hello world');
      expect(r.truncated, isFalse);
    });

    test('cuts at a word boundary and adds an ellipsis', () {
      final FitResult r = fitter.fit(
        'hello wonderful world',
        12,
        CountingScheme.plain,
      );
      expect(r.text, 'hello…');
      expect(r.truncated, isTrue);
    });

    test('keeps a whole word when the cut lands on a space', () {
      final FitResult r = fitter.fit(
        'hello world foo',
        12,
        CountingScheme.plain,
      );
      expect(r.text, 'hello world…');
      expect(fitter.length(r.text, CountingScheme.plain), 12);
    });

    test('the result never exceeds the limit', () {
      const String text =
          'The quick brown fox jumps over the lazy dog and keeps running far';
      for (int limit = 1; limit < text.length; limit++) {
        final FitResult r = fitter.fit(text, limit, CountingScheme.plain);
        expect(
          fitter.length(r.text, CountingScheme.plain),
          lessThanOrEqualTo(limit),
          reason: 'limit $limit gave "${r.text}"',
        );
      }
    });

    test('a single very long word is cut mid-word', () {
      final String word = 'a' * 50;
      final FitResult r = fitter.fit(word, 10, CountingScheme.plain);
      expect(r.text, '${'a' * 9}…');
    });

    test('an emoji is never split', () {
      final FitResult r = fitter.fit('😀😀😀😀😀😀', 4, CountingScheme.plain);
      expect(r.text, '😀😀😀…');
    });

    test('X weighting is respected when cutting', () {
      const String hook = '日本語日本語日本語日本語日本語';
      final FitResult r = fitter.fit(hook, 11, CountingScheme.x);
      expect(fitter.length(r.text, CountingScheme.x), lessThanOrEqualTo(11));
      expect(r.truncated, isTrue);
    });

    test('a limit smaller than the ellipsis gives empty text', () {
      final FitResult r = fitter.fit('hello', 0, CountingScheme.plain);
      expect(r.text, '');
      expect(r.truncated, isTrue);
    });
  });
}
