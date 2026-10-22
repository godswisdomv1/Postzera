import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:postzera/core/ports/ads_port.dart';
import 'package:postzera/platform/ads/ad_config.dart';
import 'package:postzera/utils/log.dart';

/// A loaded banner. The shell draws it with `AdWidget(ad: handle.ad)`.
class BannerAdHandle implements BannerHandle {
  BannerAdHandle(this.ad, this.heightDp);

  final BannerAd ad;

  @override
  final double heightDp;

  @override
  void dispose() => ad.dispose();
}

/// The only place an ad can be requested. The consent provider calls
/// [initialize] and [loadBanner] only after consent allows ads.
class AdsService implements AdsPort {
  AdsService({
    this.config = const AdConfig(),
    this.loadTimeout = const Duration(seconds: 30),
  });

  final AdConfig config;
  final Duration loadTimeout;

  bool _initialized = false;

  @override
  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    try {
      if (config.testDeviceId.isNotEmpty && !config.isProduction) {
        await MobileAds.instance.updateRequestConfiguration(
          RequestConfiguration(testDeviceIds: <String>[config.testDeviceId]),
        );
      }
      await MobileAds.instance.initialize();
      _initialized = true;
    } catch (error) {
      Log.w('ads', 'initialize failed: ${error.runtimeType}');
    }
  }

  @override
  Future<BannerHandle?> loadBanner(int widthDp) async {
    if (!_initialized) {
      return null;
    }
    final String unit = config.bannerUnitId(
      android: defaultTargetPlatform == TargetPlatform.android,
    );
    if (unit.isEmpty) {
      Log.w('ads', 'no banner id for this build');
      return null;
    }
    try {
      final AnchoredAdaptiveBannerAdSize? size =
          await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(widthDp);
      if (size == null) {
        return null;
      }
      final Completer<BannerHandle?> done = Completer<BannerHandle?>();
      final BannerAd banner = BannerAd(
        adUnitId: unit,
        size: size,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (Ad ad) {
            if (!done.isCompleted) {
              done.complete(BannerAdHandle(ad as BannerAd, size.height.toDouble()));
            }
          },
          onAdFailedToLoad: (Ad ad, LoadAdError error) {
            Log.w('ads', 'banner failed: ${error.code}');
            ad.dispose();
            if (!done.isCompleted) {
              done.complete(null);
            }
          },
        ),
      );
      await banner.load();
      return await done.future.timeout(
        loadTimeout,
        onTimeout: () {
          banner.dispose();
          return null;
        },
      );
    } catch (error) {
      Log.w('ads', 'load failed: ${error.runtimeType}');
      return null;
    }
  }
}
