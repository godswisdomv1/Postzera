import 'package:postzera/core/models/consent_state.dart';
import 'package:postzera/core/models/entitlement.dart';
import 'package:postzera/core/ports/consent_port.dart';

/// The rules of blueprint section 11 for deciding whether ads may be
/// requested.
class ConsentLogic {
  const ConsentLogic();

  /// Turns what the consent platform reported into the app's state.
  ///
  /// The platform answers `canRequestAds` from the previous session's saved
  /// choice when a refresh fails, so an offline launch can never override a
  /// saved "yes", and a decline, a withdrawal or no earlier answer blocks ads.
  /// While consent is still required (the form has not been answered), ads
  /// stay blocked whatever else the platform says.
  ConsentState resolve(ConsentRefreshResult result, {required DateTime now}) {
    final bool stillRequired = result.status == ConsentStatus.required;
    return ConsentState(
      status: result.status,
      canRequestAds: result.canRequestAds && !stillRequired,
      privacyOptionsRequired: result.privacyOptionsRequired,
      updatedAt: now.toUtc(),
    );
  }

  /// A banner may be requested when consent allows it and the user has not
  /// bought the ad-free upgrade.
  bool canShowAds({
    required ConsentState consent,
    required Entitlement entitlement,
  }) => consent.canRequestAds && !entitlement.isPro;
}
