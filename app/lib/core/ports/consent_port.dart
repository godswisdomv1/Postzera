import 'package:flutter/foundation.dart';
import 'package:postzera/core/models/consent_state.dart';

/// What the consent platform reported after a refresh.
@immutable
class ConsentRefreshResult {
  const ConsentRefreshResult({
    required this.updateOk,
    required this.status,
    required this.canRequestAds,
    required this.privacyOptionsRequired,
  });

  /// False when the refresh failed (for example, offline). The other fields
  /// then come from the consent saved by an earlier session.
  final bool updateOk;
  final ConsentStatus status;
  final bool canRequestAds;
  final bool privacyOptionsRequired;
}

/// The user-messaging platform for EEA, UK and Switzerland consent.
abstract class ConsentPort {
  /// Refreshes consent and shows the form only when one is required.
  /// Runs on every launch.
  Future<ConsentRefreshResult> refresh();

  /// Opens the privacy-options form, then reports the new answer.
  Future<ConsentRefreshResult> showPrivacyOptions();
}
