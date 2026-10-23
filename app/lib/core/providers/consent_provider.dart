import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:postzera/core/models/consent_state.dart';
import 'package:postzera/core/ports/ads_port.dart';
import 'package:postzera/core/ports/clock.dart';
import 'package:postzera/core/ports/consent_port.dart';
import 'package:postzera/core/providers/entitlement_provider.dart';
import 'package:postzera/core/services/consent_logic.dart';
import 'package:postzera/utils/log.dart';

@immutable
class AdsViewState {
  const AdsViewState({
    this.consent = const ConsentState.unknown(),
    this.canShowAds = false,
    this.banner,
  });

  final ConsentState consent;

  /// Consent allows ads and the upgrade is not owned.
  final bool canShowAds;

  /// The loaded banner, or null. The ad slot is empty (zero height) without it.
  final BannerHandle? banner;
}

/// Consent, then ads. No ad is requested until consent allows it, and the
/// banner is dropped the moment consent is withdrawn or the upgrade is bought.
class ConsentProvider extends ValueNotifier<AdsViewState> {
  ConsentProvider({
    required ConsentPort consent,
    required AdsPort ads,
    required EntitlementProvider entitlement,
    required Clock clock,
    ConsentLogic logic = const ConsentLogic(),
    this.retryDelays = const <Duration>[
      Duration(seconds: 30),
      Duration(seconds: 60),
      Duration(seconds: 120),
    ],
  })  : _consent = consent,
        _ads = ads,
        _entitlement = entitlement,
        _clock = clock,
        _logic = logic,
        super(const AdsViewState()) {
    _entitlement.addListener(_recompute);
  }

  final ConsentPort _consent;
  final AdsPort _ads;
  final EntitlementProvider _entitlement;
  final Clock _clock;
  final ConsentLogic _logic;

  /// Waits between failed banner loads. After the last one, no more tries
  /// until the next launch.
  final List<Duration> retryDelays;

  bool _loading = false;
  int _attempt = 0;
  Timer? _retry;

  bool get privacyOptionsRequired => value.consent.privacyOptionsRequired;

  /// Runs the consent refresh. Call once per launch, after the first frame.
  Future<void> refresh() async {
    try {
      _apply(await _consent.refresh());
    } catch (error) {
      Log.w('consent', 'refresh failed: ${error.runtimeType}');
      _recompute();
    }
  }

  /// Opens the privacy-options form. Ads stop at once if the answer changed
  /// to "no".
  Future<void> showPrivacyOptions() async {
    try {
      _apply(await _consent.showPrivacyOptions());
    } catch (error) {
      Log.w('consent', 'privacy options failed: ${error.runtimeType}');
    }
  }

  /// Loads the banner for a slot [widthDp] wide. Does nothing unless ads are
  /// allowed, and never while one is loaded or loading.
  Future<void> loadBanner(int widthDp) async {
    if (!value.canShowAds || value.banner != null || _loading) {
      return;
    }
    _loading = true;
    BannerHandle? handle;
    try {
      await _ads.initialize();
      handle = await _ads.loadBanner(widthDp);
    } catch (error) {
      Log.w('ads', 'banner failed: ${error.runtimeType}');
    }
    _loading = false;
    if (!value.canShowAds) {
      handle?.dispose();
      return;
    }
    if (handle != null) {
      _attempt = 0;
      value = AdsViewState(
        consent: value.consent,
        canShowAds: true,
        banner: handle,
      );
    } else if (_attempt < retryDelays.length) {
      final Duration wait = retryDelays[_attempt++];
      _retry?.cancel();
      _retry = Timer(wait, () => unawaited(loadBanner(widthDp)));
    }
  }

  void _apply(ConsentRefreshResult result) {
    value = AdsViewState(
      consent: _logic.resolve(result, now: _clock.now()),
      canShowAds: value.canShowAds,
      banner: value.banner,
    );
    _recompute();
  }

  void _recompute() {
    final bool can = _logic.canShowAds(
      consent: value.consent,
      entitlement: _entitlement.entitlement,
    );
    if (!can) {
      _retry?.cancel();
      value.banner?.dispose();
      value = AdsViewState(consent: value.consent);
      return;
    }
    value = AdsViewState(
      consent: value.consent,
      canShowAds: true,
      banner: value.banner,
    );
  }

  @override
  void dispose() {
    _entitlement.removeListener(_recompute);
    _retry?.cancel();
    value.banner?.dispose();
    super.dispose();
  }
}
