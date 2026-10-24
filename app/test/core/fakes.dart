import 'dart:async';

import 'package:postzera/core/models/app_settings.dart';
import 'package:postzera/core/models/consent_state.dart';
import 'package:postzera/core/models/entitlement.dart';
import 'package:postzera/core/models/media_spec.dart';
import 'package:postzera/core/models/reminder_slot.dart';
import 'package:postzera/core/models/variant.dart';
import 'package:postzera/core/ports/ads_port.dart';
import 'package:postzera/core/ports/consent_port.dart';
import 'package:postzera/core/ports/file_import_port.dart';
import 'package:postzera/core/ports/file_store_port.dart';
import 'package:postzera/core/ports/media_picker_port.dart';
import 'package:postzera/core/ports/media_renderer_port.dart';
import 'package:postzera/core/ports/notification_port.dart';
import 'package:postzera/core/ports/purchase_port.dart';
import 'package:postzera/core/ports/settings_store.dart';
import 'package:postzera/core/ports/share_port.dart';
import 'package:postzera/core/ports/video_composer_port.dart';

class FakeSettingsStore implements SettingsStore {
  AppSettings settings = const AppSettings();
  Entitlement? cache;
  bool failSave = false;
  int saves = 0;
  int clears = 0;

  @override
  Future<AppSettings> load() async => settings;

  @override
  Future<void> save(AppSettings value) async {
    if (failSave) {
      throw StateError('disk');
    }
    saves++;
    settings = value;
  }

  @override
  Future<Entitlement?> loadEntitlementCache() async => cache;

  @override
  Future<void> saveEntitlementCache(Entitlement entitlement) async {
    cache = entitlement;
  }

  @override
  Future<void> clearAll() async {
    clears++;
    settings = const AppSettings();
    cache = null;
  }
}

class FakeFileStore implements FileStorePort {
  /// Path to size in bytes.
  final Map<String, int> sizes = <String, int>{};
  final List<String> deletedPostFiles = <String>[];
  final List<String> deletedOutputs = <String>[];
  final List<String> deleted = <String>[];
  final Map<String, String> exports = <String, String>{};
  bool deletedAll = false;
  bool failCopy = false;

  @override
  Future<String> outputPath({
    required String postId,
    required String platformId,
    required String extension,
    String? suffix,
  }) async =>
      '/out/$postId/$platformId${suffix == null ? '' : '_$suffix'}.$extension';

  @override
  Future<String> copyIntoSources({
    required String postId,
    required String fromPath,
  }) async {
    if (failCopy) {
      throw StateError('copy');
    }
    final String ext = fromPath.contains('.') ? fromPath.split('.').last : '';
    final String path = '/src/$postId.$ext';
    sizes[path] = 10;
    return path;
  }

  @override
  Future<String> writeExportFile({
    required String name,
    required String content,
  }) async {
    final String path = '/exports/$name';
    exports[path] = content;
    sizes[path] = content.length;
    return path;
  }

  @override
  Future<FileInfo?> stat(String path) async {
    final int? size = sizes[path];
    return size == null
        ? null
        : FileInfo(sizeBytes: size, modified: DateTime.utc(2026, 10, 1));
  }

  @override
  Future<void> delete(String path) async {
    deleted.add(path);
    sizes.remove(path);
  }

  @override
  Future<void> deletePostFiles(String postId) async {
    deletedPostFiles.add(postId);
  }

  @override
  Future<void> deleteOutputs(String postId) async {
    deletedOutputs.add(postId);
  }

  @override
  Future<int> sweepOutputs({required Duration olderThan}) async => 0;

  @override
  Future<void> deleteAllMedia() async {
    deletedAll = true;
  }
}

class FakeRenderer implements MediaRendererPort {
  FakeRenderer(this.files);

  final FakeFileStore files;
  int images = 0;
  int slides = 0;
  Object? failWith;

  /// When set, rendering waits until it is completed.
  Completer<void>? gate;

  void _write(String path) {
    final Object? error = failWith;
    if (error != null) {
      throw error;
    }
    files.sizes[path] = 100;
  }

  @override
  Future<void> renderImage(MediaPlan plan, {required String outPath}) async {
    images++;
    await gate?.future;
    _write(outPath);
  }

  @override
  Future<void> renderSlide(
    SlidePlan slide,
    MediaPlan plan, {
    required String outPath,
  }) async {
    slides++;
    _write(outPath);
  }

  @override
  Future<void> renderOverlay(
    MediaPlan plan, {
    required List<CardTextBlock> blocks,
    required String outPath,
  }) async {
    _write(outPath);
  }
}

class FakeVideo implements VideoComposerPort {
  FakeVideo(this.files);

  final FakeFileStore files;

  @override
  Future<void> composeSlides(
    List<SlideFile> slides,
    MediaSpec spec, {
    required String outPath,
    void Function(double progress)? onProgress,
  }) async {
    files.sizes[outPath] = 1000;
  }

  @override
  Future<void> reframeWithOverlay(
    String source,
    MediaPlan plan, {
    required List<TimedOverlay> overlays,
    required String outPath,
    void Function(double progress)? onProgress,
  }) async {
    files.sizes[outPath] = 1000;
  }

