import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalWidgetsLocalizations;
import 'package:postzera/app_routes.dart';
import 'package:postzera/app_services.dart';
import 'package:postzera/core/data/app_links.dart';
import 'package:postzera/core/models/app_error.dart';
import 'package:postzera/core/ports/notification_port.dart';
import 'package:postzera/core/providers/banner_provider.dart';
import 'package:postzera/l10n/app_localizations.dart';
import 'package:postzera/l10n/localized_text.dart';
import 'package:postzera/screens/routes.dart';
import 'package:postzera/screens/screen_services.dart';
import 'package:postzera/theme/pz_motion.dart';
import 'package:postzera/theme/pz_theme.dart';
import 'package:postzera/utils/global_error_handler.dart';
import 'package:postzera/widgets/pz_banner.dart';
import 'package:postzera/widgets/pz_error_view.dart';
import 'package:postzera/widgets/pz_page_route.dart';
import 'package:postzera/widgets/pz_system_ui.dart';

/// Counts "Try again" presses on the fatal view. The app listens to it, goes
/// back to the queue and rebuilds, with all data intact.
final ValueNotifier<int> appRestarts = ValueNotifier<int>(0);

/// Clears the fatal error and returns to the queue.
void restartAppView() {
  fatalError.value = null;
  appRestarts.value++;
}

/// Opens the support page, from the fatal view that covers the app.
Future<bool> openSupportPage(ScreenServices services) =>
    services.links.open(Uri.parse(AppLinks.supportUrl));

/// The whole app: theme, language, the two localization delegates, the banner
/// host, the fatal-error gate and the navigator.
class PostzeraApp extends StatefulWidget {
  const PostzeraApp({required this.services, super.key});

  final ScreenServices services;

  @override
  State<PostzeraApp> createState() => _PostzeraAppState();
}

class _PostzeraAppState extends State<PostzeraApp> with WidgetsBindingObserver {
  final AppRouter _router = AppRouter();
  StreamSubscription<NotificationTap>? _taps;
  late Brightness _platformBrightness;
  String? _textsLanguage;

