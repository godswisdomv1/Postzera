import 'package:postzera/core/models/entitlement.dart';
import 'package:postzera/core/ports/purchase_port.dart';

/// Turns store events into the entitlement. Nothing else decides it.
class EntitlementReducer {
  const EntitlementReducer();

  /// The state at launch, before the store has answered: the cached answer, or
  /// unknown. A cached Pro keeps ads off while offline.
  Entitlement initial(Entitlement? cached) {
    if (cached == null) {
      return const Entitlement.unknown();
    }
    return cached.copyWith(source: EntitlementSource.cache);
  }

  /// Applies one store event.
  ///
  /// Only a connected store report of "not owned" clears Pro (for example
  /// after a refund). A pending purchase, a cancellation and a failure change
  /// nothing.
  Entitlement reduce(
    Entitlement state,
    PurchaseEvent event, {
    required DateTime now,
  }) {
    switch (event) {
      case PurchaseOwnershipReported(:final bool owned):
        return Entitlement(
          state: owned ? EntitlementState.pro : EntitlementState.free,
          source: EntitlementSource.store,
          updatedAt: now.toUtc(),
        );
      case PurchaseCompleted():
        return Entitlement(
          state: EntitlementState.pro,
          source: EntitlementSource.store,
          updatedAt: now.toUtc(),
        );
      case PurchasePending():
      case PurchaseCancelled():
      case PurchaseFailed():
        return state;
    }
  }
}