  @override
  Future<void> cancel() async {}
}

class FakeNotifications implements NotificationPort {
  NotificationPermission permission = NotificationPermission.unknown;
  NotificationPermission onRequest = NotificationPermission.granted;
  final List<List<ReminderSlot>> replaced = <List<ReminderSlot>>[];
  int cancels = 0;
  int inits = 0;
  Object? failReplace;
  Completer<void>? gate;
  NotificationTap? launch;
  final StreamController<NotificationTap> tapController =
      StreamController<NotificationTap>.broadcast();

  @override
  Future<void> init() async {
    inits++;
  }

  @override
  Future<NotificationPermission> requestPermission() async {
    permission = onRequest;
    return onRequest;
  }

  @override
  Future<NotificationPermission> permissionStatus() async => permission;

  @override
  Future<void> replaceAll(
    List<ReminderSlot> slots,
    NotificationTexts texts,
  ) async {
    final Object? error = failReplace;
    if (error != null) {
      throw error;
    }
    await gate?.future;
    replaced.add(slots);
  }

  @override
  Future<void> cancelAll() async {
    cancels++;
  }

  @override
  Stream<NotificationTap> get taps => tapController.stream;

  @override
  Future<NotificationTap?> launchTap() async => launch;
}

class FakePurchases implements PurchasePort {
  final StreamController<PurchaseEvent> controller =
      StreamController<PurchaseEvent>.broadcast();
  int connects = 0;
  String? price = r'$41.99';
  bool? owned;
  PurchaseEvent? onBuy;
  PurchaseEvent? onRestore;

  @override
  Future<void> connect() async {
    connects++;
  }

  @override
  Future<String?> localizedPrice() async => price;

  @override
  Future<bool?> ownsPro() async => owned;

  @override
  Future<void> buyPro() async {
    final PurchaseEvent? e = onBuy;
    if (e != null) {
      controller.add(e);
    }
  }

  @override
  Future<void> restore() async {
    final PurchaseEvent? e = onRestore;
    if (e != null) {
      controller.add(e);
    }
  }

  @override
  Stream<PurchaseEvent> get events => controller.stream;
}

class FakeConsent implements ConsentPort {
  ConsentRefreshResult next = const ConsentRefreshResult(
    updateOk: true,
    status: ConsentStatus.notRequired,
    canRequestAds: true,
    privacyOptionsRequired: false,
  );
  ConsentRefreshResult? afterOptions;
  Object? failRefresh;
  int refreshes = 0;

  @override
  Future<ConsentRefreshResult> refresh() async {
    refreshes++;
    final Object? error = failRefresh;
    if (error != null) {
      throw error;
    }
    return next;
  }

  @override
  Future<ConsentRefreshResult> showPrivacyOptions() async => afterOptions ?? next;
}

class FakeBanner implements BannerHandle {
  @override
  double get heightDp => 60;

  bool disposed = false;

  @override
  void dispose() {
    disposed = true;
  }
}

class FakeAds implements AdsPort {
  /// What each call to loadBanner returns, in order. Null means a failure.
  final List<FakeBanner?> script = <FakeBanner?>[];
  int initializes = 0;
  int loads = 0;
  final List<FakeBanner> made = <FakeBanner>[];

  @override
  Future<void> initialize() async {
    initializes++;
  }

  @override
  Future<BannerHandle?> loadBanner(int widthDp) async {
    loads++;
    if (script.isEmpty) {
      final FakeBanner b = FakeBanner();
      made.add(b);
      return b;
    }
    final FakeBanner? next = script.removeAt(0);
    if (next != null) {
      made.add(next);
    }
    return next;
  }
}

class FakeShare implements SharePort {
  ShareOutcome outcome = ShareOutcome.opened;
  Object? failWith;
  final List<({String path, String text})> shared = <({String path, String text})>[];

  @override
  Future<ShareOutcome> share({
    required String filePath,
    required String text,
    ShareOrigin? origin,
  }) async {
    final Object? error = failWith;
    if (error != null) {
      throw error;
    }
    shared.add((path: filePath, text: text));
    return outcome;
  }
}

class FakeClipboard implements ClipboardPort {
  final List<String> copied = <String>[];

  @override
  Future<void> copy(String text) async {
    copied.add(text);
  }
}

class FakePicker implements MediaPickerPort {
  PickedMedia? photo;
  PickedMedia? video;
  Object? failWith;

  @override
  Future<PickedMedia?> pickPhoto() async {
    final Object? error = failWith;
    if (error != null) {
      throw error;
    }
    return photo;
  }

  @override
  Future<PickedMedia?> pickVideo() async {
    final Object? error = failWith;
    if (error != null) {
      throw error;
    }
    return video;
  }
}

class FakeImport implements FileImportPort {
  ImportedFile? file;
  Object? failWith;

  @override
  Future<ImportedFile?> pickCsv() async {
    final Object? error = failWith;
    if (error != null) {
      throw error;
    }
    return file;
  }
}

NotificationTexts testTexts(int platformCount) => NotificationTexts(
      title: 'Time to post',
      channelName: 'Reminders',
      bodyFor: (int n) => '$n posts ready for $platformCount platforms',
    );
