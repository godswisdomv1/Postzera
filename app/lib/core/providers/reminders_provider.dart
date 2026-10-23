import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:postzera/core/models/app_error.dart';
import 'package:postzera/core/models/post.dart';
import 'package:postzera/core/models/reminder_slot.dart';
import 'package:postzera/core/ports/clock.dart';
import 'package:postzera/core/ports/notification_port.dart';
import 'package:postzera/core/ports/post_repository.dart';
import 'package:postzera/core/providers/profiles_provider.dart';
import 'package:postzera/core/providers/settings_sync.dart';
import 'package:postzera/core/services/error_classifier.dart';
import 'package:postzera/core/services/reminder_planner.dart';

@immutable
class RemindersState {
  const RemindersState({
    this.permission = NotificationPermission.unknown,
    this.syncing = false,
    this.error,
    this.scheduledCount = 0,
  });

  final NotificationPermission permission;
  final bool syncing;

  /// A retryable `scheduleFailed` error. Sending is never affected.
  final AppError? error;

  /// How many reminders the last sync scheduled.
  final int scheduledCount;

  RemindersState copyWith({
    NotificationPermission? permission,
    bool? syncing,
    AppError? error,
    bool clearError = false,
    int? scheduledCount,
  }) =>
      RemindersState(
        permission: permission ?? this.permission,
        syncing: syncing ?? this.syncing,
        error: clearError ? null : (error ?? this.error),
        scheduledCount: scheduledCount ?? this.scheduledCount,
      );
}

/// Keeps the phone's reminders in step with the scheduled posts. A sync cancels
/// everything and schedules the plan again, so it is safe to run any time:
/// at launch, after a post is saved, deleted or sent, when reminder settings
/// change, when permission is granted, and when the app returns to the front
/// (which also covers a changed time zone).
class RemindersProvider extends ValueNotifier<RemindersState> {
  RemindersProvider({
    required NotificationPort notifications,
    required PostRepository posts,
    required ProfilesProvider profiles,
    required SettingsSync settings,
    required Clock clock,
    required this.texts,
    ReminderPlanner planner = const ReminderPlanner(),
    ErrorClassifier classifier = const ErrorClassifier(),
  })  : _notifications = notifications,
        _posts = posts,
        _profiles = profiles,
        _settings = settings,
        _clock = clock,
        _planner = planner,
        _classifier = classifier,
        super(const RemindersState());

  final NotificationPort _notifications;
  final PostRepository _posts;
  final ProfilesProvider _profiles;
  final SettingsSync _settings;
  final Clock _clock;
  final ReminderPlanner _planner;
  final ErrorClassifier _classifier;

  /// Builds the localized reminder text. The argument is the number of enabled
  /// platforms. Set by the app shell, which knows the current language.
  NotificationTexts Function(int platformCount) texts;

  bool _again = false;

  /// Notification taps while the app is running.
  Stream<NotificationTap> get taps => _notifications.taps;

  /// The tap that launched the app, if any.
  Future<NotificationTap?> launchTap() => _notifications.launchTap();

  /// Prepares notifications and reads the permission. Does not ask.
  Future<void> init() async {
    try {
      await _notifications.init();
      value = value.copyWith(
        permission: await _notifications.permissionStatus(),
        clearError: true,
      );
    } catch (error) {
      value = value.copyWith(
        error: _classifier.classify(error, fallback: AppErrorKind.scheduleFailed),
      );
    }
  }

  /// Asks the system for permission, then syncs. Call only after explaining
  /// why (the end of onboarding).
  Future<NotificationPermission> requestPermission() async {
    final NotificationPermission result = await _notifications.requestPermission();
    value = value.copyWith(permission: result);
    if (result == NotificationPermission.granted) {
      await sync();
    }
    return result;
  }

  /// Re-reads the permission, for when the user returns from system settings.
  Future<void> refreshPermission() async {
    value = value.copyWith(permission: await _notifications.permissionStatus());
  }

  /// Replans and reschedules. If called while a sync runs, one more sync runs
  /// afterwards, so the last change always wins.
  Future<void> sync() async {
    if (value.syncing) {
      _again = true;
      return;
    }
    value = value.copyWith(syncing: true);
    try {
      do {
        _again = false;
        await _syncOnce();
      } while (_again);
    } finally {
      value = value.copyWith(syncing: false);
    }
  }

  Future<void> _syncOnce() async {
    try {
      if (!_settings.current.remindersEnabled) {
        await _notifications.cancelAll();
        value = value.copyWith(scheduledCount: 0, clearError: true);
        return;
      }
      final List<Post> scheduled =
          await _posts.search(status: PostStatus.scheduled);
      final List<ReminderSlot> slots = _planner.plan(scheduled, _clock);
      await _notifications.replaceAll(
        slots,
        texts(_profiles.value.enabled.length),
      );
      value = value.copyWith(scheduledCount: slots.length, clearError: true);
    } catch (error) {
      value = value.copyWith(
        error: _classifier.classify(error, fallback: AppErrorKind.scheduleFailed),
      );
    }
  }
}
