import 'package:flutter/widgets.dart';
import 'package:postzera/l10n/app_localizations.dart';
import 'package:postzera/theme/pz_theme.dart';
import 'package:postzera/widgets/pz_page_route.dart';

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

/// A bare widget under the theme, a fixed width and optional text scale.
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
