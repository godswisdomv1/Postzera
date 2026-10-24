import 'package:flutter_test/flutter_test.dart';
import 'package:postzera/core/models/app_error.dart';
import 'package:postzera/core/models/consent_state.dart';
import 'package:postzera/core/models/entitlement.dart';
import 'package:postzera/core/ports/consent_port.dart';
import 'package:postzera/core/ports/purchase_port.dart';
import 'package:postzera/core/providers/banner_provider.dart';
import 'package:postzera/core/providers/consent_provider.dart';
import 'package:postzera/core/providers/entitlement_provider.dart';

import 'fakes.dart';
import 'test_helpers.dart';

Future<void> wait([int ms = 30]) =>
    Future<void>.delayed(Duration(milliseconds: ms));

void main() {
  final FixedClock clock = FixedClock(DateTime.utc(2026, 10, 18));

  group('EntitlementProvider', () {
    late FakePurchases purchases;
    late FakeSettingsStore store;
    late BannerProvider banners;
    late EntitlementProvider provider;

    setUp(() {
      purchases = FakePurchases();
      store = FakeSettingsStore();
      banners = BannerProvider();
      provider = EntitlementProvider(
        purchases: purchases,
        store: store,
        clock: clock,
        banners: banners,
      );
    });

    test('starts unknown with nothing cached', () async {
      await provider.init();
      expect(provider.entitlement.state, EntitlementState.unknown);
    });

    test('a cached Pro keeps ads off while the store is unreachable', () async {
      store.cache = const Entitlement(
        state: EntitlementState.pro,
        source: EntitlementSource.store,
      );
      await provider.init();
      purchases.owned = null;
      await provider.connect();
      expect(provider.entitlement.state, EntitlementState.pro);
      expect(provider.entitlement.source, EntitlementSource.cache);
    });

    test('a connected store saying not owned clears a cached Pro (refund)', () async {
      store.cache = const Entitlement(
        state: EntitlementState.pro,
        source: EntitlementSource.store,
      );
      await provider.init();
      purchases.owned = false;
      await provider.connect();
      await wait();
      expect(provider.entitlement.state, EntitlementState.free);
      expect(store.cache!.state, EntitlementState.free);
    });

    test('the store saying owned gives Pro and caches it', () async {
      await provider.init();
      purchases.owned = true;
      await provider.connect();
      await wait();
      expect(provider.entitlement.state, EntitlementState.pro);
      expect(store.cache!.state, EntitlementState.pro);
    });

    test('the localized price is loaded on connect', () async {
      await provider.init();
      await provider.connect();
      expect(provider.value.price, r'$41.99');
      expect(purchases.connects, 1);
    });

    test('buying completes into Pro with a success banner', () async {
      await provider.init();
      purchases.onBuy = const PurchaseCompleted();
      await provider.buy();
      await wait();
      expect(provider.entitlement.state, EntitlementState.pro);
      expect(provider.value.status, PurchaseStatus.idle);
      expect(banners.value.transient?.message, BannerMessage.adsRemoved);
    });

    test('a pending purchase gives no entitlement yet', () async {
      await provider.init();
      purchases.onBuy = const PurchasePending();
      await provider.buy();
      await wait();
      expect(provider.value.status, PurchaseStatus.pending);
      expect(provider.entitlement.state, EntitlementState.unknown);
    });

    test('a cancelled purchase is silent', () async {
      await provider.init();
      purchases.onBuy = const PurchaseCancelled();
      await provider.buy();
      await wait();
      expect(provider.value.status, PurchaseStatus.idle);
      expect(provider.value.error, isNull);
      expect(banners.value.transient, isNull);
    });

    test('a failed purchase shows a retryable error that can be cleared', () async {
      await provider.init();
      purchases.onBuy = PurchaseFailed(AppError.of(AppErrorKind.purchaseFailed));
      await provider.buy();
      await wait();
      expect(provider.value.error?.kind, AppErrorKind.purchaseFailed);
      expect(provider.value.status, PurchaseStatus.idle);
      provider.clearError();
      expect(provider.value.error, isNull);
    });

    test('restore that finds the purchase says so', () async {
      await provider.init();
      purchases.onRestore = const PurchaseOwnershipReported(owned: true);
      await provider.restore();
      await wait();
      expect(provider.entitlement.state, EntitlementState.pro);
      expect(banners.value.transient?.message, BannerMessage.purchaseRestored);
    });

    test('restore that finds nothing says so', () async {
      await provider.init();
      purchases.onRestore = const PurchaseOwnershipReported(owned: false);
      await provider.restore();
      await wait();
      expect(provider.entitlement.state, EntitlementState.free);
      expect(banners.value.transient?.message, BannerMessage.nothingToRestore);
    });
  });

  group('ConsentProvider', () {
    late FakePurchases purchases;
    late FakeSettingsStore store;
    late EntitlementProvider entitlement;
    late FakeConsent consent;
    late FakeAds ads;
    late ConsentProvider provider;

    ConsentProvider make({
      List<Duration> delays = const <Duration>[
        Duration(milliseconds: 5),
        Duration(milliseconds: 5),
        Duration(milliseconds: 5),
      ],
    }) =>
        ConsentProvider(
          consent: consent,
          ads: ads,
          entitlement: entitlement,
          clock: clock,
          retryDelays: delays,
        );

    const ConsentRefreshResult allowed = ConsentRefreshResult(
      updateOk: true,
      status: ConsentStatus.obtained,
      canRequestAds: true,
      privacyOptionsRequired: true,
    );
    const ConsentRefreshResult blocked = ConsentRefreshResult(
      updateOk: true,
      status: ConsentStatus.required,
      canRequestAds: false,
      privacyOptionsRequired: true,
    );

    setUp(() async {
      purchases = FakePurchases();
      store = FakeSettingsStore();
      entitlement = EntitlementProvider(
        purchases: purchases,
        store: store,
        clock: clock,
        banners: BannerProvider(),
      );
      await entitlement.init();
      consent = FakeConsent();
      ads = FakeAds();
      provider = make();
    });

    tearDown(() => provider.dispose());

    test('outside the regions, ads are allowed after the refresh', () async {
      await provider.refresh();
      expect(provider.value.canShowAds, isTrue);
    });

    test('no ad is requested while consent is required', () async {
      consent.next = blocked;
      await provider.refresh();
      await provider.loadBanner(320);
      expect(provider.value.canShowAds, isFalse);
      expect(ads.loads, 0);
      expect(ads.initializes, 0);
    });

    test('a failing refresh leaves ads off and never throws', () async {
      consent.failRefresh = StateError('offline');
      await provider.refresh();
      expect(provider.value.canShowAds, isFalse);
    });

    test('the banner loads once consent allows it', () async {
      consent.next = allowed;
      await provider.refresh();
      await provider.loadBanner(320);
      expect(provider.value.banner, isNotNull);
      expect(ads.initializes, 1);
      expect(provider.privacyOptionsRequired, isTrue);
    });

    test('asking twice loads only once', () async {
      await provider.refresh();
      await Future.wait(<Future<void>>[
        provider.loadBanner(320),
        provider.loadBanner(320),
      ]);
      expect(ads.loads, 1);
    });

    test('buying the upgrade removes the banner at once', () async {
      await provider.refresh();
      await provider.loadBanner(320);
      final FakeBanner banner = ads.made.single;
      purchases.controller.add(const PurchaseCompleted());
      await wait();
      expect(provider.value.canShowAds, isFalse);
      expect(provider.value.banner, isNull);
      expect(banner.disposed, isTrue);
    });

    test('withdrawing consent removes the banner at once', () async {
      consent.next = allowed;
      await provider.refresh();
      await provider.loadBanner(320);
      final FakeBanner banner = ads.made.single;
      consent.afterOptions = const ConsentRefreshResult(
        updateOk: true,
        status: ConsentStatus.obtained,
        canRequestAds: false,
        privacyOptionsRequired: true,
      );
      await provider.showPrivacyOptions();
      expect(provider.value.canShowAds, isFalse);
      expect(banner.disposed, isTrue);
    });

    test('a failed load is retried and then succeeds', () async {
      await provider.refresh();
      ads.script.addAll(<FakeBanner?>[null, null, FakeBanner()]);
      await provider.loadBanner(320);
      expect(provider.value.banner, isNull);
      await wait(120);
      expect(provider.value.banner, isNotNull);
      expect(ads.loads, 3);
    });

    test('after the last retry, it gives up until the next launch', () async {
      provider.dispose();
      provider = make(
        delays: const <Duration>[
          Duration(milliseconds: 5),
          Duration(milliseconds: 5),
        ],
      );
      await provider.refresh();
      ads.script.addAll(<FakeBanner?>[null, null, null, null, null]);
      await provider.loadBanner(320);
      await wait(150);
      expect(ads.loads, 3);
      expect(provider.value.banner, isNull);
    });
  });
}
