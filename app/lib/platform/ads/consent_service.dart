import 'dart:async';

import 'package:google_mobile_ads/google_mobile_ads.dart' as ads;
import 'package:postzera/core/models/consent_state.dart';
import 'package:postzera/core/ports/consent_port.dart';
import 'package:postzera/platform/ads/ad_config.dart';
import 'package:postzera/utils/log.dart';

/// Google's user-messaging platform (UMP). Required for ads in the EEA, the UK
/// and Switzerland.
class ConsentService implements ConsentPort {
  ConsentService({
    this.config = const AdConfig(),
    this.timeout = const Duration(seconds: 15),
  });

  final AdConfig config;

  /// The longest a refresh may take, so startup can never hang on it.
  final Duration timeout;

  ads.ConsentInformation get _info => ads.ConsentInformation.instance;

  @override
  Future<ConsentRefreshResult> refresh() async {
    final bool updated = await _requestUpdate();
    if (updated) {
      await _showFormIfRequired();
    }
    return _read(updateOk: updated);
  }

  @override
  Future<ConsentRefreshResult> showPrivacyOptions() async {
    final Completer<void> done = Completer<void>();
    unawaited(
      ads.ConsentForm.showPrivacyOptionsForm((ads.FormError? error) {
        if (error != null) {
          Log.w('consent', 'privacy options: ${error.errorCode}');
        }
        done.complete();
      }),
    );
    await done.future.timeout(const Duration(minutes: 10), onTimeout: () {});
    return _read(updateOk: true);
  }

  Future<bool> _requestUpdate() {
    final Completer<bool> done = Completer<bool>();
    _info.requestConsentInfoUpdate(
      _parameters(),
      () => done.complete(true),
      (ads.FormError error) {
        Log.w('consent', 'update failed: ${error.errorCode}');
        done.complete(false);
      },
    );
    return done.future.timeout(timeout, onTimeout: () => false);
  }

  Future<void> _showFormIfRequired() {
    final Completer<void> done = Completer<void>();
    ads.ConsentForm.loadAndShowConsentFormIfRequired((ads.FormError? error) {
      if (error != null) {
        Log.w('consent', 'form: ${error.errorCode}');
      }
      done.complete();
    });
    return done.future.timeout(const Duration(minutes: 10), onTimeout: () {});
  }

  Future<ConsentRefreshResult> _read({required bool updateOk}) async {
    final bool canRequest = await _info.canRequestAds();
    final ads.ConsentStatus status = await _info.getConsentStatus();
    final ads.PrivacyOptionsRequirementStatus privacy =
        await _info.getPrivacyOptionsRequirementStatus();
    return ConsentRefreshResult(
      updateOk: updateOk,
      status: mapStatus(status),
      canRequestAds: canRequest,
      privacyOptionsRequired:
          privacy == ads.PrivacyOptionsRequirementStatus.required,
    );
  }

  /// Debug geography and test devices are set only when the build asks for
  /// them, and never in production.
  ads.ConsentRequestParameters _parameters() {
    if (!config.forcesConsentGeo) {
      return ads.ConsentRequestParameters();
    }
    return ads.ConsentRequestParameters(
      consentDebugSettings: ads.ConsentDebugSettings(
        debugGeography: config.consentGeo == 'eea'
            ? ads.DebugGeography.debugGeographyEea
            : ads.DebugGeography.debugGeographyOther,
        testIdentifiers:
            config.testDeviceId.isEmpty ? null : <String>[config.testDeviceId],
      ),
    );
  }

  static ConsentStatus mapStatus(ads.ConsentStatus status) => switch (status) {
        ads.ConsentStatus.notRequired => ConsentStatus.notRequired,
        ads.ConsentStatus.required => ConsentStatus.required,
        ads.ConsentStatus.obtained => ConsentStatus.obtained,
        ads.ConsentStatus.unknown => ConsentStatus.unknown,
      };
}
