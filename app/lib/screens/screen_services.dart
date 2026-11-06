import 'package:flutter/widgets.dart';
import 'package:postzera/core/ports/clock.dart';
import 'package:postzera/core/ports/share_port.dart';
import 'package:postzera/core/providers/banner_provider.dart';
import 'package:postzera/core/providers/composer_provider.dart';
import 'package:postzera/core/providers/consent_provider.dart';
import 'package:postzera/core/providers/entitlement_provider.dart';
import 'package:postzera/core/providers/import_provider.dart';
import 'package:postzera/core/providers/locale_provider.dart';
import 'package:postzera/core/providers/media_jobs_provider.dart';
import 'package:postzera/core/providers/posts_provider.dart';
import 'package:postzera/core/providers/profiles_provider.dart';
import 'package:postzera/core/providers/queue_provider.dart';
import 'package:postzera/core/providers/reminders_provider.dart';
import 'package:postzera/core/providers/settings_provider.dart';
import 'package:postzera/core/providers/theme_provider.dart';
import 'package:postzera/core/providers/undo_provider.dart';
import 'package:postzera/widgets/pz_ad_slot.dart';

/// Everything a screen may read: the providers, a clock, the link launcher and
/// the shell's banner drawing. The shell implements it (`AppServices`), and
/// tests implement it with fakes. Screens never see a plugin.
abstract interface class ScreenServices {
  ThemeProvider get theme;
  LocaleProvider get locale;
  SettingsProvider get settings;
  EntitlementProvider get entitlement;
  ConsentProvider get consent;
  PostsProvider get posts;
  ProfilesProvider get profiles;
  QueueProvider get queue;
  ComposerProvider get composer;
  MediaJobsProvider get media;
  RemindersProvider get reminders;
  ImportProvider get importer;
  UndoProvider get undo;
  BannerProvider get banners;
  Clock get clock;
  LinkPort get links;

  /// Draws a loaded banner with the ad plugin. Supplied by the shell.
  PzBannerBuilder get bannerBuilder;

  /// For the About row, for example "1.0.0 (1)".
  String get appVersion;
}

/// Hands the [ScreenServices] to every screen below it.
class ServicesScope extends InheritedWidget {
  const ServicesScope({
    required this.services,
    required super.child,
    super.key,
  });

  final ScreenServices services;

  static ScreenServices of(BuildContext context) {
    final ServicesScope? scope = context
        .dependOnInheritedWidgetOfExactType<ServicesScope>();
    assert(scope != null, 'No ServicesScope above this screen.');
    return scope!.services;
  }

  @override
  bool updateShouldNotify(ServicesScope oldWidget) =>
      oldWidget.services != services;
}
