import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postzera/core/models/app_error.dart';
import 'package:postzera/theme/pz_theme.dart';
import 'package:postzera/widgets/foundation/pz_icon_chip.dart';
import 'package:postzera/widgets/foundation/pz_icons.dart';
import 'package:postzera/widgets/foundation/pz_pressable.dart';
import 'package:postzera/widgets/pz_card.dart';
import 'package:postzera/widgets/pz_chip.dart';
import 'package:postzera/widgets/pz_empty_state.dart';
import 'package:postzera/widgets/pz_error_view.dart';
import 'package:postzera/widgets/pz_loading_indicator.dart';
import 'package:postzera/widgets/pz_nav_bar.dart';
import 'package:postzera/widgets/pz_platform_mark.dart';
import 'package:postzera/widgets/pz_primary_button.dart';
import 'package:postzera/widgets/pz_row.dart';
import 'package:postzera/widgets/pz_secondary_button.dart';
import 'package:postzera/widgets/pz_section_header.dart';

Widget harness(
  Widget child, {
  Brightness brightness = Brightness.light,
  TextDirection direction = TextDirection.ltr,
  double textScale = 1,
  double width = 360,
}) {
  return PzTheme(
    data: PzThemeData.of(brightness),
    child: Directionality(
      textDirection: direction,
      child: MediaQuery(
        data: MediaQueryData(
          size: Size(width, 800),
          textScaler: TextScaler.linear(textScale),
        ),
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: width, child: child),
        ),
      ),
    ),
  );
}

