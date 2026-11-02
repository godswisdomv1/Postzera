import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:postzera/dev/gallery_main.dart';

void main() {
  setUpAll(initializeDateFormatting);

  testWidgets('the gallery scrolls end to end in light, dark and 2.0x text', (
    t,
  ) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final Set<String> reports = <String>{};
    String where = 'start';
    final void Function(FlutterErrorDetails)? previous = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails d) {
      reports.add('[$where] ${d.toString().split('\n').take(12).join(' | ')}');
    };
    try {
      await t.pumpWidget(const GalleryApp());
      await t.pump(const Duration(milliseconds: 100));

      Future<void> sweep(String label) async {
        where = label;
        final Finder list = find.byType(ListView).first;
        for (int i = 0; i < 45; i++) {
          await t.drag(list, const Offset(0, -450));
          await t.pump(const Duration(milliseconds: 30));
        }
        for (int i = 0; i < 45; i++) {
          await t.drag(list, const Offset(0, 450));
          await t.pump(const Duration(milliseconds: 30));
        }
      }

      await sweep('light 1.0x');
      await t.tap(find.text('Dark'));
      await t.pump(const Duration(milliseconds: 100));
      await sweep('dark 1.0x');
      await t.tap(find.text('2.0x'));
      await t.pump(const Duration(milliseconds: 100));
      await sweep('dark 2.0x');
      await t.tap(find.text('Light'));
      await t.pump(const Duration(milliseconds: 100));
      await sweep('light 2.0x');
    } finally {
      FlutterError.onError = previous;
    }
    expect(reports, isEmpty, reason: reports.take(3).join('\n###\n'));
  });

  testWidgets('the media lab page builds', (t) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(const GalleryApp());
    await t.pump(const Duration(milliseconds: 100));
    await t.tap(find.text('Media lab'));
    await t.pump(const Duration(milliseconds: 100));
    expect(find.text('Run all (no clip)'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
