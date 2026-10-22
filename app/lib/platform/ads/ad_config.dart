/// Which ad ids and consent settings this build uses, from `--dart-define`.
///
/// `AD_MODE=test` (the default) uses Google's sample ids, so a checkpoint
/// build can never produce a real ad impression. `AD_MODE=prod` needs the real
/// banner ids, passed as `ADMOB_ANDROID_BANNER` and `ADMOB_IOS_BANNER`. If
/// they are missing, no ad is requested.
class AdConfig {
  const AdConfig({
    this.mode = _mode,
    this.consentGeo = _consentGeo,
    this.testDeviceId = _testDeviceId,
    this.productionAndroidBanner = _androidBanner,
    this.productionIosBanner = _iosBanner,
  });

  static const String _mode = String.fromEnvironment('AD_MODE', defaultValue: 'test');
  static const String _consentGeo =
      String.fromEnvironment('CONSENT_DEBUG_GEO', defaultValue: 'none');
  static const String _testDeviceId = String.fromEnvironment('AD_TEST_DEVICE_ID');
  static const String _androidBanner = String.fromEnvironment('ADMOB_ANDROID_BANNER');
  static const String _iosBanner = String.fromEnvironment('ADMOB_IOS_BANNER');

  /// Google's sample adaptive-banner ids.
  static const String sampleAndroidBanner =
      'ca-app-pub-3940256099942544/9214589741';
  static const String sampleIosBanner = 'ca-app-pub-3940256099942544/2435281174';

  final String mode;

  /// `none`, `eea` or `not_eea`. Ignored in production builds.
  final String consentGeo;
  final String testDeviceId;
  final String productionAndroidBanner;
  final String productionIosBanner;

  bool get isProduction => mode == 'prod';

  /// Whether to force a consent geography. Never true in production.
  bool get forcesConsentGeo =>
      !isProduction && (consentGeo == 'eea' || consentGeo == 'not_eea');

  /// The banner unit id, or an empty string when none may be used.
  String bannerUnitId({required bool android}) {
    if (!isProduction) {
      return android ? sampleAndroidBanner : sampleIosBanner;
    }
    return android ? productionAndroidBanner : productionIosBanner;
  }
}
