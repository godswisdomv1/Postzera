import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:postzera/core/providers/banner_provider.dart';
import 'package:postzera/core/providers/undo_provider.dart';
import 'package:postzera/l10n/app_localizations.dart';
import 'package:postzera/theme/pz_theme.dart';
import 'package:postzera/utils/number_format.dart';
import 'package:postzera/widgets/pz_banner.dart';
import 'package:postzera/widgets/pz_bottom_sheet.dart';
import 'package:postzera/widgets/pz_date_time_sheet.dart';
import 'package:postzera/widgets/pz_dialog.dart';
import 'package:postzera/widgets/pz_page_route.dart';
import 'package:postzera/widgets/pz_primary_button.dart';
import 'package:postzera/widgets/pz_segmented_control.dart';
import 'package:postzera/widgets/pz_switch.dart';
import 'package:postzera/widgets/pz_text_field.dart';

/// A real app shell, so Navigator, Overlay, Localizations and the keyboard
/// shortcuts behave as they do in Postzera.
Widget app(Widget home, {Brightness brightness = Brightness.light}) {
  return PzTheme(
    data: PzThemeData.of(brightness),
    child: WidgetsApp(
      color: const Color(0xFFFFFFFF),
      locale: const Locale('en'),
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        AppLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
      pageRouteBuilder: <T>(RouteSettings settings, WidgetBuilder builder) =>
          PzPageRoute<T>(settings: settings, builder: builder),
    ),
  );
}

class Opener extends StatelessWidget {
  const Opener({required this.open, super.key});

  final void Function(BuildContext context) open;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: 200,
        child: PzPrimaryButton(label: 'Open', onPressed: () => open(context)),
      ),
    );
  }
}

