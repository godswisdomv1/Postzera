import 'package:flutter/foundation.dart';

enum ConsentStatus { unknown, required, notRequired, obtained }

/// The app's in-memory mirror of the consent platform's answer. The consent
/// platform keeps its own copy; this is never persisted by the app.
@immutable
class ConsentState {
  const ConsentState({
    required this.status,
    required this.canRequestAds,
    required this.privacyOptionsRequired,
    this.updatedAt,
  });

  const ConsentState.unknown()
      : status = ConsentStatus.unknown,
        canRequestAds = false,
        privacyOptionsRequired = false,
        updatedAt = null;

  final ConsentStatus status;

  /// True only when the consent platform allows ad requests.
  final bool canRequestAds;

  /// True when Settings must show the **Privacy choices** row.
  final bool privacyOptionsRequired;
  final DateTime? updatedAt;

  ConsentState copyWith({
    ConsentStatus? status,
    bool? canRequestAds,
    bool? privacyOptionsRequired,
    DateTime? updatedAt,
  }) =>
      ConsentState(
        status: status ?? this.status,
        canRequestAds: canRequestAds ?? this.canRequestAds,
        privacyOptionsRequired:
            privacyOptionsRequired ?? this.privacyOptionsRequired,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  @override
  bool operator ==(Object other) =>
      other is ConsentState &&
      other.status == status &&
      other.canRequestAds == canRequestAds &&
      other.privacyOptionsRequired == privacyOptionsRequired &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode =>
      Object.hash(status, canRequestAds, privacyOptionsRequired, updatedAt);
}
