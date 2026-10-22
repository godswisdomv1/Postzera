import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:postzera/core/models/app_error.dart';
import 'package:postzera/core/models/reminder_slot.dart';
import 'package:postzera/core/ports/notification_port.dart';
import 'package:postzera/core/services/error_classifier.dart';
import 'package:postzera/platform/notifications/timezone_service.dart';
import 'package:postzera/utils/log.dart';

/// Local reminders. Scheduling is inexact (allowed while idle), so no
/// exact-alarm permission is needed.
class NotificationService implements NotificationPort {
  NotificationService({
    FlutterLocalNotificationsPlugin? plugin,
    TimezoneService? zones,
    this.classifier = const ErrorClassifier(),
  })  : _plugin = plugin ?? FlutterLocalNotificationsPlugin(),
        _zones = zones ?? TimezoneService();

  static const String channelId = 'postzera_reminders';
  static const String iconName = 'ic_stat_postzera';
  static const String payload = 'queue';

  final FlutterLocalNotificationsPlugin _plugin;
  final TimezoneService _zones;
  final ErrorClassifier classifier;
  final StreamController<NotificationTap> _taps =
      StreamController<NotificationTap>.broadcast();

  bool _ready = false;

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  IOSFlutterLocalNotificationsPlugin? get _ios => _plugin
      .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();

  @override
  Stream<NotificationTap> get taps => _taps.stream;

  @override
  Future<void> init() async {
    if (_ready) {
      return;
    }
    try {
      await _zones.init();
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings(iconName),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          final int? id = response.id;
          if (id != null) {
            _taps.add(NotificationTap(id));
          }
        },
      );
      _ready = true;
    } catch (error) {
      throw classifier.classify(error, fallback: AppErrorKind.scheduleFailed);
    }
  }

  @override
  Future<NotificationPermission> requestPermission() async {
    try {
      final bool? granted = await _android?.requestNotificationsPermission() ??
          await _ios?.requestPermissions(alert: true, badge: true, sound: true);
      return granted == true
          ? NotificationPermission.granted
          : NotificationPermission.denied;
    } catch (error) {
      Log.w('notify', 'permission request failed: ${error.runtimeType}');
      return NotificationPermission.unknown;
    }
  }

  @override
  Future<NotificationPermission> permissionStatus() async {
    try {
      final AndroidFlutterLocalNotificationsPlugin? android = _android;
      if (android != null) {
        final bool? enabled = await android.areNotificationsEnabled();
        return enabled == true
            ? NotificationPermission.granted
            : NotificationPermission.denied;
      }
      final NotificationsEnabledOptions? options = await _ios?.checkPermissions();
      if (options == null) {
        return NotificationPermission.unknown;
      }
      return options.isEnabled
          ? NotificationPermission.granted
          : NotificationPermission.denied;
    } catch (error) {
      Log.w('notify', 'permission check failed: ${error.runtimeType}');
      return NotificationPermission.unknown;
    }
  }

  @override
  Future<void> replaceAll(
    List<ReminderSlot> slots,
    NotificationTexts texts,
  ) async {
    await init();
    await cancelAll();
    Object? firstFailure;
    for (final ReminderSlot slot in slots) {
      try {
        await _schedule(slot, texts);
      } catch (error) {
        firstFailure ??= error;
        Log.w('notify', 'schedule failed: ${error.runtimeType}');
      }
    }
    if (firstFailure != null) {
      throw classifier.classify(firstFailure, fallback: AppErrorKind.scheduleFailed);
    }
  }

  Future<void> _schedule(ReminderSlot slot, NotificationTexts texts) async {
    final String body = texts.bodyFor(slot.postCount);
    final AndroidFlutterLocalNotificationsPlugin? android = _android;
    if (android != null) {
      await android.zonedSchedule(
        id: slot.notificationId,
        title: texts.title,
        body: body,
        scheduledDate: _zones.toLocal(slot.whenUtc),
        payload: payload,
        scheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        notificationDetails: AndroidNotificationDetails(
          channelId,
          texts.channelName,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          icon: iconName,
        ),
      );
      return;
    }
    await _ios?.zonedSchedule(
      id: slot.notificationId,
      title: texts.title,
      body: body,
      scheduledDate: _zones.toLocal(slot.whenUtc),
      payload: payload,
      notificationDetails: const DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
        presentBadge: false,
      ),
    );
  }

  @override
  Future<void> cancelAll() async {
    try {
      await _android?.cancelAll();
      await _ios?.cancelAll();
    } catch (error) {
      throw classifier.classify(error, fallback: AppErrorKind.scheduleFailed);
    }
  }

  @override
  Future<NotificationTap?> launchTap() async {
    try {
      final NotificationAppLaunchDetails? details =
          await _android?.getNotificationAppLaunchDetails() ??
              await _ios?.getNotificationAppLaunchDetails();
      final int? id = details?.notificationResponse?.id;
      if (details == null || !details.didNotificationLaunchApp || id == null) {
        return null;
      }
      return NotificationTap(id);
    } catch (error) {
      Log.w('notify', 'launch details failed: ${error.runtimeType}');
      return null;
    }
  }
}
