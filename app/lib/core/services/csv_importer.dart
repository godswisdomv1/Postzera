import 'package:flutter/foundation.dart';
import 'package:postzera/core/data/builtin_card_themes.dart';
import 'package:postzera/core/models/media_source.dart';
import 'package:postzera/core/models/post.dart';
import 'package:postzera/core/ports/clock.dart';
import 'package:postzera/core/services/hashtag_service.dart';
import 'package:postzera/utils/id_generator.dart';

/// Why a row was rejected.
enum CsvIssue { missingHook, invalidDate, unclosedQuote }

@immutable
class CsvRowError {
  const CsvRowError(this.line, this.issue);

  /// 1-based line where the row starts. The header is line 1.
  final int line;
  final CsvIssue issue;
}

@immutable
class CsvImportResult {
  const CsvImportResult({
    this.valid = const <Post>[],
    this.errors = const <CsvRowError>[],
    this.hookColumnMissing = false,
    this.extraRows = 0,
  });

  /// Posts ready to import (drafts, or scheduled when a date was given).
  final List<Post> valid;
  final List<CsvRowError> errors;

  /// The header has no `hook` column, so nothing can be imported.
  final bool hookColumnMissing;

  /// Rows beyond the 200-row limit that were not read.
  final int extraRows;
}

class _Record {
  _Record(this.line, this.fields, {this.unclosed = false});

  final int line;
  final List<String> fields;
  final bool unclosed;
}

/// Reads the CSV format of blueprint section 7: UTF-8, optional byte-order
/// mark, RFC 4180 quoting, header `hook,body,cta,link,hashtags,scheduled,
/// card_theme`. Only `hook` is required. At most 200 rows are read.
class CsvImporter {
  CsvImporter({
    this.clock = const SystemClock(),
    String Function()? idGenerator,
    this.defaultThemeId = defaultCardThemeId,
    this.hashtags = const HashtagService(),
  }) : _newId = idGenerator ?? newId;

  static const int maxRows = 200;

  final Clock clock;
  final String defaultThemeId;
  final HashtagService hashtags;
  final String Function() _newId;

  static final RegExp _date =
      RegExp(r'^(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2})$');

  CsvImportResult parse(String input) {
    final String text = input.startsWith('\uFEFF') ? input.substring(1) : input;
    final List<_Record> records = _records(text);
    if (records.isEmpty) {
      return const CsvImportResult(hookColumnMissing: true);
    }

    final Map<String, int> columns = <String, int>{};
    final List<String> header = records.first.fields;
    for (int i = 0; i < header.length; i++) {
      columns.putIfAbsent(header[i].trim().toLowerCase(), () => i);
    }
    if (!columns.containsKey('hook')) {
      return const CsvImportResult(hookColumnMissing: true);
    }

    final DateTime now = clock.now().toUtc();
    final Set<String> themeIds =
        builtinCardThemes.map((theme) => theme.id).toSet();
    final List<Post> valid = <Post>[];
    final List<CsvRowError> errors = <CsvRowError>[];
    int extra = 0;

    for (final _Record record in records.skip(1)) {
      if (valid.length + errors.length >= maxRows) {
        extra++;
        continue;
      }
      String cell(String name) {
        final int? index = columns[name];
        if (index == null || index >= record.fields.length) {
          return '';
        }
        return record.fields[index].trim();
      }

      if (record.unclosed) {
        errors.add(CsvRowError(record.line, CsvIssue.unclosedQuote));
        continue;
      }
      final String hook = cell('hook');
      if (hook.isEmpty) {
        errors.add(CsvRowError(record.line, CsvIssue.missingHook));
        continue;
      }
      final String scheduledText = cell('scheduled');
      DateTime? scheduled;
      if (scheduledText.isNotEmpty) {
        scheduled = _parseLocalDate(scheduledText);
        if (scheduled == null) {
          errors.add(CsvRowError(record.line, CsvIssue.invalidDate));
          continue;
        }
      }
      final String theme = cell('card_theme').toLowerCase();
      valid.add(
        Post(
          id: _newId(),
          hook: hook,
          body: cell('body'),
          cta: cell('cta'),
          link: cell('link'),
          hashtags: hashtags.parse(cell('hashtags')),
          mediaSource: const MediaSource.auto(),
          cardThemeId: themeIds.contains(theme) ? theme : defaultThemeId,
          scheduledAt: scheduled?.toUtc(),
          status: scheduled == null ? PostStatus.draft : PostStatus.scheduled,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }
    return CsvImportResult(valid: valid, errors: errors, extraRows: extra);
  }

  /// `YYYY-MM-DD HH:MM` in local time, or null when it is not a real date.
  static DateTime? _parseLocalDate(String text) {
    final RegExpMatch? m = _date.firstMatch(text);
    if (m == null) {
      return null;
    }
    final int year = int.parse(m.group(1)!);
    final int month = int.parse(m.group(2)!);
    final int day = int.parse(m.group(3)!);
    final int hour = int.parse(m.group(4)!);
    final int minute = int.parse(m.group(5)!);
    final DateTime value = DateTime(year, month, day, hour, minute);
    if (value.year != year ||
        value.month != month ||
        value.day != day ||
        hour > 23 ||
        minute > 59) {
      return null;
    }
    return value;
  }

  /// Splits RFC 4180 text into records. Quoted fields may hold commas, quotes
  /// ("") and line breaks. Blank lines are skipped.
  List<_Record> _records(String text) {
    final List<_Record> out = <_Record>[];
    List<String> fields = <String>[];
    final StringBuffer cell = StringBuffer();
    bool inQuotes = false;
    bool fieldStarted = false;
    int line = 1;
    int startLine = 1;

    void endRecord({bool unclosed = false}) {
      fields.add(cell.toString());
      final bool blank =
          fields.length == 1 && fields.first.isEmpty && !unclosed;
      if (!blank) {
        out.add(_Record(startLine, fields, unclosed: unclosed));
      }
      fields = <String>[];
      cell.clear();
      fieldStarted = false;
    }

    for (int i = 0; i < text.length; i++) {
      final String c = text[i];
      if (inQuotes) {
        if (c == '"') {
          if (i + 1 < text.length && text[i + 1] == '"') {
            cell.write('"');
            i++;
          } else {
            inQuotes = false;
          }
        } else if (c == '\r' && i + 1 < text.length && text[i + 1] == '\n') {
          continue;
        } else {
          if (c == '\n') {
            line++;
          }
          cell.write(c);
        }
        continue;
      }
      if (c == '"' && !fieldStarted) {
        inQuotes = true;
        fieldStarted = true;
      } else if (c == ',') {
        fields.add(cell.toString());
        cell.clear();
        fieldStarted = false;
      } else if (c == '\r' && i + 1 < text.length && text[i + 1] == '\n') {
        continue;
      } else if (c == '\n' || c == '\r') {
        endRecord();
        line++;
        startLine = line;
      } else {
        cell.write(c);
        fieldStarted = true;
      }
    }
    if (inQuotes) {
      endRecord(unclosed: true);
    } else if (cell.isNotEmpty || fields.isNotEmpty) {
      endRecord();
    }
    return out;
  }
}
