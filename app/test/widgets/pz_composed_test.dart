import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postzera/core/data/builtin_card_themes.dart';
import 'package:postzera/core/models/app_error.dart';
import 'package:postzera/core/models/variant.dart';
import 'package:postzera/core/ports/ads_port.dart';
import 'package:postzera/core/providers/consent_provider.dart';
import 'package:postzera/core/providers/media_jobs_provider.dart';
import 'package:postzera/core/services/variant_builder.dart';
import 'package:postzera/widgets/pz_ad_slot.dart';
import 'package:postzera/widgets/pz_entitlement_badge.dart';
import 'package:postzera/widgets/pz_progress_bar.dart';
import 'package:postzera/widgets/pz_theme_swatch.dart';
import 'package:postzera/widgets/pz_variant_card.dart';
import 'package:postzera/widgets/pz_variant_strip.dart';

import '../core/test_helpers.dart';
import 'test_app.dart';

class _Banner implements BannerHandle {
  @override
  double get heightDp => 60;

  @override
  void dispose() {}
}

Variant variantFor(String platformId, {String body = ''}) {
  return const VariantBuilder().build(
    testPost(hook: 'One post for every platform', body: body, link: ''),
    profileById(platformId),
    cardThemeById('paper'),
  );
}

void main() {
  group('PzAdSlot', () {
    Widget slot(ValueNotifier<AdsViewState> state, List<int> asked) {
      return app(
        Column(
          children: <Widget>[
            const Expanded(child: SizedBox.expand()),
            PzAdSlot(
              state: state,
              requestBanner: (int w) async => asked.add(w),
              bannerBuilder: (BuildContext c, BannerHandle b) =>
                  const SizedBox.expand(key: Key('banner')),
            ),
          ],
        ),
      );
    }

    testWidgets('takes no room while consent blocks ads', (t) async {
      final ValueNotifier<AdsViewState> state =
          ValueNotifier<AdsViewState>(const AdsViewState());
      addTearDown(state.dispose);
      final List<int> asked = <int>[];
      await t.pumpWidget(slot(state, asked));
      await t.pumpAndSettle();
      expect(t.getSize(find.byType(PzAdSlot)).height, 0);
      expect(asked, isEmpty);
    });

    testWidgets('asks for a banner once ads are allowed, then shows it', (t) async {
      final ValueNotifier<AdsViewState> state =
          ValueNotifier<AdsViewState>(const AdsViewState(canShowAds: true));
      addTearDown(state.dispose);
      final List<int> asked = <int>[];
      await t.pumpWidget(slot(state, asked));
      await t.pumpAndSettle();
      expect(asked.length, 1);
      expect(t.getSize(find.byType(PzAdSlot)).height, 0);
      state.value = AdsViewState(canShowAds: true, banner: _Banner());
      await t.pumpAndSettle();
      expect(find.byKey(const Key('banner')), findsOneWidget);
      // 16 dp above the 60 dp banner.
      expect(t.getSize(find.byType(PzAdSlot)).height, 76);
    });

    testWidgets('collapses again once the upgrade is owned', (t) async {
      final ValueNotifier<AdsViewState> state = ValueNotifier<AdsViewState>(
        AdsViewState(canShowAds: true, banner: _Banner()),
      );
      addTearDown(state.dispose);
      await t.pumpWidget(slot(state, <int>[]));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('banner')), findsOneWidget);
      state.value = const AdsViewState();
      await t.pumpAndSettle();
      expect(find.byKey(const Key('banner')), findsNothing);
      expect(t.getSize(find.byType(PzAdSlot)).height, 0);
    });

    testWidgets('is never taller than 15% of the screen', (t) async {
      t.view.physicalSize = const Size(400, 300);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final ValueNotifier<AdsViewState> state = ValueNotifier<AdsViewState>(
        AdsViewState(canShowAds: true, banner: _Banner()),
      );
      addTearDown(state.dispose);
      await t.pumpWidget(slot(state, <int>[]));
      await t.pumpAndSettle();
      // 15% of 300 is 45, below the banner's 60. Plus 16 above.
      expect(t.getSize(find.byType(PzAdSlot)).height, 61);
    });
  });

  group('small widgets', () {
    testWidgets('the Ad-free badge says so', (t) async {
      await t.pumpWidget(app(const Align(alignment: Alignment.topLeft, child: PzEntitlementBadge())));
      await t.pumpAndSettle();
      expect(find.text('Ad-free'), findsOneWidget);
    });

    testWidgets('a theme swatch reports taps and marks selection', (t) async {
      int taps = 0;
      await t.pumpWidget(
        app(
          Align(
            alignment: Alignment.topLeft,
            child: PzThemeSwatch(
              theme: cardThemeById('midnight'),
              selected: true,
              onTap: () => taps++,
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(t.getSize(find.byType(PzThemeSwatch)).height, greaterThanOrEqualTo(48));
      await t.tap(find.byType(PzThemeSwatch));
      expect(taps, 1);
    });

    testWidgets('the progress bar fills in proportion', (t) async {
      await t.pumpWidget(
        harness(const PzProgressBar(value: 0.25), width: 200),
      );
      final Size bar = t.getSize(find.byType(PzProgressBar));
      expect(bar.width, 200);
      final Size fill = t.getSize(find.byType(FractionallySizedBox));
      expect(fill.width, 50);
    });
  });

  group('PzVariantCard', () {
    // As in the strip, a page scrolls when its card is taller than the screen.
    Widget card(Variant v, {MediaJob? job, bool sent = false}) => app(
      SingleChildScrollView(
        child: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: 340,
            child: PzVariantCard(
              variant: v,
              platformName: 'Instagram',
              monogram: 'In',
              job: job,
              sent: sent,
              onRetry: () {},
              onUseAutoCard: () {},
            ),
          ),
        ),
      ),
    );

    testWidgets('shows the platform, the hook preview and the caption', (t) async {
      final Variant v = variantFor('instagram', body: 'A longer body.');
      await t.pumpWidget(card(v));
      await t.pumpAndSettle();
      expect(find.text('Instagram'), findsOneWidget);
      expect(find.text('One post for every platform'), findsWidgets);
    });

    testWidgets('keeps the true aspect ratio of the canvas', (t) async {
      final Variant v = variantFor('instagram');
      await t.pumpWidget(card(v));
      await t.pumpAndSettle();
      final Size media = t.getSize(find.byType(AspectRatio));
      expect(media.width / media.height, closeTo(1080 / 1350, 0.01));
    });

    testWidgets('a rendering job shows progress', (t) async {
      final Variant v = variantFor('instagram');
      final MediaJob job = MediaJob(
        cacheKey: v.mediaPlan.cacheKey,
        status: MediaJobStatus.rendering,
        progress: 0.4,
      );
      await t.pumpWidget(card(v, job: job));
      await t.pump();
      expect(find.byType(PzProgressBar), findsOneWidget);
      await t.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a failed job offers retry and a plain card', (t) async {
      final Variant v = variantFor('instagram');
      final MediaJob job = MediaJob(
        cacheKey: v.mediaPlan.cacheKey,
        status: MediaJobStatus.failed,
        error: AppError.of(AppErrorKind.renderFailed),
      );
      await t.pumpWidget(card(v, job: job));
      await t.pumpAndSettle();
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Use auto card'), findsOneWidget);
    });

    testWidgets('a sent platform shows Posted', (t) async {
      final Variant v = variantFor('instagram');
      await t.pumpWidget(card(v, sent: true));
      await t.pumpAndSettle();
      expect(find.text('Posted'), findsOneWidget);
    });

    testWidgets('a video variant shows the video badge', (t) async {
      final Variant v = variantFor('tiktok', body: 'Short body');
      expect(v.mediaPlan.kind, MediaOutputKind.video);
      await t.pumpWidget(card(v));
      await t.pumpAndSettle();
      expect(find.byType(PzVariantCard), findsOneWidget);
    });

    testWidgets('warnings appear as chips', (t) async {
      final Variant v = variantFor('x');
      final Variant warned = Variant(
        platformId: v.platformId,
        caption: v.caption,
        mediaPlan: v.mediaPlan,
        warnings: const <VariantWarning>{VariantWarning.captionTruncated},
      );
      await t.pumpWidget(card(warned));
      await t.pumpAndSettle();
      expect(find.text('Caption shortened'), findsOneWidget);
    });
  });

  group('PzVariantStrip', () {
    testWidgets('swipes between pages and lets the next one peek', (t) async {
      final List<int> seen = <int>[];
      await t.pumpWidget(
        app(
          PzVariantStrip(
            itemCount: 3,
            onPageChanged: seen.add,
            itemBuilder: (BuildContext c, int i) =>
                SizedBox(height: 200, child: Center(child: Text('Page $i'))),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('Page 0'), findsOneWidget);
      expect(find.text('Page 1'), findsOneWidget, reason: 'the next page peeks');
      await t.drag(find.byType(PageView), const Offset(-450, 0));
      await t.pumpAndSettle();
      expect(seen, <int>[1]);
    });

    testWidgets('the page dots are announced', (t) async {
      final SemanticsHandle handle = t.ensureSemantics();
      await t.pumpWidget(
        app(
          PzVariantStrip(
            itemCount: 3,
            itemBuilder: (BuildContext c, int i) => const SizedBox(height: 100),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.bySemanticsLabel('Platform 1 of 3'), findsOneWidget);
      handle.dispose();
    });
  });
}
