import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:postzera/app.dart';
import 'package:postzera/core/models/app_error.dart';
import 'package:postzera/core/models/app_settings.dart';
import 'package:postzera/core/ports/notification_port.dart';
import 'package:postzera/screens/routes.dart';
import 'package:postzera/screens/settings_screen.dart';
import 'package:postzera/theme/pz_theme.dart';
import 'package:postzera/utils/global_error_handler.dart';

import '../screens/screens_test.dart' show phone, screenTest, settle, tapText;
import '../screens/test_services.dart';

void main() {
  setUpAll(initializeDateFormatting);
  tearDown(() => fatalError.value = null);

  group('PostzeraApp', () {
    screenTest('the first run opens onboarding', (t) async {
      phone(t);
      final TestServices s = await TestServices.create();
      addTearDown(s.dispose);
      await t.pumpWidget(PostzeraApp(services: s));
      await settle(t);
      expect(find.text('Where do you post?'), findsOneWidget);
      expect(find.text('Nothing queued'), findsNothing);
    });

    screenTest('after onboarding it opens the empty queue', (t) async {
      phone(t);
      final TestServices s = await TestServices.create();
      addTearDown(s.dispose);
      await s.settings.completeOnboarding();
      await t.pumpWidget(PostzeraApp(services: s));
      await settle(t);
      expect(find.text('Nothing queued'), findsOneWidget);
      expect(find.text('Where do you post?'), findsNothing);
    });

    screenTest('onboarding ends on the queue', (t) async {
      phone(t);
      final TestServices s = await TestServices.create();
      addTearDown(s.dispose);
      await t.pumpWidget(PostzeraApp(services: s));
      await settle(t);
      await tapText(t, 'Skip');
      await tapText(t, 'Skip');
      await tapText(t, 'Start');
      await settle(t, 16);
      expect(find.text('Nothing queued'), findsOneWidget);
      expect(s.settings.value.settings.onboardingDone, isTrue);
    });

    screenTest('a reminder tap brings the queue to the front', (t) async {
      phone(t);
      final TestServices s = await TestServices.create();
      addTearDown(s.dispose);
      await s.settings.completeOnboarding();
      await t.pumpWidget(PostzeraApp(services: s));
      await settle(t);
      unawaited(
        t
            .state<NavigatorState>(find.byType(Navigator))
            .pushNamed<void>(Routes.settings),
      );
      await settle(t);
      expect(find.byType(SettingsScreen), findsOneWidget);
      s.notifications.tapController.add(const NotificationTap(7));
      await settle(t, 16);
      expect(find.byType(SettingsScreen), findsNothing);
      expect(find.text('Nothing queued'), findsOneWidget);
    });

    screenTest('switching to the dark theme changes the tokens', (t) async {
      phone(t);
      final TestServices s = await TestServices.create();
      addTearDown(s.dispose);
      await s.settings.completeOnboarding();
      await t.pumpWidget(PostzeraApp(services: s));
      await settle(t);
      PzThemeData tokens() =>
          t.widget<PzTheme>(find.byType(PzTheme).first).data;
      expect(tokens().isDark, isFalse);
      await s.theme.setMode(ThemeModeSetting.dark);
      await t.pump();
      await t.pump(const Duration(milliseconds: 250));
      await settle(t);
      expect(tokens().isDark, isTrue);
      expect(find.text('Nothing queued'), findsOneWidget);
    });

    screenTest('a fatal error covers the app and Try again returns', (t) async {
      phone(t);
      final TestServices s = await TestServices.create();
      addTearDown(s.dispose);
      await s.settings.completeOnboarding();
      await t.pumpWidget(PostzeraApp(services: s));
      await settle(t);
      fatalError.value = AppError.of(AppErrorKind.unexpected);
      await settle(t, 4);
      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      await t.tap(find.text('Try again'));
      await settle(t, 8);
      expect(fatalError.value, isNull);
      expect(find.text('Something went wrong'), findsNothing);
      expect(find.text('Nothing queued'), findsOneWidget);
    });

    screenTest('the fatal view offers the support page', (t) async {
      phone(t);
      final TestServices s = await TestServices.create();
      addTearDown(s.dispose);
      await s.settings.completeOnboarding();
      await t.pumpWidget(PostzeraApp(services: s));
      await settle(t);
      fatalError.value = AppError.of(AppErrorKind.unexpected);
      await settle(t, 4);
      await t.tap(find.text('Contact support'));
      await settle(t, 2);
      expect(s.fakeLinks.opened.single.path, '/support');
    });
  });

  group('FatalApp', () {
    screenTest('a database from a newer version shows no Try again', (t) async {
      phone(t);
      await t.pumpWidget(
        FatalApp(error: AppError.of(AppErrorKind.dbDowngrade)),
      );
      await settle(t, 4);
      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.textContaining('newer version of Postzera'), findsOneWidget);
      expect(find.text('Try again'), findsNothing);
    });

    screenTest('the support link works when it is given', (t) async {
      phone(t);
      bool opened = false;
      await t.pumpWidget(
        FatalApp(
          error: AppError.of(AppErrorKind.unexpected),
          onSupport: () => opened = true,
        ),
      );
      await settle(t, 4);
      await t.tap(find.text('Contact support'));
      expect(opened, isTrue);
    });
  });

  group('FatalErrorView', () {
    screenTest('works with no theme or localizations above it', (t) async {
      phone(t);
      bool retried = false;
      await t.pumpWidget(
        FatalErrorView(
          error: AppError.of(AppErrorKind.unexpected),
          onRetry: () => retried = true,
        ),
      );
      expect(find.text('Something went wrong'), findsOneWidget);
      await t.tap(find.text('Try again'));
      expect(retried, isTrue);
    });
  });
}
