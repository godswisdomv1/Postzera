import 'package:flutter_test/flutter_test.dart';
import 'package:postzera/app_services.dart';
import 'package:postzera/bootstrap.dart';
import 'package:postzera/core/models/app_error.dart';

import 'app_services_test.dart' show Harness;

void main() {
  test('runs consent, the store, reminders and the file sweep', () async {
    final Harness h = Harness();
    addTearDown(h.services.dispose);
    await h.services.loadInitial();
    await startDeferred(h.services);
    expect(h.consent.refreshes, 1);
    expect(h.purchases.connects, 1);
    expect(h.notifications.inits, 1);
    expect(h.notifications.replaced, isNotEmpty);
    expect(h.files.sweeps, <Duration>[outputMaxAge]);
    expect(outputMaxAge, const Duration(days: 14));
  });

  test('a step that fails does not stop the others', () async {
    final Harness h = Harness();
    addTearDown(h.services.dispose);
    await h.services.loadInitial();
    h.purchases.failConnect = StateError('store down');
    h.consent.failRefresh = StateError('consent down');
    await startDeferred(h.services);
    expect(h.notifications.inits, 1);
    expect(h.notifications.replaced, isNotEmpty);
    expect(h.files.sweeps, hasLength(1));
  });

  test('a recovered database shows a one-time banner', () async {
    final Harness h = Harness(
      notices: const StartupNotices(databaseRecovered: true),
    );
    addTearDown(h.services.dispose);
    await h.services.loadInitial();
    await startDeferred(h.services);
    expect(h.services.banners.value.transient?.error?.kind, AppErrorKind.dbCorrupt);
    expect(h.services.banners.value.sticky, isEmpty);
  });

  test('a healthy start shows no banner', () async {
    final Harness h = Harness();
    addTearDown(h.services.dispose);
    await h.services.loadInitial();
    await startDeferred(h.services);
    expect(h.services.banners.value.transient, isNull);
  });
}
