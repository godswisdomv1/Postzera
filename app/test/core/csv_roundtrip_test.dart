import 'package:flutter_test/flutter_test.dart';
import 'package:postzera/core/models/post.dart';
import 'package:postzera/core/services/csv_exporter.dart';
import 'package:postzera/core/services/csv_importer.dart';

import 'test_helpers.dart';

void main() {
  int counter = 0;
  CsvImporter importer() => CsvImporter(
        clock: FixedClock(DateTime.utc(2026, 10, 18, 8)),
        idGenerator: () => 'id${counter++}',
      );
  const CsvExporter exporter = CsvExporter();

  group('round trip', () {
    final List<Post> posts = <Post>[
      testPost(hook: 'Plain'),
      testPost(
        hook: 'Comma, and "quotes"',
        body: 'Line one\nLine two',
        cta: 'Go',
        link: 'https://example.com/?a=1,2',
        tags: const <String>['#a', '#b'],
        theme: 'ink',
      ).copyWith(
        status: PostStatus.scheduled,
        scheduledAt: DateTime(2026, 11, 2, 14, 30).toUtc(),
      ),
    ];

    test('export then import returns the same posts', () {
      final CsvImportResult r = importer().parse(exporter.encode(posts));
      expect(r.errors, isEmpty);
      expect(r.valid.length, 2);
      for (int i = 0; i < posts.length; i++) {
        final Post want = posts[i];
        final Post got = r.valid[i];
        expect(got.hook, want.hook);
        expect(got.body, want.body);
        expect(got.cta, want.cta);
        expect(got.link, want.link);
        expect(got.hashtags, want.hashtags);
        expect(got.cardThemeId, want.cardThemeId);
        expect(got.scheduledAt, want.scheduledAt);
        expect(got.status, want.scheduledAt == null
            ? PostStatus.draft
            : PostStatus.scheduled);
      }
    });

    test('the export starts with a byte-order mark and the header', () {
      final String text = exporter.encode(posts);
      expect(text.startsWith('\uFEFFhook,body,cta,link,hashtags,scheduled,card_theme'), isTrue);
      expect(text, contains('"Comma, and ""quotes"""'));
    });
  });

  group('reading', () {
    test('a byte-order mark is ignored', () {
      final CsvImportResult r = importer().parse('\uFEFFhook\nHi\n');
      expect(r.valid.single.hook, 'Hi');
    });

    test('CRLF and LF line endings both work', () {
      expect(importer().parse('hook\r\nA\r\nB\r\n').valid.length, 2);
      expect(importer().parse('hook\nA\nB').valid.length, 2);
    });

    test('blank lines are skipped', () {
      expect(importer().parse('hook\n\nA\n\n').valid.length, 1);
    });

    test('only hook is required and column order is free', () {
      final CsvImportResult r = importer().parse('cta,hook\nGo,Hello\n');
      expect(r.valid.single.hook, 'Hello');
      expect(r.valid.single.cta, 'Go');
    });

    test('a missing hook column stops the import', () {
      final CsvImportResult r = importer().parse('body,cta\nx,y\n');
      expect(r.hookColumnMissing, isTrue);
      expect(r.valid, isEmpty);
    });

    test('a row with an empty hook is reported with its line number', () {
      final CsvImportResult r = importer().parse('hook,body\nOk,a\n,text\n');
      expect(r.valid.length, 1);
      expect(r.errors.single.line, 3);
      expect(r.errors.single.issue, CsvIssue.missingHook);
    });

    test('a bad date is reported', () {
      final CsvImportResult r = importer().parse(
        'hook,scheduled\nA,2026-13-40 99:99\nB,2026-02-30 10:00\nC,tomorrow\n',
      );
      expect(r.valid, isEmpty);
      expect(r.errors.map((CsvRowError e) => e.line).toList(), <int>[2, 3, 4]);
      expect(
        r.errors.every((CsvRowError e) => e.issue == CsvIssue.invalidDate),
        isTrue,
      );
    });

    test('a good date makes a scheduled post, no date makes a draft', () {
      final CsvImportResult r = importer().parse(
        'hook,scheduled\nA,2026-11-02 14:30\nB,\n',
      );
      expect(r.valid[0].status, PostStatus.scheduled);
      expect(r.valid[0].scheduledAt, DateTime(2026, 11, 2, 14, 30).toUtc());
      expect(r.valid[1].status, PostStatus.draft);
      expect(r.valid[1].scheduledAt, isNull);
    });

    test('quoted fields keep commas, quotes and line breaks', () {
      final CsvImportResult r = importer().parse(
        'hook,body\n"A, ""B""","x\ny"\n',
      );
      expect(r.valid.single.hook, 'A, "B"');
      expect(r.valid.single.body, 'x\ny');
    });

    test('line numbers count lines inside quoted fields', () {
      final CsvImportResult r = importer().parse(
        'hook,body\n"multi\nline",x\n,bad\n',
      );
      expect(r.valid.single.hook, 'multi\nline');
      expect(r.errors.single.line, 4);
    });

    test('an unclosed quote is reported', () {
      final CsvImportResult r = importer().parse(
        'hook,body\nA,"never closed\nmore text\n',
      );
      expect(r.valid, isEmpty);
      expect(r.errors.single.line, 2);
      expect(r.errors.single.issue, CsvIssue.unclosedQuote);
    });

    test('hashtags may be separated by spaces or commas', () {
      final CsvImportResult r = importer().parse(
        'hook,hashtags\nA,"a, b,#c  #a"\n',
      );
      expect(r.valid.single.hashtags, <String>['#a', '#b', '#c']);
    });

    test('card themes fall back to the default', () {
      final CsvImportResult r = importer().parse(
        'hook,card_theme\nA,INK \nB,nope\nC,\n',
      );
      expect(
        r.valid.map((Post p) => p.cardThemeId).toList(),
        <String>['ink', 'paper', 'paper'],
      );
    });

    test('at most 200 rows are read', () {
      final String rows = List<String>.generate(201, (int i) => 'Post $i').join('\n');
      final CsvImportResult r = importer().parse('hook\n$rows\n');
      expect(r.valid.length, 200);
      expect(r.extraRows, 1);
    });

    test('an empty file is rejected', () {
      expect(importer().parse('').hookColumnMissing, isTrue);
    });
  });
}
