// Runs the real gallery on a real Android runtime (an emulator in CI) and
// drives it like a person would: long-press a word, run the media lab. It
// prints every measurement with the prefix RESULT so CI can publish them.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:postzera/dev/gallery_main.dart';

Future<void> waitFor(
  WidgetTester t,
  Finder finder, {
  Duration timeout = const Duration(seconds: 120),
  String? what,
}) async {
  final DateTime end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await t.pump(const Duration(milliseconds: 250));
    if (finder.evaluate().isNotEmpty) {
      return;
    }
  }
  fail('Timed out after ${timeout.inSeconds} s waiting for ${what ?? finder}');
}

/// Every piece of text on screen that mentions milliseconds or a size.
List<String> measurements(WidgetTester t) {
  final List<String> lines = <String>[];
  for (final Element e in find.byType(Text).evaluate()) {
    final String data = (e.widget as Text).data ?? '';
    if (data.contains(' ms') && data.contains(':')) {
      lines.add(data);
    }
  }
  return lines;
}

void main() {
  final IntegrationTestWidgetsFlutterBinding binding =
      IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  setUpAll(initializeDateFormatting);

  testWidgets('a long press on a word shows the Cut and Copy chips', (t) async {
    await t.pumpWidget(const GalleryApp());
    await t.pumpAndSettle(const Duration(milliseconds: 300));

    final Finder field = find.byWidgetPredicate(
      (Widget w) =>
          w is EditableText && w.controller.text.startsWith('A very long'),
    );
    await t.dragUntilVisible(
      field,
      find.byType(ListView).first,
      const Offset(0, -300),
      maxIteration: 60,
    );
    await t.pump(const Duration(milliseconds: 300));
    await t.longPressAt(t.getTopLeft(field) + const Offset(30, 20));
    await t.pump(const Duration(milliseconds: 800));
    final bool cut = find.text('Cut').evaluate().isNotEmpty;
    final bool copy = find.text('Copy').evaluate().isNotEmpty;
    // ignore: avoid_print
    print('RESULT long press toolbar: Cut=$cut Copy=$copy');
    expect(cut, isTrue, reason: 'Cut chip after a long press');
    expect(copy, isTrue, reason: 'Copy chip after a long press');
  });

  testWidgets('the media lab renders exact sizes and is never a cache hit', (
    t,
  ) async {
    await t.pumpWidget(const GalleryApp());
    await t.pumpAndSettle(const Duration(milliseconds: 300));
    await t.tap(find.text('Media lab'));
    await t.pump(const Duration(milliseconds: 500));

    Future<List<String>> run(String button, String done) async {
      await t.tap(find.text(button));
      await waitFor(t, find.textContaining(done), what: done);
      await t.pump(const Duration(milliseconds: 500));
      return measurements(t);
    }

    final List<String> autoCards = await run(
      'Auto cards, three shapes',
      'pinterest:',
    );
    // ignore: avoid_print
    for (final String l in autoCards) print('RESULT $l');
    final List<String> photo = await run('Photo-backed image', 'source)');
    // ignore: avoid_print
    for (final String l in photo) print('RESULT $l');
    final List<String> three = await run('Slide video, 3 slides', 'tiktok 3');
    // ignore: avoid_print
    for (final String l in three) print('RESULT $l');
    final List<String> five = await run('Slide video, 5 slides', 'tiktok 5');
    // ignore: avoid_print
    for (final String l in five) print('RESULT $l');

    final List<String> all = measurements(t);
    for (final String l in all) {
      expect(l.contains('SIZE '), isFalse, reason: 'wrong output size: $l');
      expect(l.contains('FAILED'), isFalse, reason: l);
    }
    expect(find.textContaining('FAILED'), findsNothing);
  });
}
