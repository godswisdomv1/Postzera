import 'package:postzera/core/models/post.dart';
import 'package:postzera/core/models/reminder_slot.dart';
import 'package:postzera/core/ports/clock.dart';

/// Plans local notifications: one per distinct posting minute, never per
/// platform, and never more than [maxPending] so the app stays under iOS's
/// limit of 64.
class ReminderPlanner {
  const ReminderPlanner();

  static const int maxPending = 60;

  /// Slots for every scheduled post that is still in the future, soonest
  /// first. Posts already past due get no notification (the queue shows them
  /// as Overdue).
  ///
  /// Posts are grouped by their exact minute. That equals grouping by local
  /// date and minute, and daylight saving cannot move a slot because each one
  /// is an absolute instant.
  List<ReminderSlot> plan(List<Post> posts, Clock clock) {
    final DateTime now = clock.now();
    final Map<int, int> counts = <int, int>{};
    for (final Post post in posts) {
      final DateTime? at = post.scheduledAt;
      if (post.status != PostStatus.scheduled || at == null) {
        continue;
      }
      if (!at.isAfter(now)) {
        continue;
      }
      final int minute = at.toUtc().millisecondsSinceEpoch ~/ 60000;
      counts[minute] = (counts[minute] ?? 0) + 1;
    }
    final List<int> minutes = counts.keys.toList()..sort();
    return <ReminderSlot>[
      for (final int minute in minutes.take(maxPending))
        ReminderSlot(
          notificationId: notificationIdFor(minute),
          whenUtc: DateTime.fromMillisecondsSinceEpoch(
            minute * 60000,
            isUtc: true,
          ),
          postCount: counts[minute]!,
        ),
    ];
  }

  /// A stable 31-bit id for an epoch minute. Multiplying by an odd number
  /// modulo 2^31 is a one-to-one mapping, so two different minutes never share
  /// an id.
  static int notificationIdFor(int epochMinute) =>
      (epochMinute * 0x9E3779B1) & 0x7FFFFFFF;
}
