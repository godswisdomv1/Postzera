import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postzera/theme/pz_colors.dart';
import 'package:postzera/theme/pz_radii.dart';
import 'package:postzera/theme/pz_theme.dart';
import 'package:postzera/theme/pz_typography.dart';

double _contrast(Color a, Color b) {
  final double la = a.computeLuminance();
  final double lb = b.computeLuminance();
  final double hi = la > lb ? la : lb;
  final double lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  for (final MapEntry<String, PzColors> mode in <String, PzColors>{
    'light': PzColors.light,
    'dark': PzColors.dark,
  }.entries) {
    group('${mode.key} colors', () {
      final PzColors c = mode.value;
      final List<Color> backgrounds = <Color>[
        c.bgPrimary,
        c.bgSecondary,
        c.bgTertiary,
      ];

      test('text and status colors reach 4.5:1 on every background', () {
        final Map<String, Color> text = <String, Color>{
          'textPrimary': c.textPrimary,
          'textSecondary': c.textSecondary,
          'textTertiary': c.textTertiary,
          'error': c.error,
          'success': c.success,
          'warning': c.warning,
        };
        text.forEach((String name, Color color) {
          for (final Color bg in backgrounds) {
            expect(
              _contrast(color, bg),
              greaterThanOrEqualTo(4.5),
              reason: '$name on $bg',
            );
          }
        });
      });

      test('label on the accent fill reaches 4.5:1', () {
        expect(_contrast(c.onAccent, c.accent), greaterThanOrEqualTo(4.5));
        expect(_contrast(c.onAccent, c.accentDim), greaterThanOrEqualTo(4.5));
      });
    });
  }

  test('PzColors.of picks by brightness', () {
    expect(PzColors.of(Brightness.light), same(PzColors.light));
    expect(PzColors.of(Brightness.dark), same(PzColors.dark));
  });

  test('Inter optical size follows the 14 / 32 rule', () {
    expect(interOpticalSize(12), 14);
    expect(interOpticalSize(17), 14);
    expect(interOpticalSize(28), 32);
    expect(interOpticalSize(34), 32);
    expect(interOpticalSize(22.5), greaterThan(14));
    expect(interOpticalSize(22.5), lessThan(32));
  });

  test('typography roles use the right family, size and weight', () {
    final PzTypography t = PzTypography.of(PzColors.light);
    expect(t.display.fontFamily, PzFonts.newsreader);
    expect(t.display.fontFamilyFallback, contains(PzFonts.inter));
    expect(t.display.fontSize, 34);
    expect(t.display.fontWeight, FontWeight.w600);
    expect(t.body.fontFamily, PzFonts.inter);
    expect(t.body.fontSize, 17);
    expect(t.body.fontWeight, FontWeight.w400);
    expect(t.counter.fontFamily, PzFonts.mono);
    expect(t.counter.fontSize, 13);
    expect(t.sectionHeader.letterSpacing, 0.8);
  });

  test('pill radius is half the height', () {
    expect(PzRadii.pill(32), const BorderRadius.all(Radius.circular(16)));
  });

  testWidgets('PzTheme.of returns the nearest theme', (
    WidgetTester tester,
  ) async {
    PzThemeData? seen;
    await tester.pumpWidget(
      PzTheme(
        data: PzThemeData.dark,
        child: Builder(
          builder: (BuildContext context) {
            seen = PzTheme.of(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(seen, same(PzThemeData.dark));
    expect(seen!.isDark, isTrue);
  });
}
