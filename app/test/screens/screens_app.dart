import 'package:flutter/widgets.dart';
import 'package:postzera/l10n/app_localizations.dart';
import 'package:postzera/screens/composer_screen.dart';
import 'package:postzera/screens/library_screen.dart';
import 'package:postzera/screens/queue_screen.dart';
import 'package:postzera/screens/routes.dart';
import 'package:postzera/screens/screen_services.dart';
import 'package:postzera/screens/send_screen.dart';
import 'package:postzera/screens/variants_screen.dart';
import 'package:postzera/theme/pz_theme.dart';
import 'package:postzera/widgets/pz_banner.dart';
import 'package:postzera/widgets/pz_page_route.dart';

/// A small copy of the app shell for screen tests: the real screens behind
/// their route names, and a plain text page for every screen that is not
/// built yet or is not under test.
Widget screensApp(
  ScreenServices services, {
  String initial = Routes.queue,
  Object? arguments,
  Brightness brightness = Brightness.light,
  List<String>? visited,
}) {
  return ServicesScope(
    services: services,
    child: PzTheme(
      data: PzThemeData.of(brightness),
      child: WidgetsApp(
        color: const Color(0xFFFFFFFF),
        locale: const Locale('en'),
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          AppLocalizations.delegate,
          DefaultWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        initialRoute: initial,
        onGenerateInitialRoutes: (String name) => <Route<dynamic>>[
          _route(RouteSettings(name: name, arguments: arguments), visited),
        ],
        onGenerateRoute: (RouteSettings settings) => _route(settings, visited),
        builder: (BuildContext context, Widget? child) => PzBannerHost(
          banners: services.banners,
          undo: services.undo,
          child: child ?? const SizedBox.shrink(),
        ),
      ),
    ),
  );
}

Route<dynamic> _route(RouteSettings settings, List<String>? visited) {
  visited?.add('${settings.name}');
  Widget page;
  switch (settings.name) {
    case Routes.queue:
      page = const QueueScreen();
    case Routes.library:
      page = const LibraryScreen();
    case Routes.compose:
      page = ComposerScreen(
        postId: (settings.arguments as ComposeArgs?)?.postId,
      );
    case Routes.variants:
      page = VariantsScreen(
        postId: (settings.arguments as VariantsArgs).postId,
      );
    case Routes.send:
      final SendArgs args = settings.arguments as SendArgs;
      page = SendScreen(postId: args.postId, platformId: args.platformId);
    default:
      page = Center(child: Text('route:${settings.name}'));
  }
  return PzPageRoute<void>(
    settings: settings,
    builder: (BuildContext context) => page,
  );
}
