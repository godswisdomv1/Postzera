import 'package:flutter/foundation.dart' show LicenseEntry, LicenseEntryWithLineBreaks, LicenseRegistry;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:postzera/core/models/app_settings.dart';
import 'package:postzera/core/models/platform_profile.dart';
import 'package:postzera/core/models/platform_template.dart';
import 'package:postzera/core/models/post.dart';
import 'package:postzera/core/ports/file_import_port.dart';
import 'package:postzera/core/ports/purchase_port.dart';
import 'package:postzera/screens/routes.dart';
import 'package:postzera/widgets/foundation/pz_icon_chip.dart';
import 'package:postzera/widgets/pz_switch.dart';

import '../core/fakes.dart';
import 'screens_app.dart';
import 'screens_test.dart' show reveal, screenTest, settle, tapText, phone;
import 'test_services.dart';

Finder chipLabelled(String label) => find.byWidgetPredicate(
  (Widget w) => w is PzIconChip && w.semanticLabel == label,
);

void main() {
  setUpAll(initializeDateFormatting);

  group('PlatformsScreen', () {
    screenTest('lists every platform and switches one off', (t) async {
      phone(t);
      final TestServices s = await TestServices.create();
      addTearDown(s.dispose);
      await t.pumpWidget(screensApp(s, initial: Routes.platforms));
      await settle(t);
      expect(find.text('X'), findsWidgets);
      expect(find.text('Instagram'), findsOneWidget);
      await t.tap(find.byType(PzSwitch).first);
      await settle(t);
      expect(s.profiles.value.byId('x')!.enabled, isFalse);
    });

    screenTest('moves a platform down', (t) async {
      phone(t);
      final TestServices s = await TestServices.create();
      addTearDown(s.dispose);
      await t.pumpWidget(screensApp(s, initial: Routes.platforms));
      await settle(t);
      expect(s.profiles.value.profiles.first.id, 'x');
      await t.tap(chipLabelled('Move down').first);
      await settle(t);
      expect(s.profiles.value.profiles.first.id, isNot('x'));
    });

    screenTest('adds a custom platform', (t) async {
      phone(t);
      final TestServices s = await TestServices.create();
      addTearDown(s.dispose);
      await t.pumpWidget(screensApp(s, initial: Routes.platforms));
      await settle(t);
      await t.tap(find.text('Add platform').last);
      await settle(t, 10);
      await t.enterText(find.byType(EditableText).at(0), 'Mastodon');
      await t.enterText(find.byType(EditableText).at(1), 'Ma');
      await t.pump();
      await tapText(t, 'Add');
      await settle(t, 10);
      expect(
        s.profiles.value.profiles.any(
          (PlatformProfile p) => p.name == 'Mastodon' && p.isCustom,
        ),
        isTrue,
      );
    });

    screenTest('a bad form shows an error and adds nothing', (t) async {
      phone(t);
      final TestServices s = await TestServices.create();
      addTearDown(s.dispose);
      await t.pumpWidget(screensApp(s, initial: Routes.platforms));
      await settle(t);
      final int before = s.profiles.value.profiles.length;
      await t.tap(find.text('Add platform').last);
      await settle(t, 10);
      await tapText(t, 'Add');
      await settle(t, 6);
      expect(find.text('Check the name, the letters and the numbers.'), findsOneWidget);
      expect(s.profiles.value.profiles.length, before);
    });
  });

  group('TemplateEditorScreen', () {
    Future<TestServices> editor(WidgetTester t) async {
      phone(t);
      final TestServices s = await TestServices.create();
      addTearDown(s.dispose);
      await t.pumpWidget(
        screensApp(
          s,
          initial: Routes.templateEditor,
          arguments: const TemplateEditorArgs(platformId: 'x'),
        ),
      );
      await settle(t);
      return s;
    }

    screenTest('changes the caption limit and resets it', (t) async {
      final TestServices s = await editor(t);
      expect(s.profiles.value.byId('x')!.captionLimit, 280);
      await t.enterText(find.byType(EditableText).first, '140');
      await settle(t, 6);
      expect(s.profiles.value.byId('x')!.captionLimit, 140);
      await tapText(t, 'Reset to default');
      await settle(t, 8);
      expect(s.profiles.value.byId('x')!.captionLimit, 280);
    });

    screenTest('sets the hashtag placement and the image shape', (t) async {
      final TestServices s = await editor(t);
      await tapText(t, 'None');
      expect(s.profiles.value.byId('x')!.template.hashtagStyle, HashtagStyle.none);
      await tapText(t, '9:16');
      expect(s.profiles.value.byId('x')!.media.heightPx, 1920);
    });

    screenTest('reorders the parts', (t) async {
      final TestServices s = await editor(t);
      final TemplateSlot first = s.profiles.value.byId('x')!.template.blocks.first.slot;
      final Finder down = chipLabelled('Move down').first;
      await reveal(t, down);
      await t.tap(down);
      await settle(t, 6);
      expect(
        s.profiles.value.byId('x')!.template.blocks.first.slot,
        isNot(first),
      );
    });
  });

  group('ImportScreen', () {
    screenTest('checks a file, then imports the valid rows', (t) async {
      phone(t);
      final TestServices s = await TestServices.create();
      addTearDown(s.dispose);
      s.fakeImport.file = const ImportedFile(
        name: 'posts.csv',
        text: 'hook,body\nFirst,Body\n,No hook here\n',
      );
      await t.pumpWidget(screensApp(s, initial: Routes.importCsv));
      await settle(t);
      await tapText(t, 'Choose a CSV file');
      await settle(t, 8);
      expect(find.text('1 ready, 1 with problems'), findsOneWidget);
      expect(find.text('Line 3: the hook is empty'), findsOneWidget);
      await tapText(t, 'Import 1 post');
      await settle(t, 10);
      expect(s.posts.value.posts.length, 1);
      expect(find.text('Done'), findsOneWidget);
    });
  });

  group('SettingsScreen', () {
    Future<TestServices> settings(WidgetTester t) async {
      phone(t);
      final TestServices s = await TestServices.create();
      addTearDown(s.dispose);
      await t.pumpWidget(screensApp(s, initial: Routes.settings));
      await settle(t);
      return s;
    }

    screenTest('changes the theme and the language', (t) async {
      final TestServices s = await settings(t);
      await tapText(t, 'Dark');
      expect(s.theme.value, ThemeModeSetting.dark);
      await tapText(t, 'Language');
      await settle(t, 8);
      await t.tap(find.text('日本語'));
      await settle(t, 8);
      expect(s.locale.value, 'ja');
    });

    screenTest('shows Remove ads and opens the paywall', (t) async {
      phone(t);
      final TestServices s = await TestServices.create();
      addTearDown(s.dispose);
      final List<String> visited = <String>[];
      await t.pumpWidget(
        screensApp(s, initial: Routes.settings, visited: visited),
      );
      await settle(t);
      await tapText(t, 'Remove ads');
      expect(visited.last, Routes.paywall);
    });

    screenTest('the privacy choices row appears only when required', (t) async {
      final TestServices s = await settings(t);
      expect(find.text('Privacy choices'), findsNothing);
    });

    screenTest('turns the daily reminders off', (t) async {
      final TestServices s = await settings(t);
      expect(s.settings.value.settings.remindersEnabled, isTrue);
      await t.tap(find.byType(PzSwitch).first);
      await settle(t, 8);
      expect(s.settings.value.settings.remindersEnabled, isFalse);
    });

    screenTest('Delete all data asks first and leads to onboarding', (t) async {
      phone(t);
      final TestServices s = await TestServices.create(
        saved: <Post>[TestServices.scheduled('a')],
      );
      addTearDown(s.dispose);
      await t.pumpWidget(screensApp(s, initial: Routes.settings));
      await settle(t);
      await tapText(t, 'Delete all data');
      await settle(t, 8);
      expect(find.text('Delete all data?'), findsOneWidget);
      await t.tap(find.text('Delete everything'));
      await settle(t, 14);
      expect(await s.postRepo.all(), isEmpty);
      expect(find.text('route:/onboarding'), findsNothing);
    });
  });

  group('PaywallScreen', () {
    screenTest('shows the store price and offers restore', (t) async {
      phone(t);
      final TestServices s = await TestServices.create();
      addTearDown(s.dispose);
      await t.pumpWidget(screensApp(s, initial: Routes.paywall));
      await settle(t, 14);
      expect(find.text('Remove ads'), findsWidgets);
      expect(find.textContaining('Remove ads for'), findsOneWidget);
      expect(find.text('Restore purchases'), findsOneWidget);
    });

    screenTest('a completed purchase shows the thank-you', (t) async {
      phone(t);
      final TestServices s = await TestServices.create();
      addTearDown(s.dispose);
      s.purchases.onBuy = const PurchaseCompleted();
      await t.pumpWidget(screensApp(s, initial: Routes.paywall));
      await settle(t, 14);
      await t.tap(find.textContaining('Remove ads for'));
      await settle(t, 14);
      expect(find.text('The ads are removed. Thank you.'), findsOneWidget);
    });
  });

  group('OnboardingScreen', () {
    screenTest('walks three steps and then opens the queue', (t) async {
      phone(t);
      final TestServices s = await TestServices.create();
      addTearDown(s.dispose);
      await t.pumpWidget(screensApp(s, initial: Routes.onboarding));
      await settle(t);
      expect(find.text('Step 1 of 3'), findsOneWidget);
      expect(find.text('Where do you post?'), findsOneWidget);
      await tapText(t, 'Next');
      expect(find.text('Step 2 of 3'), findsOneWidget);
      await tapText(t, 'Next');
      expect(find.text('Step 3 of 3'), findsOneWidget);
      expect(find.text('Allow reminders?'), findsOneWidget);
      await tapText(t, 'Allow notifications');
      await settle(t, 14);
      expect(s.settings.value.settings.onboardingDone, isTrue);
      expect(find.text('Nothing queued'), findsOneWidget);
    });

    screenTest('every step can be skipped', (t) async {
      phone(t);
      final TestServices s = await TestServices.create();
      addTearDown(s.dispose);
      await t.pumpWidget(screensApp(s, initial: Routes.onboarding));
      await settle(t);
      await tapText(t, 'Skip');
      await tapText(t, 'Skip');
      expect(find.text('Step 3 of 3'), findsOneWidget);
      await tapText(t, 'Start');
      await settle(t, 14);
      expect(s.settings.value.settings.onboardingDone, isTrue);
    });
  });

  group('LicensesScreen', () {
    screenTest('lists a package and shows its license', (t) async {
      phone(t);
      LicenseRegistry.addLicense(
        () => Stream<LicenseEntry>.value(
          const LicenseEntryWithLineBreaks(<String>['Inter'], 'Open Font License text'),
        ),
      );
      final TestServices s = await TestServices.create();
      addTearDown(s.dispose);
      await t.pumpWidget(screensApp(s, initial: Routes.licenses));
      await settle(t, 14);
      expect(find.text('Inter'), findsOneWidget);
      await tapText(t, 'Inter');
      expect(find.text('Open Font License text'), findsOneWidget);
    });
  });
}