void main() {
  group('PzPressable', () {
    testWidgets('a tiny child still gets a 48 dp target', (tester) async {
      await tester.pumpWidget(
        harness(
          PzPressable(
            onTap: () {},
            builder: (_, __) => const SizedBox.square(dimension: 10),
          ),
        ),
      );
      final Size size = tester.getSize(find.byType(PzPressable));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    });

    testWidgets('tapping calls onTap, disabled does not', (tester) async {
      int taps = 0;
      await tester.pumpWidget(
        harness(
          PzPressable(
            onTap: () => taps++,
            builder: (_, __) => const SizedBox.square(dimension: 10),
          ),
        ),
      );
      await tester.tap(find.byType(PzPressable));
      expect(taps, 1);
      await tester.pumpWidget(
        harness(
          PzPressable(
            onTap: null,
            builder: (_, __) => const SizedBox.square(dimension: 10),
          ),
        ),
      );
      await tester.tap(find.byType(PzPressable));
      expect(taps, 1);
    });

    testWidgets('the keyboard activates it with Enter', (tester) async {
      int taps = 0;
      await tester.pumpWidget(
        harness(
          PzPressable(
            onTap: () => taps++,
            builder: (_, __) => const SizedBox.square(dimension: 10),
          ),
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('the press state reaches the builder', (tester) async {
      bool seenPressed = false;
      await tester.pumpWidget(
        harness(
          PzPressable(
            onTap: () {},
            builder: (_, PzPressState s) {
              seenPressed = seenPressed || s.pressed;
              return const SizedBox.square(dimension: 10);
            },
          ),
        ),
      );
      final TestGesture gesture = await tester.startGesture(
        tester.getCenter(find.byType(PzPressable)),
      );
      await tester.pump();
      expect(seenPressed, isTrue);
      await gesture.up();
    });
  });

  for (final Brightness brightness in Brightness.values) {
    group('in ${brightness.name} mode', () {
      Widget wrap(Widget w, {double scale = 1, TextDirection? dir}) => harness(
        w,
        brightness: brightness,
        textScale: scale,
        direction: dir ?? TextDirection.ltr,
      );

      testWidgets('primary button is at least 48 high and taps', (t) async {
        int taps = 0;
        await t.pumpWidget(
          wrap(PzPrimaryButton(label: 'Send', onPressed: () => taps++)),
        );
        expect(t.getSize(find.byType(PzPrimaryButton)).height, greaterThanOrEqualTo(48));
        await t.tap(find.byType(PzPrimaryButton));
        expect(taps, 1);
      });

      testWidgets('a disabled or busy primary button ignores taps', (t) async {
        int taps = 0;
        await t.pumpWidget(
          wrap(PzPrimaryButton(label: 'Send', onPressed: () => taps++, busy: true)),
        );
        await t.tap(find.byType(PzPrimaryButton));
        await t.pumpWidget(
          wrap(const PzPrimaryButton(label: 'Send', onPressed: null)),
        );
        await t.tap(find.byType(PzPrimaryButton));
        expect(taps, 0);
      });

      testWidgets('secondary button taps and has a label', (t) async {
        int taps = 0;
        await t.pumpWidget(
          wrap(PzSecondaryButton(label: 'Restore', onPressed: () => taps++)),
        );
        await t.tap(find.byType(PzSecondaryButton));
        expect(taps, 1);
        expect(find.text('Restore'), findsOneWidget);
      });

      testWidgets('icon chip: target 48, label read aloud', (t) async {
        final SemanticsHandle handle = t.ensureSemantics();
        await t.pumpWidget(
          wrap(PzIconChip(icon: PzIcons.settings, semanticLabel: 'Settings', onTap: () {})),
        );
        expect(t.getSize(find.byType(PzPressable)).width, greaterThanOrEqualTo(48));
        expect(find.bySemanticsLabel('Settings'), findsOneWidget);
        handle.dispose();
      });

      testWidgets('card summary taps and shows label and value', (t) async {
        int taps = 0;
        await t.pumpWidget(
          wrap(PzCard.summary(label: 'Theme', value: 'Light', icon: PzIcons.theme, onTap: () => taps++)),
        );
        expect(find.text('Theme'), findsOneWidget);
        expect(find.text('Light'), findsOneWidget);
        await t.tap(find.byType(PzCard));
        expect(taps, 1);
      });

      testWidgets('row is at least 56 high', (t) async {
        await t.pumpWidget(wrap(PzRow(label: 'Language', onTap: () {})));
        expect(t.getSize(find.byType(PzRow)).height, greaterThanOrEqualTo(56));
      });

      testWidgets('chips show icon plus label for status', (t) async {
        await t.pumpWidget(
          wrap(const Column(children: <Widget>[
            PzChip(label: 'Sent', tone: PzChipTone.success),
            PzChip(label: 'Shortened', tone: PzChipTone.warning),
            PzChip(label: 'Failed', tone: PzChipTone.error),
            PzChip(label: 'Drafts', selected: true),
          ])),
        );
        expect(find.text('Sent'), findsOneWidget);
        expect(find.text('Drafts'), findsOneWidget);
        expect(t.getSize(find.byType(PzChip).first).height, greaterThanOrEqualTo(32));
      });

      testWidgets('empty state shows its words and action', (t) async {
        await t.pumpWidget(
          wrap(PzEmptyState(
            icon: PzIcons.queue,
            title: 'Nothing queued',
            subtitle: 'Write a post',
            action: PzPrimaryButton(label: 'New post', onPressed: () {}),
          )),
        );
        expect(find.text('Nothing queued'), findsOneWidget);
        expect(find.text('Write a post'), findsOneWidget);
        expect(find.text('New post'), findsOneWidget);
      });

      testWidgets('nav bar: back and actions respond', (t) async {
        int backs = 0;
        int acts = 0;
        await t.pumpWidget(
          wrap(PzNavBar(
            title: 'Library',
            onBack: () => backs++,
            backLabel: 'Back',
            actions: <PzNavAction>[
              PzNavAction(icon: PzIcons.add, label: 'Add', onTap: () => acts++),
            ],
          )),
        );
        expect(find.text('Library'), findsOneWidget);
        await t.tap(find.byType(PzIconChip).first);
        await t.tap(find.byType(PzIconChip).last);
        expect(backs, 1);
        expect(acts, 1);
      });

      testWidgets('platform mark and section header render', (t) async {
        await t.pumpWidget(
          wrap(const Column(children: <Widget>[
            PzPlatformMark(monogram: 'In', size: 40, name: 'Instagram'),
            PzSectionHeader('Today'),
          ])),
        );
        expect(find.text('In'), findsOneWidget);
        expect(find.text('TODAY'), findsOneWidget);
      });

      testWidgets('nothing overflows at 2.0 text scale', (t) async {
        await t.pumpWidget(
          wrap(
            Column(children: <Widget>[
              PzNavBar(
                title: 'A rather long screen title',
                brand: null,
                onBack: () {},
                backLabel: 'Back',
                actions: <PzNavAction>[
                  PzNavAction(icon: PzIcons.add, label: 'Add', onTap: () {}),
                ],
              ),
              PzCard.summary(label: 'Default card theme', value: 'Midnight', icon: PzIcons.theme, onTap: () {}),
              PzRow(label: 'Notifications are off', subtitle: 'Turn them on in system settings', icon: PzIcons.bell, onTap: () {}),
              const Wrap(children: <Widget>[
                PzChip(label: 'All'),
                PzChip(label: 'Scheduled', selected: true),
                PzChip(label: 'Caption shortened', tone: PzChipTone.warning),
              ]),
              PzPrimaryButton(label: 'Preview variants', onPressed: () {}),
              PzSecondaryButton(label: 'Restore purchases', onPressed: () {}),
            ]),
            scale: 2,
          ),
        );
        expect(tester(t), isNull);
      });

      testWidgets('works right to left', (t) async {
        await t.pumpWidget(
          wrap(
            Column(children: <Widget>[
              PzRow(label: 'اللغة', onTap: () {}),
              PzCard.summary(label: 'المظهر', value: 'فاتح', onTap: () {}),
            ]),
            dir: TextDirection.rtl,
          ),
        );
        expect(find.text('اللغة'), findsOneWidget);
        expect(t.takeException(), isNull);
      });

      testWidgets('error view offers retry only when retriable', (t) async {
        int retries = 0;
        await t.pumpWidget(
          wrap(PzErrorView(
            error: AppError.of(AppErrorKind.renderFailed),
            title: 'Could not render',
            message: 'Try again.',
            retryLabel: 'Try again',
            onRetry: () => retries++,
          )),
        );
        await t.tap(find.text('Try again').last);
        expect(retries, 1);
        await t.pumpWidget(
          wrap(PzErrorView(
            error: AppError.of(AppErrorKind.dbDowngrade),
            title: 'Update needed',
            message: 'This data is from a newer version.',
            retryLabel: 'Try again',
            onRetry: () => retries++,
          )),
        );
        expect(find.text('Try again'), findsNothing);
      });
    });
  }

  testWidgets('the fatal error view works above the app theme', (t) async {
    await t.pumpWidget(
      PzErrorView(
        error: AppError.of(AppErrorKind.unexpected),
        title: 'Something went wrong',
        message: 'Please restart.',
        fatal: true,
      ),
    );
    expect(find.text('Something went wrong'), findsOneWidget);
  });

  group('PzLoadingIndicator', () {
    testWidgets('appears only after its delay and then turns', (t) async {
      await t.pumpWidget(harness(const PzLoadingIndicator()));
      expect(t.getSize(find.byType(PzLoadingIndicator)), Size.zero);
      await t.pump(const Duration(milliseconds: 310));
      expect(t.getSize(find.byType(PzLoadingIndicator)), const Size.square(24));
      await t.pumpWidget(const SizedBox.shrink());
    });
  });

  group('contrast', () {
    double ratio(Color a, Color b) {
      final double la = a.computeLuminance();
      final double lb = b.computeLuminance();
      final double hi = la > lb ? la : lb;
      final double lo = la > lb ? lb : la;
      return (hi + 0.05) / (lo + 0.05);
    }

    for (final Brightness brightness in Brightness.values) {
      test('text on the selected-chip tint meets 4.5:1 in ${brightness.name}', () {
        final PzThemeData theme = PzThemeData.of(brightness);
        expect(ratio(theme.colors.textPrimary, theme.accentTint), greaterThanOrEqualTo(4.5));
        expect(ratio(theme.colors.accent, theme.accentTint), greaterThanOrEqualTo(3));
      });
    }
  });
}

/// Returns the exception the tester caught, so a layout overflow fails the test.
Object? tester(WidgetTester t) => t.takeException();
