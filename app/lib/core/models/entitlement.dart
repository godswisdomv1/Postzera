import 'package:flutter/foundation.dart';
import 'package:postzera/core/models/json_read.dart';

enum EntitlementState { unknown, free, pro }

/// Where the entitlement answer came from.
enum EntitlementSource { store, cache }

/// Whether the one-time purchase is owned. Only the entitlement reducer
/// creates new values; nothing infers it at the point of use.
@immutable
class Entitlement {
  const Entitlement({
    required this.state,
    required this.source,
    this.updatedAt,
  });

  const Entitlement.unknown()
      : state = EntitlementState.unknown,
        source = EntitlementSource.cache,
        updatedAt = null;

  factory Entitlement.fromJson(Map<String, Object?> json) => Entitlement(
        state: readEnum(
          EntitlementState.values,
          json['state'],
          EntitlementState.unknown,
        ),
        source: readEnum(
          EntitlementSource.values,
          json['source'],
          EntitlementSource.cache,
        ),
        updatedAt: readDateOrNull(json['updatedAt']),
      );

  final EntitlementState state;
  final EntitlementSource source;

  /// UTC.
  final DateTime? updatedAt;

  bool get isPro => state == EntitlementState.pro;

  Entitlement copyWith({
    EntitlementState? state,
    EntitlementSource? source,
    DateTime? updatedAt,
  }) =>
      Entitlement(
        state: state ?? this.state,
        source: source ?? this.source,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'schemaVersion': modelSchemaVersion,
        'state': state.name,
        'source': source.name,
        'updatedAt': updatedAt?.toUtc().millisecondsSinceEpoch,
      };

  @override
  bool operator ==(Object other) =>
      other is Entitlement &&
      other.state == state &&
      other.source == source &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(state, source, updatedAt);
}
