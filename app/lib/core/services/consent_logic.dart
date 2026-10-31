import 'package:postzera/core/models/consent_state.dart';
import 'package:postzera/core/models/entitlement.dart';
import 'package:postzera/core/ports/consent_port.dart';

/// The rules of blueprint section 11 for deciding whether ads may be
/// requested.
class ConsentLogic {
  const ConsentLogic();

  /// Turns what the consent platform reported into the app's state.
  ///
  /// Google's rule is that `canRequestAds` is the only thing an app may
  /// consult: it already answers from the previous session when a refresh
  /// fails, and it stays false until a required form has been answered. The
  /// app never second-guesses it. A user who declines is not an ad-free user
  /// by default: when the platform still allows requests, Google chooses the
  /// serving mode (personalized, non-personalized or limited ads), and the
  /// app simply asks.
  ConsentState resolve(ConsentRefreshResult result, {required DateTime now}) {
    return ConsentState(
      status: result.status,
      canRequestAds: result.canRequestAds,
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
