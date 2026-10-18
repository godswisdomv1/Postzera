import 'package:flutter/foundation.dart';
import 'package:postzera/core/models/app_error.dart';

/// Something the store reported about the one-time purchase.
@immutable
sealed class PurchaseEvent {
  const PurchaseEvent();
}

/// A connected store said whether the product is owned. Only this event can
/// clear a cached Pro flag.
final class PurchaseOwnershipReported extends PurchaseEvent {
  const PurchaseOwnershipReported({required this.owned});

  final bool owned;
}

/// The purchase just completed.
final class PurchaseCompleted extends PurchaseEvent {
  const PurchaseCompleted();
}

/// Waiting for approval (Android pending purchases). No entitlement yet.
final class PurchasePending extends PurchaseEvent {
  const PurchasePending();
}

final class PurchaseCancelled extends PurchaseEvent {
  const PurchaseCancelled();
}

final class PurchaseFailed extends PurchaseEvent {
  const PurchaseFailed(this.error);

  final AppError error;
}

/// The store side of the one-time ad-removal purchase.
abstract class PurchasePort {
  /// Connects to the store without blocking startup.
  Future<void> connect();

  /// The store's localized price, or null when it could not be loaded.
  Future<String?> localizedPrice();

  /// Whether the product is owned. Null when the store could not be reached.
  Future<bool?> ownsPro();

  Future<void> buyPro();

  Future<void> restore();

  /// Results of buying and restoring.
  Stream<PurchaseEvent> get events;
}