  ScreenServices get _s => widget.services;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _platformBrightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    _taps = _s.reminders.taps.listen((NotificationTap tap) {
      unawaited(_s.queue.load());
      _router.showQueue();
    });
    appRestarts.addListener(_onRestart);
  }

  void _onRestart() => _router.showQueue();

  @override
  void didChangePlatformBrightness() {
    setState(() {
      _platformBrightness =
          WidgetsBinding.instance.platformDispatcher.platformBrightness;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    appRestarts.removeListener(_onRestart);
    unawaited(_taps?.cancel());
    super.dispose();
  }

  /// Retry on a banner: replan reminders or reconnect to the store. Other
  /// errors are retried where they happened, so the banner just closes.
  void _retry(BannerItem item) {
    final AppErrorKind? kind = item.error?.kind;
    if (kind == AppErrorKind.scheduleFailed) {
      unawaited(_s.reminders.sync());
    } else if (kind == AppErrorKind.purchaseFailed ||
        kind == AppErrorKind.storeUnavailable) {
      unawaited(_s.entitlement.connect());
    }
    _s.banners.removeSticky(item.id);
    _s.banners.dismiss();
  }

  @override
  Widget build(BuildContext context) {
    return ServicesScope(
      services: _s,
      child: ListenableBuilder(
        listenable: Listenable.merge(<Listenable>[
          _s.theme,
          _s.locale,
          appRestarts,
        ]),
        builder: (BuildContext context, Widget? _) {
          final bool dark = _s.theme.isDark(
            systemIsDark: _platformBrightness == Brightness.dark,
          );
          final PzThemeData theme = PzThemeData.of(
            dark ? Brightness.dark : Brightness.light,
          );
          final String? code = _s.locale.value;
          final bool onboarded = _s.settings.value.settings.onboardingDone;
          return PzTheme(
            data: theme,
            child: PzSystemUi(
              child: _ThemeFade(
                brightness: theme.brightness,
                child: WidgetsApp(
                  navigatorKey: _router.navigatorKey,
                  color: theme.colors.bgPrimary,
                  locale: code == null ? null : Locale(code),
                  localizationsDelegates:
                      const <LocalizationsDelegate<dynamic>>[
                        AppLocalizations.delegate,
                        GlobalWidgetsLocalizations.delegate,
                      ],
                  supportedLocales: AppLocalizations.supportedLocales,
                  initialRoute: onboarded ? Routes.queue : Routes.onboarding,
                  onGenerateInitialRoutes: _router.initialRoutes,
                  onGenerateRoute: _router.generateRoute,
                  builder: (BuildContext context, Widget? child) =>
                      _shell(context, theme, child),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _shell(BuildContext context, PzThemeData theme, Widget? child) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    _s.reminders.texts = notificationTextsFor(l10n);
    final String language = l10n.localeName;
    if (_textsLanguage != null && _textsLanguage != language) {
      // Scheduled notifications keep the old language until they are planned
      // again. Not during this build: the sync notifies its listeners.
      WidgetsBinding.instance.addPostFrameCallback(
        (Duration _) => unawaited(_s.reminders.sync()),
      );
    }
    _textsLanguage = language;
    return DefaultTextStyle(
      style: theme.text.body,
      child: PzBannerHost(
        banners: _s.banners,
        undo: _s.undo,
        onRetry: _retry,
        child: _FatalGate(
          services: _s,
          child: child ?? const SizedBox.shrink(),
        ),
      ),
    );
  }
}

/// Puts the fatal-error view over the app when something unrecoverable has
/// been reported, without disturbing the screens under it.
class _FatalGate extends StatelessWidget {
  const _FatalGate({required this.services, required this.child});

  final ScreenServices services;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppError?>(
      valueListenable: fatalError,
      builder: (BuildContext context, AppError? error, Widget? _) {
        return Stack(
          textDirection: TextDirection.ltr,
          fit: StackFit.expand,
          children: <Widget>[
            child,
            if (error != null)
              Positioned.fill(
                child: FatalErrorView(
                  error: error,
                  onRetry: restartAppView,
                  onSupport: () => unawaited(openSupportPage(services)),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// The fatal-error layout: icon, message, Try again and a support link. It
/// works with or without localizations or a theme above it, so it can be the
/// replacement for any widget that failed to build, and never shows a grey
/// screen.
class FatalErrorView extends StatelessWidget {
  const FatalErrorView({
    required this.error,
    this.onRetry,
    this.onSupport,
    super.key,
  });

  final AppError error;

  /// Left out where trying again cannot help, such as a database that is
  /// newer than the app.
  final VoidCallback? onRetry;
  final VoidCallback? onSupport;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n =
        Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        lookupAppLocalizations(const Locale('en'));
    return PzErrorView(
      error: error,
      title: l10n.fatal_title,
      message: error.kind == AppErrorKind.unexpected
          ? l10n.fatal_message
          : errorText(l10n, error),
      retryLabel: l10n.fatal_tryAgain,
      onRetry: onRetry,
      supportLabel: l10n.fatal_support,
      onSupport: onSupport,
      fatal: true,
    );
  }
}

/// The app that runs when startup itself fails (a database from a newer
/// version, or storage that cannot be opened). It has no services.
class FatalApp extends StatelessWidget {
  const FatalApp({required this.error, this.onSupport, super.key});

  final AppError error;
  final VoidCallback? onSupport;

  @override
  Widget build(BuildContext context) {
    final PzThemeData theme = PzThemeData.of(
      WidgetsBinding.instance.platformDispatcher.platformBrightness,
    );
    return PzTheme(
      data: theme,
      child: PzSystemUi(
        child: WidgetsApp(
          color: theme.colors.bgPrimary,
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            AppLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          onGenerateRoute: (RouteSettings settings) => PzPageRoute<void>(
            settings: settings,
            builder: (BuildContext context) =>
                FatalErrorView(error: error, onSupport: onSupport),
          ),
        ),
      ),
    );
  }
}

/// Softens a change of theme: the new colors appear at once, under a veil of
/// the old page color that fades out over 200 ms. The navigator is never
/// rebuilt, so no screen loses its state. With Reduce Motion it is instant.
class _ThemeFade extends StatefulWidget {
  const _ThemeFade({required this.brightness, required this.child});

  final Brightness brightness;
  final Widget child;

  @override
  State<_ThemeFade> createState() => _ThemeFadeState();
}

class _ThemeFadeState extends State<_ThemeFade>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: PzMotion.themeChange,
  );
  Brightness? _from;

  @override
  void didUpdateWidget(_ThemeFade oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.brightness == widget.brightness) {
      return;
    }
    final bool instant = WidgetsBinding
        .instance
        .platformDispatcher
        .accessibilityFeatures
        .disableAnimations;
    if (instant) {
      _from = null;
      return;
    }
    _from = oldWidget.brightness;
    _controller.value = 1;
    unawaited(
      _controller.reverse().whenComplete(() {
        if (mounted) {
          setState(() => _from = null);
        }
      }),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Brightness? from = _from;
    return Stack(
      textDirection: TextDirection.ltr,
      fit: StackFit.expand,
      children: <Widget>[
        widget.child,
        if (from != null)
          IgnorePointer(
            child: FadeTransition(
              opacity: _controller,
              child: ColoredBox(
                color: PzThemeData.of(from).colors.bgPrimary,
              ),
            ),
          )
        else
          const SizedBox.shrink(),
      ],
    );
  }
}
