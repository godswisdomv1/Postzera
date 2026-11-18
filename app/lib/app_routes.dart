import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:postzera/screens/composer_screen.dart';
import 'package:postzera/screens/import_screen.dart';
import 'package:postzera/screens/library_screen.dart';
import 'package:postzera/screens/licenses_screen.dart';
import 'package:postzera/screens/onboarding_screen.dart';
import 'package:postzera/screens/paywall_screen.dart';
import 'package:postzera/screens/platforms_screen.dart';
import 'package:postzera/screens/queue_screen.dart';
import 'package:postzera/screens/routes.dart';
import 'package:postzera/screens/send_screen.dart';
import 'package:postzera/screens/settings_screen.dart';
import 'package:postzera/screens/template_editor_screen.dart';
import 'package:postzera/screens/variants_screen.dart';
import 'package:postzera/widgets/pz_page_route.dart';

/// Maps route names to screens, with the app's own page transition, and owns
/// the navigator. An unknown name opens the queue, never a blank page.
class AppRouter {
  AppRouter() : navigatorKey = GlobalKey<NavigatorState>(debugLabel: 'postzera');

  final GlobalKey<NavigatorState> navigatorKey;

  List<Route<dynamic>> initialRoutes(String name) => <Route<dynamic>>[
    generateRoute(RouteSettings(name: name)),
  ];

  Route<dynamic> generateRoute(RouteSettings settings) {
    return PzPageRoute<void>(
      settings: settings,
      reduceMotion: _reduceMotion,
      builder: (BuildContext context) => _page(settings),
    );
  }

  /// Brings the queue to the front and drops every other screen. Used when a
  /// reminder is tapped.
  void showQueue() {
    final NavigatorState? navigator = navigatorKey.currentState;
    if (navigator == null) {
      return;
    }
    bool atQueue = false;
    navigator.popUntil((Route<dynamic> route) {
      if (route.isFirst) {
        atQueue = route.settings.name == Routes.queue;
        return true;
      }
      return false;
    });
    if (!atQueue) {
      unawaited(
        navigator.pushNamedAndRemoveUntil<void>(
          Routes.queue,
          (Route<dynamic> route) => false,
        ),
      );
    }
  }

  /// The system's Reduce Motion switch, read when a route is made because a
  /// route's durations have no context to ask.
  static bool get _reduceMotion => WidgetsBinding
      .instance
      .platformDispatcher
      .accessibilityFeatures
      .disableAnimations;

  static Widget _page(RouteSettings settings) {
    switch (settings.name) {
      case Routes.onboarding:
        return const OnboardingScreen();
      case Routes.compose:
        return ComposerScreen(
          postId: (settings.arguments as ComposeArgs?)?.postId,
        );
      case Routes.variants:
        return VariantsScreen(
          postId: (settings.arguments! as VariantsArgs).postId,
        );
      case Routes.send:
        final SendArgs args = settings.arguments! as SendArgs;
        return SendScreen(postId: args.postId, platformId: args.platformId);
      case Routes.library:
        return const LibraryScreen();
      case Routes.platforms:
        return const PlatformsScreen();
      case Routes.templateEditor:
        return TemplateEditorScreen(
          platformId: (settings.arguments! as TemplateEditorArgs).platformId,
        );
      case Routes.importCsv:
        return const ImportScreen();
      case Routes.settings:
        return const SettingsScreen();
      case Routes.paywall:
        return const PaywallScreen();
      case Routes.licenses:
        return const LicensesScreen();
      case Routes.queue:
      default:
        return const QueueScreen();
    }
  }
}
