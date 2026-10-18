/// Cleans and caps hashtags.
class HashtagService {
  const HashtagService();

  static final RegExp _separators = RegExp(r'[\s,]+');

  /// Splits typed text on spaces and commas, then normalizes it.
  List<String> parse(String input) => normalize(input.split(_separators));

  /// Strips `#` and spaces, drops empty entries and duplicates (ignoring
  /// case, keeping the first spelling), and adds a single `#` to each.
  List<String> normalize(Iterable<String> raw) {
    final Set<String> seen = <String>{};
    final List<String> result = <String>[];
    for (final String entry in raw) {
      final String cleaned = entry.replaceAll(RegExp(r'[#\s]'), '');
      if (cleaned.isEmpty) {
        continue;
      }
      if (seen.add(cleaned.toLowerCase())) {
        result.add('#$cleaned');
      }
    }
    return result;
  }

  /// Keeps at most [max] tags. [dropped] is true when any were removed.
  ({List<String> tags, bool dropped}) cap(List<String> tags, int max) {
    if (max <= 0) {
      return (tags: const <String>[], dropped: tags.isNotEmpty);
    }
    if (tags.length <= max) {
      return (tags: tags, dropped: false);
    }
    return (tags: tags.sublist(0, max), dropped: true);
  }
}
