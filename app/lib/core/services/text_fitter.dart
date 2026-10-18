import 'package:characters/characters.dart';
import 'package:flutter/foundation.dart';
import 'package:postzera/core/models/platform_profile.dart';

/// The result of fitting text to a limit.
@immutable
class FitResult {
  const FitResult(this.text, {required this.truncated});

  final String text;

  /// True when the text had to be cut.
  final bool truncated;
}

/// Measures and shortens text.
///
/// Plain counting counts grapheme clusters, so an emoji or a letter with
/// combining marks counts once. X counting follows X's published weighting
/// (limit 280): a link counts 23, an emoji counts 2, characters inside the
/// code-point ranges 0 to 4351, 8192 to 8205, 8208 to 8223 and 8242 to 8247
/// count 1, and every other character (including Chinese, Japanese and Korean
/// text) counts 2. Only links that start with http:// or https:// are
/// recognized as links.
class TextFitter {
  const TextFitter();

  static const String ellipsis = '…';
  static const int xLinkWeight = 23;

  static final RegExp _link = RegExp(r'https?://\S+', caseSensitive: false);

  /// The length of [text] under [scheme].
  int length(String text, CountingScheme scheme) {
    if (scheme == CountingScheme.plain) {
      return text.characters.length;
    }
    int total = 0;
    int cursor = 0;
    for (final Match m in _link.allMatches(text)) {
      total += _xWeight(text.substring(cursor, m.start));
      total += xLinkWeight;
      cursor = m.end;
    }
    return total + _xWeight(text.substring(cursor));
  }

  /// Cuts [text] to at most [limit] (under [scheme]) at the last word
  /// boundary that leaves room for an ellipsis. Text that already fits is
  /// returned unchanged.
  FitResult fit(String text, int limit, CountingScheme scheme) {
    if (length(text, scheme) <= limit) {
      return FitResult(text, truncated: false);
    }
    if (limit <= 0 || length(ellipsis, scheme) > limit) {
      return const FitResult('', truncated: true);
    }
    final List<String> g = text.characters.toList();

    bool fits(int count) =>
        length(g.sublist(0, count).join() + ellipsis, scheme) <= limit;

    int lo = 0;
    int hi = g.length - 1;
    while (lo < hi) {
      final int mid = (lo + hi + 1) ~/ 2;
      if (fits(mid)) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    int k = lo;
    while (k > 0 && !fits(k)) {
      k--;
    }

    if (!(k < g.length && _isSpace(g[k]))) {
      int j = k - 1;
      while (j > 0 && !_isSpace(g[j])) {
        j--;
      }
      if (j > 0) {
        k = j;
      }
    }
    final String prefix = g.sublist(0, k).join().trimRight();
    return FitResult('$prefix$ellipsis', truncated: true);
  }

  static bool _isSpace(String grapheme) => grapheme.trim().isEmpty;

  int _xWeight(String text) {
    int total = 0;
    for (final String g in text.characters) {
      total += _graphemeWeight(g);
    }
    return total;
  }

  static int _graphemeWeight(String grapheme) {
    final int rune = grapheme.runes.first;
    if (_isEmoji(rune)) {
      return 2;
    }
    final bool light = (rune >= 0 && rune <= 4351) ||
        (rune >= 8192 && rune <= 8205) ||
        (rune >= 8208 && rune <= 8223) ||
        (rune >= 8242 && rune <= 8247);
    return light ? 1 : 2;
  }

  static bool _isEmoji(int rune) =>
      (rune >= 0x1F000 && rune <= 0x1FAFF) ||
      (rune >= 0x2600 && rune <= 0x27BF) ||
      (rune >= 0x2B00 && rune <= 0x2BFF);
}
