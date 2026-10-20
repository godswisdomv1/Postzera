import 'package:flutter_test/flutter_test.dart';
import 'package:postzera/core/models/post.dart';
import 'package:postzera/core/models/reminder_slot.dart';
import 'package:postzera/core/services/reminder_planner.dart';

import 'test_helpers.dart';

void main() {
  const ReminderPlanner planner = ReminderPlanner();
  final DateTime now = DateTime.utc(2026, 10, 18, 8);
  final FixedClock clock = FixedClock(now);

  Post scheduled(String id, DateTime at) => testPost().copyWith(
    id: id,
    status: PostStatus.scheduled,
    scheduledAt: at,
  );

  test('an empty list gives no reminders', () {
    expect(planner.plan(const <Post>[], clock), isEmpty);
  });

  test('posts in the same minute share one reminder', () {
    final List<ReminderSlot> slots = planner.plan(<Post>[
      scheduled('a', DateTime.utc(2026, 10, 18, 9)),
      scheduled('b', DateTime.utc(2026, 10, 18, 9, 0, 30)),
      scheduled('c', DateTime.utc(2026, 10, 18, 9, 0, 59)),
    ], clock);
    expect(slots.length, 1);
    expect(slots.single.postCount, 3);
    expect(slots.single.whenUtc, DateTime.utc(2026, 10, 18, 9));
  });

  test('different minutes give separate reminders, soonest first', () {
    final List<ReminderSlot> slots = planner.plan(<Post>[
      scheduled('late', DateTime.utc(2026, 10, 19, 9)),
      scheduled('early', DateTime.utc(2026, 10, 18, 9, 1)),
    ], clock);
    expect(slots.map((ReminderSlot s) => s.whenUtc).toList(), <DateTime>[
      DateTime.utc(2026, 10, 18, 9, 1),
      DateTime.utc(2026, 10, 19, 9),
    ]);
  });

  test('at most 60 reminders are kept, the soonest ones', () {
    final List<Post> posts = <Post>[
      for (int i = 0; i < 70; i++)
        scheduled(
          'p$i',
          DateTime.utc(2026, 10, 18, 9).add(Duration(minutes: i)),
        ),
    ];
    final List<ReminderSlot> slots = planner.plan(posts, clock);
    expect(slots.length, 60);
    expect(slots.first.whenUtc, DateTime.utc(2026, 10, 18, 9));
    expect(slots.last.whenUtc, DateTime.utc(2026, 10, 18, 9, 59));
  });

  test('notification ids are stable, 31-bit and distinct', () {
    final List<Post> posts = <Post>[
      for (int i = 0; i < 50; i++)
        scheduled(
          'p$i',
          DateTime.utc(2026, 10, 18, 9).add(Duration(minutes: i)),
        ),
    ];
    final List<ReminderSlot> first = planner.plan(posts, clock);
    final List<ReminderSlot> second = planner.plan(posts, clock);
    expect(first, second);
    final Set<int> ids = first
        .map((ReminderSlot s) => s.notificationId)
        .toSet();
    expect(ids.length, 50);
    for (final int id in ids) {
      expect(id, greaterThanOrEqualTo(0));
      expect(id, lessThanOrEqualTo(0x7FFFFFFF));
    }
  });

  test('past-due posts and the current instant get no reminder', () {
    final List<ReminderSlot> slots = planner.plan(<Post>[
      scheduled('past', DateTime.utc(2026, 10, 18, 7)),
      scheduled('now', now),
    ], clock);
    expect(slots, isEmpty);
  });

  test('drafts, sent posts and unscheduled posts get no reminder', () {
    final DateTime future = DateTime.utc(2026, 10, 19, 9);
    final List<ReminderSlot> slots = planner.plan(<Post>[
      testPost().copyWith(status: PostStatus.draft, scheduledAt: future),
      testPost().copyWith(status: PostStatus.sent, scheduledAt: future),
      testPost().copyWith(status: PostStatus.archived, scheduledAt: future),
      testPost().copyWith(status: PostStatus.scheduled),
    ], clock);
    expect(slots, isEmpty);
  });

  test('daylight-saving changes cannot move a slot', () {
    final DateTime january = DateTime.utc(2026, 1, 1);
    final List<DateTime> instants = <DateTime>[
      DateTime.utc(2026, 3, 8, 6, 59), // just before the US spring change
      DateTime.utc(2026, 3, 8, 7, 1), // just after
      DateTime.utc(2026, 3, 29, 0, 59), // just before the EU spring change
      DateTime.utc(2026, 3, 29, 1, 1), // just after
      DateTime.utc(2026, 10, 25, 0, 59), // just before the EU autumn change
      DateTime.utc(2026, 10, 25, 1, 1), // just after
    ];
    final List<ReminderSlot> slots = planner.plan(<Post>[
      for (int i = 0; i < instants.length; i++) scheduled('p$i', instants[i]),
    ], FixedClock(january));
    expect(slots.map((ReminderSlot s) => s.whenUtc).toList(), instants);
  });
}