void main() {
  setUpAll(initializeDateFormatting);

  group('PzTextField', () {
    Widget field(TextEditingController c, {FocusNode? node, String? error}) {
      return app(
        Center(
          child: SizedBox(
            width: 320,
            child: PzTextField(
              controller: c,
              focusNode: node,
              label: 'Hook',
              hint: 'Write a headline',
              errorText: error,
              counterBuilder: (String t) =>
                  (text: formatCount(t.length, 10), over: t.length > 10),
            ),
          ),
        ),
      );
    }

    testWidgets('typing fills the controller and updates the counter', (
      t,
    ) async {
      final TextEditingController c = TextEditingController();
      addTearDown(c.dispose);
      await t.pumpWidget(field(c));
      await t.pumpAndSettle();
      expect(find.text('Write a headline'), findsOneWidget);
      expect(find.text('0 / 10'), findsOneWidget);
      await t.enterText(find.byType(EditableText), 'hello');
      await t.pump();
      expect(c.text, 'hello');
      expect(find.text('5 / 10'), findsOneWidget);
      expect(find.text('Write a headline'), findsNothing);
    });

    testWidgets('over the limit the counter turns to the error color', (
      t,
    ) async {
      final TextEditingController c = TextEditingController();
      addTearDown(c.dispose);
      await t.pumpWidget(field(c));
      await t.pumpAndSettle();
      await t.enterText(find.byType(EditableText), 'twelve chars');
      await t.pump();
      final Text counter = t.widget<Text>(find.text('12 / 10'));
      expect(counter.style?.color, PzThemeData.light.colors.error);
    });

    testWidgets('an error message shows under the field', (t) async {
      final TextEditingController c = TextEditingController();
      addTearDown(c.dispose);
      await t.pumpWidget(field(c, error: 'Add a hook'));
      await t.pumpAndSettle();
      expect(find.text('Add a hook'), findsOneWidget);
    });

    testWidgets('tapping the field focuses it', (t) async {
      final TextEditingController c = TextEditingController();
      final FocusNode node = FocusNode();
      addTearDown(c.dispose);
      addTearDown(node.dispose);
      await t.pumpWidget(field(c, node: node));
      await t.pumpAndSettle();
      expect(node.hasFocus, isFalse);
      await t.tap(find.byType(PzTextField));
      await t.pump();
      expect(node.hasFocus, isTrue);
    });

    testWidgets('text direction follows the text', (t) async {
      final TextEditingController c = TextEditingController();
      addTearDown(c.dispose);
      await t.pumpWidget(field(c));
      await t.pumpAndSettle();
      await t.enterText(find.byType(EditableText), 'مرحبا بالعالم');
      await t.pump();
      expect(
        t.widget<EditableText>(find.byType(EditableText)).textDirection,
        TextDirection.rtl,
      );
      await t.enterText(find.byType(EditableText), 'hello');
      await t.pump();
      expect(
        t.widget<EditableText>(find.byType(EditableText)).textDirection,
        TextDirection.ltr,
      );
    });

    testWidgets('selecting text offers cut, copy, paste and select all', (
      t,
    ) async {
      final TextEditingController c = TextEditingController();
      addTearDown(c.dispose);
      await t.pumpWidget(field(c));
      await t.pumpAndSettle();
      await t.enterText(find.byType(EditableText), 'hello');
      await t.pump();
      await t.longPressAt(
        t.getTopLeft(find.byType(EditableText)) + const Offset(24, 12),
      );
      await t.pumpAndSettle();
      expect(c.selection.isCollapsed, isFalse, reason: 'a word is selected');
      final EditableTextState editable = t.state<EditableTextState>(
        find.byType(EditableText),
      );
      // The long press alone must bring up the toolbar, with no further call.
      await t.pumpAndSettle();
      expect(
        editable.selectionOverlay?.toolbarIsVisible,
        isTrue,
        reason: 'trace: $pzGestureTrace; sel=${c.selection}; '
            'items=${editable.contextMenuButtonItems.map((i) => i.type).toList()}',
      );
      expect(find.text('Cut'), findsOneWidget);
      expect(find.text('Copy'), findsOneWidget);
    });
  });

  group('PzSwitch and PzSegmentedControl', () {
    testWidgets('the switch toggles and has a 48 dp target', (t) async {
      final List<bool> seen = <bool>[];
      await t.pumpWidget(
        app(
          Align(
            alignment: Alignment.topLeft,
            child: PzSwitch(
              value: false,
              onChanged: seen.add,
              semanticLabel: 'Reminders',
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(t.getSize(find.byType(PzSwitch)).height, greaterThanOrEqualTo(48));
      await t.tap(find.byType(PzSwitch));
      expect(seen, <bool>[true]);
    });

    testWidgets('a disabled switch ignores taps', (t) async {
      await t.pumpWidget(
        app(
          const Align(
            alignment: Alignment.topLeft,
            child: PzSwitch(
              value: true,
              onChanged: null,
              semanticLabel: 'Reminders',
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.byType(PzSwitch));
      expect(t.takeException(), isNull);
    });

    testWidgets('choosing a segment reports its value', (t) async {
      final List<String> seen = <String>[];
      await t.pumpWidget(
        app(
          Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 320,
              child: PzSegmentedControl<String>(
                segments: const <PzSegment<String>>[
                  PzSegment<String>(value: 'system', label: 'System'),
                  PzSegment<String>(value: 'light', label: 'Light'),
                  PzSegment<String>(value: 'dark', label: 'Dark'),
                ],
                selected: 'system',
                onChanged: seen.add,
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Dark'));
      expect(seen, <String>['dark']);
    });
  });

  group('sheets and dialogs', () {
    testWidgets('a sheet opens and the scrim dismisses it', (t) async {
      await t.pumpWidget(
        app(
          Opener(
            open: (BuildContext c) => showPzSheet<void>(
              context: c,
              builder: (_) => const Text('Sheet content'),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Open'));
      await t.pumpAndSettle();
      expect(find.text('Sheet content'), findsOneWidget);
      await t.tapAt(const Offset(700, 20));
      await t.pumpAndSettle();
      expect(find.text('Sheet content'), findsNothing);
    });

    testWidgets('a sheet closes when dragged down by its handle', (t) async {
      await t.pumpWidget(
        app(
          Opener(
            open: (BuildContext c) => showPzSheet<void>(
              context: c,
              builder: (_) => const Text('Sheet content'),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Open'));
      await t.pumpAndSettle();
      final Offset content = t.getCenter(find.text('Sheet content'));
      await t.dragFrom(
        Offset(content.dx, content.dy - 34),
        const Offset(0, 400),
      );
      await t.pumpAndSettle();
      expect(find.text('Sheet content'), findsNothing);
    });

    testWidgets('a dialog resolves true on confirm and false on cancel', (
      t,
    ) async {
      bool? result;
      await t.pumpWidget(
        app(
          Opener(
            open: (BuildContext c) async {
              result = await showPzDialog(
                context: c,
                title: 'Delete post?',
                message: 'This cannot be undone.',
                confirmLabel: 'Delete',
                destructive: true,
              );
            },
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Open'));
      await t.pumpAndSettle();
      expect(find.text('Delete post?'), findsOneWidget);
      await t.tap(find.text('Delete'));
      await t.pumpAndSettle();
      expect(result, isTrue);
      await t.tap(find.text('Open'));
      await t.pumpAndSettle();
      await t.tap(find.text('Cancel'));
      await t.pumpAndSettle();
      expect(result, isFalse);
    });

    testWidgets('the date and time sheet returns the chosen time', (t) async {
      final DateTime initial = DateTime(2030, 5, 17, 9, 30);
      DateTime? result;
      await t.pumpWidget(
        app(
          Opener(
            open: (BuildContext c) async {
              result = await showPzDateTimeSheet(
                context: c,
                initial: initial,
                title: 'Schedule',
                confirmLabel: 'Set time',
              );
            },
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Open'));
      await t.pumpAndSettle();
      expect(find.text('Schedule'), findsOneWidget);
      await t.tap(find.text('Set time'));
      await t.pumpAndSettle();
      expect(result, initial);
    });

    testWidgets('a time before the minimum cannot be confirmed', (t) async {
      DateTime? result;
      await t.pumpWidget(
        app(
          Opener(
            open: (BuildContext c) async {
              result = await showPzDateTimeSheet(
                context: c,
                initial: DateTime(2030, 5, 17, 9, 30),
                minimum: DateTime(2030, 5, 18, 10),
                title: 'Schedule',
                confirmLabel: 'Set time',
              );
            },
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Open'));
      await t.pumpAndSettle();
      await t.tap(find.text('Set time'));
      await t.pumpAndSettle();
      expect(result, isNull);
      expect(find.text('Schedule'), findsOneWidget);
    });
  });

  group('PzBannerHost', () {
    late BannerProvider banners;
    late UndoProvider undo;

    setUp(() {
      banners = BannerProvider();
      undo = UndoProvider();
    });

    tearDown(() {
      banners.dispose();
      undo.dispose();
    });

    Widget host() => app(
      PzBannerHost(
        banners: banners,
        undo: undo,
        child: const SizedBox.expand(),
      ),
    );

    testWidgets('shows a success banner and a counted one', (t) async {
      await t.pumpWidget(host());
      await t.pumpAndSettle();
      banners.success(BannerMessage.postSaved);
      await t.pump();
      expect(find.text('Post saved'), findsOneWidget);
      banners.success(BannerMessage.imported, count: 12);
      await t.pump();
      expect(find.text('12 posts imported'), findsOneWidget);
      banners.dismiss();
    });

    testWidgets('sticky banners stay until removed', (t) async {
      await t.pumpWidget(host());
      await t.pumpAndSettle();
      banners.addSticky(
        const BannerItem(
          id: 'db',
          kind: BannerKind.warning,
          message: BannerMessage.storageFallback,
        ),
      );
      await t.pump();
      expect(find.textContaining('cannot be saved'), findsOneWidget);
      banners.removeSticky('db');
      await t.pump();
      expect(find.textContaining('cannot be saved'), findsNothing);
    });

    testWidgets('an undo banner can take the action back', (t) async {
      bool reverted = false;
      await t.pumpWidget(host());
      await t.pumpAndSettle();
      await undo.register(
        UndoAction(
          label: UndoLabel.postDeleted,
          revert: () async => reverted = true,
        ),
      );
      await t.pump();
      expect(find.text('Post deleted'), findsOneWidget);
      await t.tap(find.text('Undo'));
      await t.pump();
      expect(reverted, isTrue);
    });
  });

  group('PzPageRoute', () {
    Widget pusher() => app(
      Opener(
        open: (BuildContext c) {
          Navigator.of(c).push<void>(
            PzPageRoute<void>(builder: (_) => const Text('Second screen')),
          );
        },
      ),
    );

    testWidgets('pushes and pops', (t) async {
      await t.pumpWidget(pusher());
      await t.pumpAndSettle();
      await t.tap(find.text('Open'));
      await t.pumpAndSettle();
      expect(find.text('Second screen'), findsOneWidget);
      t.state<NavigatorState>(find.byType(Navigator)).pop();
      await t.pumpAndSettle();
      expect(find.text('Second screen'), findsNothing);
    });

    testWidgets('on iPhone an edge swipe goes back', (t) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        await t.pumpWidget(pusher());
        await t.pumpAndSettle();
        await t.tap(find.text('Open'));
        await t.pumpAndSettle();
        await t.dragFrom(const Offset(4, 300), const Offset(600, 0));
        await t.pumpAndSettle();
        expect(find.text('Second screen'), findsNothing);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('on Android an edge swipe does nothing', (t) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        await t.pumpWidget(pusher());
        await t.pumpAndSettle();
        await t.tap(find.text('Open'));
        await t.pumpAndSettle();
        await t.dragFrom(const Offset(4, 300), const Offset(600, 0));
        await t.pumpAndSettle();
        expect(find.text('Second screen'), findsOneWidget);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });
}
