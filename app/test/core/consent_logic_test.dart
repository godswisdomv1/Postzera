import 'package:flutter_test/flutter_test.dart';
import 'package:postzera/core/models/consent_state.dart';
import 'package:postzera/core/models/entitlement.dart';
import 'package:postzera/core/ports/consent_port.dart';
import 'package:postzera/core/services/consent_logic.dart';

void main() {
  const ConsentLogic logic = ConsentLogic();
  final DateTime now = DateTime.utc(2026, 10, 18);

  ConsentState resolve({
    required bool updateOk,
    required ConsentStatus status,
    required bool canRequestAds,
    bool privacyOptions = false,
  }) =>
      logic.resolve(
        ConsentRefreshResult(
          updateOk: updateOk,
          status: status,
          canRequestAds: canRequestAds,
          privacyOptionsRequired: privacyOptions,
        ),
        now: now,
      );

  test('outside the regions, a successful refresh allows ads', () {
    final ConsentState s = resolve(
      updateOk: true,
      status: ConsentStatus.notRequired,
      canRequestAds: true,
    );
    expect(s.canRequestAds, isTrue);
    expect(s.status, ConsentStatus.notRequired);
  });

  test('consent required and not yet given blocks ads', () {
    final ConsentState s = resolve(
      updateOk: true,
      status: ConsentStatus.required,
      canRequestAds: false,
      privacyOptions: true,
    );
    expect(s.canRequestAds, isFalse);
    expect(s.privacyOptionsRequired, isTrue);
  });

  test('ads stay blocked while consent is required, whatever else is reported',
      () {
    final ConsentState s = resolve(
      updateOk: true,
      status: ConsentStatus.required,
      canRequestAds: true,
    );
    expect(s.canRequestAds, isFalse);
  });

  test('after the form is answered with yes, ads are allowed', () {
    final ConsentState s = resolve(
      updateOk: true,
      status: ConsentStatus.obtained,
      canRequestAds: true,
      privacyOptions: true,
    );
    expect(s.canRequestAds, isTrue);
  });

  test('a failed refresh keeps an earlier yes', () {
    final ConsentState s = resolve(
      updateOk: false,
      status: ConsentStatus.unknown,
      canRequestAds: true,
    );
    expect(s.canRequestAds, isTrue);
  });

  test('a failed refresh keeps an earlier decline', () {
    final ConsentState s = resolve(
      updateOk: false,
      status: ConsentStatus.obtained,
      canRequestAds: false,
    );
    expect(s.canRequestAds, isFalse);
  });

  test('a failed refresh with no earlier answer blocks ads', () {
    final ConsentState s = resolve(
      updateOk: false,
      status: ConsentStatus.unknown,
      canRequestAds: false,
    );
    expect(s.canRequestAds, isFalse);
  });

  test('withdrawing in privacy choices blocks ads from that moment', () {
    final ConsentState s = resolve(
      updateOk: true,
      status: ConsentStatus.obtained,
      canRequestAds: false,
      privacyOptions: true,
    );
    expect(s.canRequestAds, isFalse);
    expect(s.privacyOptionsRequired, isTrue);
  });

  test('the answer is stamped with the time', () {
    final ConsentState s = resolve(
      updateOk: true,
      status: ConsentStatus.notRequired,
      canRequestAds: true,
    );
    expect(s.updatedAt, now);
  });

  group('canShowAds', () {
    const ConsentState allowed = ConsentState(
      status: ConsentStatus.obtained,
      canRequestAds: true,
      privacyOptionsRequired: false,
    );
    const ConsentState blocked = ConsentState.unknown();
    const Entitlement pro = Entitlement(
      state: EntitlementState.pro,
      source: EntitlementSource.store,
    );
    const Entitlement free = Entitlement(
      state: EntitlementState.free,
      source: EntitlementSource.store,
    );

    test('needs consent and no purchase', () {
      expect(logic.canShowAds(consent: allowed, entitlement: free), isTrue);
      expect(
        logic.canShowAds(
          consent: allowed,
          entitlement: const Entitlement.unknown(),
        ),
        isTrue,
      );
      expect(logic.canShowAds(consent: allowed, entitlement: pro), isFalse);
      expect(logic.canShowAds(consent: blocked, entitlement: free), isFalse);
    });
  });
}
