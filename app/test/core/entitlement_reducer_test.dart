import 'package:flutter_test/flutter_test.dart';
import 'package:postzera/core/models/app_error.dart';
import 'package:postzera/core/models/entitlement.dart';
import 'package:postzera/core/ports/purchase_port.dart';
import 'package:postzera/core/services/entitlement_reducer.dart';

void main() {
  const EntitlementReducer reducer = EntitlementReducer();
  final DateTime now = DateTime.utc(2026, 10, 18);

  Entitlement apply(Entitlement s, PurchaseEvent e) =>
      reducer.reduce(s, e, now: now);

  const Entitlement free = Entitlement(
    state: EntitlementState.free,
    source: EntitlementSource.store,
  );
  const Entitlement pro = Entitlement(
    state: EntitlementState.pro,
    source: EntitlementSource.store,
  );

  group('launch', () {
    test('with nothing cached, the state is unknown', () {
      expect(reducer.initial(null).state, EntitlementState.unknown);
    });

    test('a cached Pro keeps ads off while offline', () {
      final Entitlement s = reducer.initial(pro);
      expect(s.state, EntitlementState.pro);
      expect(s.source, EntitlementSource.cache);
    });

    test('a cached free state is kept', () {
      expect(reducer.initial(free).state, EntitlementState.free);
    });
  });

  group('purchase', () {
    test('a completed purchase gives Pro', () {
      final Entitlement s = apply(free, const PurchaseCompleted());
      expect(s.state, EntitlementState.pro);
      expect(s.source, EntitlementSource.store);
      expect(s.updatedAt, now);
    });

    test('a pending purchase gives nothing yet', () {
      expect(apply(free, const PurchasePending()), free);
    });

    test('a cancelled purchase changes nothing', () {
      expect(apply(free, const PurchaseCancelled()), free);
      expect(apply(pro, const PurchaseCancelled()), pro);
    });

    test('a failed purchase changes nothing', () {
      final PurchaseFailed failure =
          PurchaseFailed(AppError.of(AppErrorKind.purchaseFailed));
      expect(apply(free, failure), free);
      expect(apply(pro, failure), pro);
    });
  });

  group('restore and refund', () {
    test('restore that finds the product gives Pro', () {
      final Entitlement s = apply(
        const Entitlement.unknown(),
        const PurchaseOwnershipReported(owned: true),
      );
      expect(s.state, EntitlementState.pro);
    });

    test('a connected store saying not owned clears a cached Pro', () {
      final Entitlement cached = reducer.initial(pro);
      final Entitlement s = apply(
        cached,
        const PurchaseOwnershipReported(owned: false),
      );
      expect(s.state, EntitlementState.free);
      expect(s.source, EntitlementSource.store);
    });

    test('without a store report, nothing clears Pro', () {
      final Entitlement cached = reducer.initial(pro);
      expect(apply(cached, const PurchasePending()).state, EntitlementState.pro);
      expect(apply(cached, const PurchaseCancelled()).state, EntitlementState.pro);
    });
  });
}
