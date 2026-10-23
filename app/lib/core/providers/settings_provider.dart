import 'package:flutter/foundation.dart';
import 'package:postzera/core/models/app_error.dart';
import 'package:postzera/core/models/app_settings.dart';
import 'package:postzera/core/models/post.dart';
import 'package:postzera/core/ports/file_store_port.dart';
import 'package:postzera/core/ports/notification_port.dart';
import 'package:postzera/core/ports/post_repository.dart';
import 'package:postzera/core/ports/profile_repository.dart';
import 'package:postzera/core/ports/send_record_repository.dart';
import 'package:postzera/core/providers/banner_provider.dart';
import 'package:postzera/core/providers/settings_sync.dart';
import 'package:postzera/core/services/error_classifier.dart';
import 'package:postzera/utils/log.dart';

@immutable
class SettingsViewState {
  const SettingsViewState({
    this.settings = const AppSettings(),
    this.loaded = false,
    this.deleting = false,
  });

  final AppSettings settings;
  final bool loaded;
  final bool deleting;

  SettingsViewState copyWith({
    AppSettings? settings,
    bool? loaded,
    bool? deleting,
  }) =>
      SettingsViewState(
        settings: settings ?? this.settings,
        loaded: loaded ?? this.loaded,
        deleting: deleting ?? this.deleting,
      );
}

/// Reminder settings, the default card theme, the onboarding flag, and
/// **Delete all data**.
class SettingsProvider extends ValueNotifier<SettingsViewState> {
  SettingsProvider({
    required SettingsSync sync,
    required PostRepository posts,
    required ProfileRepository profiles,
    required SendRecordRepository records,
    required FileStorePort files,
    required NotificationPort notifications,
    required BannerProvider banners,
    this.onChanged,
    ErrorClassifier classifier = const ErrorClassifier(),
  })  : _sync = sync,
        _posts = posts,
        _profiles = profiles,
        _records = records,
        _files = files,
        _notifications = notifications,
        _banners = banners,
        _classifier = classifier,
        super(SettingsViewState(settings: sync.current, loaded: sync.loaded)) {
    _sync.addListener(_onSync);
  }

  final SettingsSync _sync;
  final PostRepository _posts;
  final ProfileRepository _profiles;
  final SendRecordRepository _records;
  final FileStorePort _files;
  final NotificationPort _notifications;
  final BannerProvider _banners;
  final ErrorClassifier _classifier;

  /// Called after a change that affects reminders.
  final VoidCallback? onChanged;

  Future<void> load() async {
    await _sync.load();
  }

  Future<void> setRemindersEnabled({required bool enabled}) => _change(
        (AppSettings s) => s.copyWith(remindersEnabled: enabled),
        affectsReminders: true,
      );

  /// Minutes from midnight, 0 to 1439.
  Future<void> setReminderMinutes(int minutes) => _change(
        (AppSettings s) => s.copyWith(reminderMinutes: minutes.clamp(0, 1439)),
        affectsReminders: true,
      );

  Future<void> setDefaultCardTheme(String id) =>
      _change((AppSettings s) => s.copyWith(defaultCardThemeId: id));

  Future<void> completeOnboarding() =>
      _change((AppSettings s) => s.copyWith(onboardingDone: true));

  /// Removes every post, platform setting, setting, cached purchase flag,
  /// media file and reminder, then returns to the first-run state. The
  /// purchase itself stays with the store account.
  Future<void> deleteAllData() async {
    value = value.copyWith(deleting: true);
    try {
      final List<Post> all = await _posts.all();
      for (final Post post in all) {
        await _records.deleteForPost(post.id);
      }
      await _posts.deleteAll();
      await _profiles.deleteAll();
      await _profiles.ensureDefaults();
      await _files.deleteAllMedia();
      await _notifications.cancelAll();
      await _sync.reset();
      _banners.success(BannerMessage.dataDeleted);
      onChanged?.call();
    } catch (error) {
      Log.w('settings', 'delete all failed: ${error.runtimeType}');
      _banners.failure(
        _classifier.classify(error, fallback: AppErrorKind.unexpected),
      );
    } finally {
      value = value.copyWith(deleting: false);
    }
  }

  Future<void> _change(
    AppSettings Function(AppSettings) change, {
    bool affectsReminders = false,
  }) async {
    try {
      await _sync.update(change);
    } on AppError catch (error) {
      _banners.failure(error);
    }
    if (affectsReminders) {
      onChanged?.call();
    }
  }

  void _onSync() {
    value = value.copyWith(settings: _sync.current, loaded: _sync.loaded);
  }

  @override
  void dispose() {
    _sync.removeListener(_onSync);
    super.dispose();
  }
}
