import 'package:flutter/foundation.dart';
import 'package:postzera/core/models/reminder_slot.dart';

enum NotificationPermission { unknown, granted, denied }

/// A tap on a delivered reminder.
@immutable
class NotificationTap {
  const NotificationTap(this.notificationId);

  final int notificationId;
}

/// Localized text for reminders.
@immutable
class NotificationTexts {
  const NotificationTexts({
    required this.title,
    required this.channelName,
    required this.bodyFor,
  });

  final String title;
  final String channelName;

  /// The body for a reminder with this many posts due.
  final String Function(int postCount) bodyFor;
}

/// Local reminder notifications. No server and no exact-alarm permission.
abstract class NotificationPort {
  Future<void> init();

  /// Asks the system for permission. Call only after explaining why.
  Future<NotificationPermission> requestPermission();

  Future<NotificationPermission> permissionStatus();

  /// Cancels every Postzera notification, then schedules one per slot.
  Future<void> replaceAll(List<ReminderSlot> slots, NotificationTexts texts);

  Future<void> cancelAll();

  /// Taps on reminders while the app is running.
  Stream<NotificationTap> get taps;

  /// The tap that launched the app, if it was launched by a reminder.
  Future<NotificationTap?> launchTap();
}
