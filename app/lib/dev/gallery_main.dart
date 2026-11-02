import 'package:flutter/widgets.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:postzera/core/providers/banner_provider.dart';
import 'package:postzera/core/providers/undo_provider.dart';
import 'package:postzera/dev/component_gallery.dart';
import 'package:postzera/dev/media_lab.dart';
import 'package:postzera/l10n/app_localizations.dart';
import 'package:postzera/theme/pz_spacing.dart';
import 'package:postzera/theme/pz_theme.dart';
import 'package:postzera/widgets/pz_banner.dart';
import 'package:postzera/widgets/pz_nav_bar.dart';
import 'package:postzera/widgets/pz_page_route.dart';
import 'package:postzera/widgets/pz_segmented_control.dart';

/// Checkpoint 1 entry point: the component gallery and the media lab, with
/// switches for light and dark and for 1.0 and 2.0 text scale. It starts no
/// services. Build it with `--target lib/dev/gallery_main.dart`.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting();
  runApp(const GalleryApp());
}

class GalleryApp extends StatefulWidget {
  const GalleryApp({super.key});

  @override
  State<GalleryApp> createState() => _GalleryAppState();
}

class _GalleryAppState extends State<GalleryApp> {
  Brightness _brightness = Brightness.light;
  double _scale = 1;
  int _page = 0;
  final BannerProvider _banners = BannerProvider();
  final UndoProvider _undo = UndoProvider();

  @override
  void dispose() {
    _banners.dispose();
    _undo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final PzThemeData theme = PzThemeData.of(_brightness);
    return PzTheme(
      data: theme,
      child: WidgetsApp(
        color: theme.colors.bgPrimary,
        locale: const Locale('en'),
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          AppLocalizations.delegate,
          DefaultWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        pageRouteBuilder: <T>(RouteSettings settings, WidgetBuilder builder) =>
            PzPageRoute<T>(settings: settings, builder: builder),
        builder: (BuildContext context, Widget? child) {
          return MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(_scale)),
            child: ColoredBox(
              color: theme.colors.bgPrimary,
              child: DefaultTextStyle(
                style: theme.text.body,
                child: child ?? const SizedBox.shrink(),
              ),
            ),
          );
        },
        home: _Shell(
          banners: _banners,
          undo: _undo,
          brightness: _brightness,
          scale: _scale,
          page: _page,
          onBrightness: (Brightness b) => setState(() => _brightness = b),
          onScale: (double s) => setState(() => _scale = s),
          onPage: (int i) => setState(() => _page = i),
        ),
      ),
    );
  }
}

class _Shell extends StatelessWidget {
  const _Shell({
    required this.banners,
    required this.undo,
    required this.brightness,
    required this.scale,
    required this.page,
    required this.onBrightness,
    required this.onScale,
    required this.onPage,
  });

  final BannerProvider banners;
  final UndoProvider undo;
  final Brightness brightness;
  final double scale;
  final int page;
  final ValueChanged<Brightness> onBrightness;
  final ValueChanged<double> onScale;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context) {
    final double bottom = MediaQuery.paddingOf(context).bottom;
    return PzBannerHost(
      banners: banners,
      undo: undo,
      child: Column(
        children: <Widget>[
          const PzNavBar(title: 'Postzera gallery'),
          // The controls keep their size so they stay usable at 2.0 scale.
          MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.noScaling),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: PzSpacing.screenPadding,
              ),
              child: Column(
                children: <Widget>[
                  PzSegmentedControl<int>(
                    segments: const <PzSegment<int>>[
                      PzSegment<int>(value: 0, label: 'Components'),
                      PzSegment<int>(value: 1, label: 'Media lab'),
                    ],
                    selected: page,
                    onChanged: onPage,
                  ),
                  const SizedBox(height: PzSpacing.sm),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: PzSegmentedControl<Brightness>(
                          segments: const <PzSegment<Brightness>>[
                            PzSegment<Brightness>(
                              value: Brightness.light,
                              label: 'Light',
                            ),
                            PzSegment<Brightness>(
                              value: Brightness.dark,
                              label: 'Dark',
                            ),
                          ],
                          selected: brightness,
                          onChanged: onBrightness,
                        ),
                      ),
                      const SizedBox(width: PzSpacing.sm),
                      Expanded(
                        child: PzSegmentedControl<double>(
                          segments: const <PzSegment<double>>[
                            PzSegment<double>(value: 1, label: '1.0x'),
                            PzSegment<double>(value: 2, label: '2.0x'),
                          ],
                          selected: scale,
                          onChanged: onScale,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: bottom),
              child: page == 0
                  ? ComponentGallery(banners: banners, undo: undo)
                  : const MediaLab(),
            ),
          ),
        ],
      ),
    );
  }
}
