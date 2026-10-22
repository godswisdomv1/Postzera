import 'package:flutter_inapp_purchase/flutter_inapp_purchase.dart' as iap;
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart' as ads;
import 'package:postzera/core/models/app_error.dart';
import 'package:postzera/core/models/consent_state.dart';
import 'package:postzera/core/ports/purchase_port.dart';
import 'package:postzera/platform/ads/ad_config.dart';
import 'package:postzera/platform/ads/consent_service.dart';
import 'package:postzera/platform/import/file_import_service.dart';
import 'package:postzera/platform/notifications/timezone_service.dart';
import 'package:postzera/platform/purchases/purchase_config.dart';
import 'package:postzera/platform/purchases/purchase_service.dart';
import 'package:postzera/platform/share/link_launcher.dart';
import 'package:postzera/platform/share/share_service.dart';
import 'package:timezone/timezone.dart' as tz;

void main() {
  group('ShareService.mimeTypeOf', () {
    test('knows the files Postzera shares', () {
      expect(ShareService.mimeTypeOf('/a/b.PNG'), 'image/png');
      expect(ShareService.mimeTypeOf('/a/b.jpg'), 'image/jpeg');
      expect(ShareService.mimeTypeOf('/a/b.jpeg'), 'image/jpeg');
      expect(ShareService.mimeTypeOf('/a/b.mp4'), 'video/mp4');
      expect(ShareService.mimeTypeOf('/a/b.csv'), 'text/csv');
      expect(ShareService.mimeTypeOf('/a/b.bin'), isNull);
    });
  });

  group('LinkLauncher.mailtoUri', () {
    test('encodes spaces as %20, not +', () {
      final Uri uri = LinkLauncher.mailtoUri(
        to: 'help@example.com',
        subject: 'Postzera feedback',
        body: 'Hello there & thanks',
      );
      expect(uri.scheme, 'mailto');
      expect(uri.path, 'help@example.com');
      expect(uri.toString(), contains('subject=Postzera%20feedback'));
      expect(uri.toString(), contains('body=Hello%20there%20%26%20thanks'));
      expect(uri.toString(), isNot(contains('+')));
    });

    test('with no subject or body there is no query', () {
      final Uri uri = LinkLauncher.mailtoUri(to: 'a@b.co');
      expect(uri.toString(), 'mailto:a@b.co');
    });
  });

  group('TimezoneService', () {
    test('converts an instant to the device zone, with daylight saving', () async {
      final TimezoneService berlin =
          TimezoneService(zoneNameReader: () async => 'Europe/Berlin');
      expect(await berlin.init(), 'Europe/Berlin');
      final tz.TZDateTime summer = berlin.toLocal(DateTime.utc(2026, 7, 1, 12));
      final tz.TZDateTime winter = berlin.toLocal(DateTime.utc(2026, 1, 1, 12));
      expect(summer.hour, 14);
      expect(winter.hour, 13);
      expect(summer.isAtSameMomentAs(DateTime.utc(2026, 7, 1, 12)), isTrue);
    });

    test('an unknown zone falls back to UTC', () async {
      final TimezoneService service =
          TimezoneService(zoneNameReader: () async => 'Mars/Olympus');
      expect(await service.init(), 'UTC');
      expect(service.toLocal(DateTime.utc(2026, 1, 1, 9)).hour, 9);
    });

    test('a failing read falls back to UTC', () async {
      final TimezoneService service = TimezoneService(
        zoneNameReader: () async => throw StateError('no channel'),
      );
      expect(await service.init(), 'UTC');
    });

    test('refresh follows a changed zone', () async {
      String name = 'America/New_York';
      final TimezoneService service =
          TimezoneService(zoneNameReader: () async => name);
      await service.init();
      expect(service.zoneName, 'America/New_York');
      name = 'Asia/Tokyo';
      await service.refresh();
      expect(service.zoneName, 'Asia/Tokyo');
      expect(service.toLocal(DateTime.utc(2026, 1, 1, 0)).hour, 9);
    });
  });

  group('AdConfig', () {
    test('test mode uses Google sample ids', () {
      const AdConfig c = AdConfig(mode: 'test');
      expect(c.bannerUnitId(android: true), AdConfig.sampleAndroidBanner);
      expect(c.bannerUnitId(android: false), AdConfig.sampleIosBanner);
      expect(c.isProduction, isFalse);
    });

    test('production without ids requests no ad', () {
      const AdConfig c = AdConfig(mode: 'prod');
      expect(c.bannerUnitId(android: true), '');
      expect(c.bannerUnitId(android: false), '');
    });

    test('production uses its own ids', () {
      const AdConfig c = AdConfig(
        mode: 'prod',
        productionAndroidBanner: 'ca-app-pub-1/2',
        productionIosBanner: 'ca-app-pub-3/4',
      );
      expect(c.bannerUnitId(android: true), 'ca-app-pub-1/2');
      expect(c.bannerUnitId(android: false), 'ca-app-pub-3/4');
    });

    test('a consent geography can be forced in test builds only', () {
      expect(const AdConfig(consentGeo: 'eea').forcesConsentGeo, isTrue);
      expect(const AdConfig(consentGeo: 'not_eea').forcesConsentGeo, isTrue);
      expect(const AdConfig(consentGeo: 'none').forcesConsentGeo, isFalse);
      expect(
        const AdConfig(mode: 'prod', consentGeo: 'eea').forcesConsentGeo,
        isFalse,
      );
    });
  });

  test('ConsentService maps every platform status', () {
    expect(
      ConsentService.mapStatus(ads.ConsentStatus.notRequired),
      ConsentStatus.notRequired,
    );
    expect(
      ConsentService.mapStatus(ads.ConsentStatus.required),
      ConsentStatus.required,
    );
    expect(
      ConsentService.mapStatus(ads.ConsentStatus.obtained),
      ConsentStatus.obtained,
    );
    expect(
      ConsentService.mapStatus(ads.ConsentStatus.unknown),
      ConsentStatus.unknown,
    );
  });

  group('purchases', () {
    test('the product id matches the stores', () {
      expect(PurchaseConfig.proProductId, 'com.zdmgold.postzera.pro');
    });

    iap.PurchaseError error(iap.ErrorCode code) =>
        iap.PurchaseError(code: code, message: 'x');

    test('a cancel is silent', () {
      expect(
        PurchaseService.eventForError(error(iap.ErrorCode.UserCancelled)),
        isA<PurchaseCancelled>(),
      );
    });

    test('an already-owned error means the user owns it', () {
      final PurchaseEvent e =
          PurchaseService.eventForError(error(iap.ErrorCode.AlreadyOwned));
      expect(e, isA<PurchaseOwnershipReported>());
      expect((e as PurchaseOwnershipReported).owned, isTrue);
    });

    test('network and service errors are store problems', () {
      for (final iap.ErrorCode code in <iap.ErrorCode>[
        iap.ErrorCode.NetworkError,
        iap.ErrorCode.ServiceError,
        iap.ErrorCode.RemoteError,
      ]) {
        final PurchaseEvent e = PurchaseService.eventForError(error(code));
        expect((e as PurchaseFailed).error.kind, AppErrorKind.storeUnavailable);
      }
    });

    test('any other error is a failed purchase', () {
      final PurchaseEvent e =
          PurchaseService.eventForError(error(iap.ErrorCode.Unknown));
      expect((e as PurchaseFailed).error.kind, AppErrorKind.purchaseFailed);
    });
  });

  group('FileImportService.decodeCsvBytes', () {
    test('decodes UTF-8 and removes a byte-order mark', () {
      expect(FileImportService.decodeCsvBytes(<int>[0xEF, 0xBB, 0xBF, 0x68, 0x69]), 'hi');
      expect(FileImportService.decodeCsvBytes(<int>[0x68, 0xC3, 0xA9]), 'hé');
    });

    test('invalid UTF-8 is an importUnreadable error', () {
      expect(
        () => FileImportService.decodeCsvBytes(<int>[0xFF, 0xFE, 0xFA]),
        throwsA(isA<AppError>()),
      );
    });

    test('a file over 2 MB is refused', () {
      expect(
        () => FileImportService.decodeCsvBytes(
          List<int>.filled(FileImportService.maxBytes + 1, 0x61),
        ),
        throwsA(
          isA<AppError>().having(
            (AppError e) => e.kind,
            'kind',
            AppErrorKind.importUnreadable,
          ),
        ),
      );
    });

    test('exactly 2 MB is accepted', () {
      expect(
        FileImportService.decodeCsvBytes(
          List<int>.filled(FileImportService.maxBytes, 0x61),
        ).length,
        FileImportService.maxBytes,
      );
    });
  });
}
