import 'package:postzera/core/models/post.dart';

/// The columns of the CSV format, in order.
const List<String> csvColumns = <String>[
  'hook',
  'body',
  'cta',
  'link',
  'hashtags',
  'scheduled',
  'card_theme',
];

/// Writes posts in the format [CsvImporter] reads, so export and import
/// round-trip. Media is not exported.
class CsvExporter {
  const CsvExporter();

  static const String _bom = '\uFEFF';

  /// UTF-8 text with a byte-order mark (so spreadsheets open it correctly),
  /// RFC 4180 quoting and CRLF line endings. The scheduled time is written in
  /// the device's local time as `YYYY-MM-DD HH:MM`.
  String encode(List<Post> posts) {
    final StringBuffer out = StringBuffer(_bom)
      ..write(csvColumns.join(','))
      ..write('\r\n');
    for (final Post post in posts) {
      final List<String> cells = <String>[
        post.hook,
        post.body,
        post.cta,
        post.link,
        post.hashtags.join(' '),
        _local(post.scheduledAt),
        post.cardThemeId,
      ];
      out
        ..write(cells.map(_cell).join(','))
        ..write('\r\n');
    }
    return out.toString();
  }

  static String _cell(String value) {
    if (value.contains(RegExp(r'[",\r\n]'))) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  static String _local(DateTime? utc) {
    if (utc == null) {
      return '';
    }
    final DateTime t = utc.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${t.year.toString().padLeft(4, '0')}-${two(t.month)}-${two(t.day)} '
        '${two(t.hour)}:${two(t.minute)}';
  }
}
