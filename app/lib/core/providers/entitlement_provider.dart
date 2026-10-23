import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:postzera/core/models/app_error.dart';
import 'package:postzera/core/models/entitlement.dart';
import 'package:postzera/core/ports/clock.dart';
import 'package:postzera/core/ports/purchase_port.dart';
import 'package:postzera/core/ports/settings_store.dart';
import 'package:postzera/core/providers/banner_provider.dart';
import 'package:postzera/core/services/entitlement_reducer.dart';
import 'package:postzera/utils/log.dart';

/// What the purchase flow is doing right now.
enum PurchaseStatus { idle, buying, restoring, pending }

@immutable
class EntitlementViewState {
  const EntitlementViewState({
    this.entitlement = const Entitlement.unknown(),
    this.price,
    this.status = PurchaseStatus.idle,
    this.error,
  });

  final Entitlement entitlement;

  /// The store's localized price, once loaded.
  final String? price;
  final PurchaseStatus status;

  /// A retryable problem to show on the paywall.
  final AppError? error;

  EntitlementViewState copyWith({
    Entitlement? entitlement,
    String? price,
    PurchaseStatus? status,
    AppError? error,
    bool clearError = false,
  }) =>
      EntitlementViewState(
        entitlement: entitlement ?? this.entitlement,
        price: price ?? this.price,
        status: status ?? this.status,
        error: clearError ? null : (error ?? this.error),
      );
}

/// Whether the ad-free upgrade is owned. Only [EntitlementReducer] changes the
/// answer, from store events.
class EntitlementProvider extends ValueNotifier<EntitlementViewState> {
  EntitlementProvider({
    required PurchasePort purchases,
    required SettingsStore store,
    required Clock clock,
    required BannerProvider banners,
    EntitlementReducer reducer = const EntitlementReducer(),
  })  : _purchases = purchases,
        _store = store,
        _clock = clock,
        _banners = banners,
        _reducer = reducer,
        super(const EntitlementViewState());

  final PurchasePort _purchases;
  final SettingsStore _store;
  final Clock _clock;
  final BannerProvider _banners;
  final EntitlementReducer _reducer;

  StreamSubscription<PurchaseEvent>? _subscription;

  Entitlement get entitlement => value.entitlement;

  /// Reads the cached answer. Fast, and safe to await at startup.
  Future<void> init() async {
    Entitlement? cached;
    try {
      cached = await _store.loadEntitlementCache();
    } catch (error) {
      Log.w('entitlement', 'cache read failed: ${error.runtimeType}');
    }
    value = value.copyWith(entitlement: _reducer.initial(cached));
    _subscription ??= _purchases.events.listen(_onEvent);
  }

  /// Connects to the store, loads the price and asks what is owned. Call after
  /// the first frame; it never blocks startup.
  Future<void> connect() async {
    await _purchases.connect();
    final String? price = await _purchases.localizedPrice();
    if (price != null) {
      value = value.copyWith(price: price);
    }
    final bool? owned = await _purchases.ownsPro();
    if (owned != null) {
      _apply(PurchaseOwnershipReported(owned: owned));
    }
  }

  Future<void> buy() async {
    value = value.copyWith(status: PurchaseStatus.buying, clearError: true);
    await _purchases.buyPro();
  }

  Future<void> restore() async {
    value = value.copyWith(status: PurchaseStatus.restoring, clearError: true);
    await _purchases.restore();
  }

  void clearError() => value = value.copyWith(clearError: true);

  void _onEvent(PurchaseEvent event) {
    final PurchaseStatus before = value.status;
    _apply(event);
    switch (event) {
      case PurchaseCompleted():
        _banners.success(BannerMessage.adsRemoved);
        value = value.copyWith(status: PurchaseStatus.idle);
      case PurchaseOwnershipReported(:final bool owned):
        if (before == PurchaseStatus.restoring) {
          _banners.success(
            owned ? BannerMessage.purchaseRestored : BannerMessage.nothingToRestore,
          );
        }
        value = value.copyWith(status: PurchaseStatus.idle);
      case PurchasePending():
        value = value.copyWith(status: PurchaseStatus.pending);
      case PurchaseCancelled():
        value = value.copyWith(status: PurchaseStatus.idle);
      case PurchaseFailed(:final AppError error):
        value = value.copyWith(status: PurchaseStatus.idle, error: error);
    }
  }

  void _apply(PurchaseEvent event) {
    final Entitlement next =
        _reducer.reduce(value.entitlement, event, now: _clock.now());
    if (next != value.entitlement) {
      value = value.copyWith(entitlement: next);
      unawaited(_save(next));
    }
  }

  Future<void> _save(Entitlement entitlement) async {
    try {
      await _store.saveEntitlementCache(entitlement);
    } catch (error) {
      Log.w('entitlement', 'cache write failed: ${error.runtimeType}');
    }
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
