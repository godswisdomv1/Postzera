import 'package:flutter/foundation.dart';

/// One notification to schedule: a posting time and how many posts are due.
/// Computed by the reminder planner, never stored.
@immutable
class ReminderSlot {
  const ReminderSlot({
    required this.notificationId,
    required this.whenUtc,
    required this.postCount,
  });

  /// Stable 31-bit id derived from the slot's epoch minute.
  final int notificationId;
  final DateTime whenUtc;
  final int postCount;

  @override
  bool operator ==(Object other) =>
      other is ReminderSlot &&
      other.notificationId == notificationId &&
      other.whenUtc == whenUtc &&
      other.postCount == postCount;

  @override
  int get hashCode => Object.hash(notificationId, whenUtc, postCount);

  @override
  String toString() => 'ReminderSlot($notificationId, $whenUtc, $postCount)';
}
