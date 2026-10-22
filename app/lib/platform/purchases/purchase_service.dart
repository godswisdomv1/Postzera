import 'dart:async';

import 'package:flutter_inapp_purchase/flutter_inapp_purchase.dart';
import 'package:postzera/core/models/app_error.dart';
import 'package:postzera/core/ports/purchase_port.dart' as port;
import 'package:postzera/platform/purchases/purchase_config.dart';
import 'package:postzera/utils/log.dart';

/// The one-time ad-removal purchase, through the stores' own billing
/// (Google Play Billing and StoreKit 2).
class PurchaseService implements port.PurchasePort {
  PurchaseService({FlutterInappPurchase? plugin})
      : _iap = plugin ?? FlutterInappPurchase.instance;

  final FlutterInappPurchase _iap;
  final StreamController<port.PurchaseEvent> _events =
      StreamController<port.PurchaseEvent>.broadcast();

  StreamSubscription<Purchase>? _updates;
  StreamSubscription<PurchaseError>? _errors;
  bool _connected = false;

  static const String _productId = PurchaseConfig.proProductId;

  @override
  Stream<port.PurchaseEvent> get events => _events.stream;

  @override
  Future<void> connect() async {
    if (_connected) {
      return;
    }
    try {
      _connected = await _iap.initConnection();
      _updates ??= _iap.purchaseUpdatedListener.listen(_onPurchase);
      _errors ??= _iap.purchaseErrorListener.listen(
        (PurchaseError e) => _events.add(eventForError(e)),
      );
    } catch (error) {
      _connected = false;
      Log.w('store', 'connect failed: ${error.runtimeType}');
    }
  }

  @override
  Future<String?> localizedPrice() async {
    if (!await _ensureConnected()) {
      return null;
    }
    try {
      final FetchProductsResult result = await _iap.fetchProducts(
        skus: <String>[_productId],
        type: ProductQueryType.InApp,
      );
      if (result is FetchProductsResultProducts) {
        for (final Product product in result.value ?? const <Product>[]) {
          if (product.id == _productId) {
            return product.displayPrice;
          }
        }
      }
      return null;
    } catch (error) {
      Log.w('store', 'price failed: ${error.runtimeType}');
      return null;
    }
  }

  @override
  Future<bool?> ownsPro() async {
    if (!await _ensureConnected()) {
      return null;
    }
    try {
      final List<Purchase> owned = await _iap.getAvailablePurchases();
      return owned.any(_isPro);
    } catch (error) {
      Log.w('store', 'ownership failed: ${error.runtimeType}');
      return null;
    }
  }

  @override
  Future<void> buyPro() async {
    if (!await _ensureConnected()) {
      _events.add(
        port.PurchaseFailed(AppError.of(AppErrorKind.storeUnavailable)),
      );
      return;
    }
    try {
      await _iap.requestPurchase(
        const RequestPurchaseProps.inApp((
          apple: RequestPurchaseIosProps(sku: _productId),
          google: RequestPurchaseAndroidProps(skus: <String>[_productId]),
        )),
      );
    } catch (error) {
      _events.add(
        error is PurchaseError
            ? eventForError(error)
            : port.PurchaseFailed(AppError.of(AppErrorKind.purchaseFailed)),
      );
    }
  }

  @override
  Future<void> restore() async {
    if (!await _ensureConnected()) {
      _events.add(
        port.PurchaseFailed(AppError.of(AppErrorKind.storeUnavailable)),
      );
      return;
    }
    try {
      await _iap.restorePurchases();
    } catch (error) {
      Log.w('store', 'restore failed: ${error.runtimeType}');
    }
    final bool? owned = await ownsPro();
    _events.add(
      owned == null
          ? port.PurchaseFailed(AppError.of(AppErrorKind.storeUnavailable))
          : port.PurchaseOwnershipReported(owned: owned),
    );
  }

  Future<void> dispose() async {
    await _updates?.cancel();
    await _errors?.cancel();
    await _events.close();
  }

  Future<bool> _ensureConnected() async {
    if (!_connected) {
      await connect();
    }
    return _connected;
  }

  bool _isPro(Purchase p) =>
      p.productId == _productId && p.purchaseState == PurchaseState.Purchased;

  Future<void> _onPurchase(Purchase purchase) async {
    if (purchase.productId != _productId) {
      return;
    }
    switch (purchase.purchaseState) {
      case PurchaseState.Purchased:
        // Always finish the transaction. On Android this acknowledges it, and
        // an unacknowledged purchase is refunded after three days.
        try {
          await _iap.finishTransaction(purchase: purchase, isConsumable: false);
        } catch (error) {
          Log.w('store', 'finish failed: ${error.runtimeType}');
        }
        _events.add(const port.PurchaseCompleted());
      case PurchaseState.Pending:
        _events.add(const port.PurchasePending());
      case PurchaseState.Unknown:
        break;
    }
  }

  /// How a store error is shown: a cancel is silent, an existing purchase is
  /// treated as owned, a network problem is a store problem, the rest is a
  /// failed purchase.
  static port.PurchaseEvent eventForError(PurchaseError error) {
    switch (error.code) {
      case ErrorCode.UserCancelled:
        return const port.PurchaseCancelled();
      case ErrorCode.AlreadyOwned:
        return const port.PurchaseOwnershipReported(owned: true);
      case ErrorCode.NetworkError:
      case ErrorCode.ServiceError:
      case ErrorCode.RemoteError:
        return port.PurchaseFailed(AppError.of(AppErrorKind.storeUnavailable));
      default:
        return port.PurchaseFailed(AppError.of(AppErrorKind.purchaseFailed));
    }
  }
}
