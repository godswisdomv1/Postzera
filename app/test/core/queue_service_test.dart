import 'package:flutter_test/flutter_test.dart';
import 'package:postzera/core/models/post.dart';
import 'package:postzera/core/models/send_record.dart';
import 'package:postzera/core/ports/post_repository.dart';
import 'package:postzera/core/services/queue_service.dart';

import 'test_helpers.dart';

void main() {
  const QueueService service = QueueService();
  // Local noon, so "today" is unambiguous in any time zone.
  final DateTime now = DateTime(2026, 10, 18, 12);
  final FixedClock clock = FixedClock(now);

  Post scheduled(String id, DateTime at, {PostStatus? status}) =>
      testPost(hook: id).copyWith(
        id: id,
        status: status ?? PostStatus.scheduled,
        scheduledAt: at.toUtc(),
      );

  group('sections', () {
    test('splits into overdue, today and upcoming', () {
      final QueueSections s = service.sections(<Post>[
        scheduled('overdue', DateTime(2026, 10, 18, 9)),
        scheduled('today', DateTime(2026, 10, 18, 18)),
        scheduled('tomorrow', DateTime(2026, 10, 19, 9)),
        scheduled('in7', DateTime(2026, 10, 25, 9)),
        scheduled('in8', DateTime(2026, 10, 26, 9)),
        scheduled('yesterday', DateTime(2026, 10, 17, 9)),
      ], const <String, List<SendRecord>>{}, clock, platformCount: 9);
      expect(s.overdue.map((QueueEntry e) => e.post.id).toList(), <String>[
        'yesterday',
        'overdue',
      ]);
      expect(s.today.map((QueueEntry e) => e.post.id).toList(), <String>['today']);
      expect(s.upcoming.map((QueueEntry e) => e.post.id).toList(), <String>[
        'tomorrow',
        'in7',
      ]);
      expect(s.total, 5);
    });

    test('drafts and sent posts never appear', () {
      final QueueSections s = service.sections(<Post>[
        scheduled('draft', DateTime(2026, 10, 18, 18), status: PostStatus.draft),
        scheduled('sent', DateTime(2026, 10, 18, 18), status: PostStatus.sent),
        testPost().copyWith(status: PostStatus.scheduled),
      ], const <String, List<SendRecord>>{}, clock, platformCount: 9);
      expect(s.isEmpty, isTrue);
    });

    test('counts sent and skipped platforms', () {
      final QueueSections s = service.sections(
        <Post>[scheduled('a', DateTime(2026, 10, 18, 18))],
        <String, List<SendRecord>>{
          'a': <SendRecord>[
            const SendRecord(postId: 'a', platformId: 'x', status: SendStatus.done),
            const SendRecord(
              postId: 'a',
              platformId: 'instagram',
              status: SendStatus.done,
            ),
            const SendRecord(
              postId: 'a',
              platformId: 'reddit',
              status: SendStatus.skipped,
            ),
            const SendRecord(
              postId: 'a',
              platformId: 'quora',
              status: SendStatus.pending,
            ),
          ],
        },
        clock,
        platformCount: 9,
      );
      final QueueEntry e = s.today.single;
      expect(e.doneCount, 2);
      expect(e.skippedCount, 1);
      expect(e.platformCount, 9);
    });
  });

  group('library', () {
    final Post a = testPost(hook: 'Apple pie', body: 'Sweet').copyWith(
      id: 'a',
      status: PostStatus.draft,
      updatedAt: DateTime.utc(2026, 10, 1),
    );
    final Post b = testPost(hook: 'Banana', body: 'apple sauce').copyWith(
      id: 'b',
      status: PostStatus.scheduled,
      scheduledAt: DateTime.utc(2026, 10, 30),
      updatedAt: DateTime.utc(2026, 10, 5),
    );
    final Post c = testPost(hook: 'Cherry').copyWith(
      id: 'c',
      status: PostStatus.sent,
      scheduledAt: DateTime.utc(2026, 10, 20),
      updatedAt: DateTime.utc(2026, 10, 3),
    );
    final List<Post> all = <Post>[a, b, c];

    test('search matches hook or body, ignoring case', () {
      expect(
        service.filterAndSort(all, query: 'APPLE').map((Post p) => p.id).toSet(),
        <String>{'a', 'b'},
      );
    });

    test('filters by status', () {
      expect(
        service.filterAndSort(all, status: PostStatus.sent).single.id,
        'c',
      );
    });

    test('sorts newest, oldest and soonest scheduled', () {
      List<String> ids(PostSort sort) =>
          service.filterAndSort(all, sort: sort).map((Post p) => p.id).toList();
      expect(ids(PostSort.newest), <String>['b', 'c', 'a']);
      expect(ids(PostSort.oldest), <String>['a', 'c', 'b']);
      expect(ids(PostSort.scheduledSoonest), <String>['c', 'b', 'a']);
    });

    test('groups by local day and keeps order', () {
      final List<LibraryGroup> groups = service.groupByDay(<Post>[
        a.copyWith(updatedAt: DateTime(2026, 10, 18, 9)),
        b.copyWith(scheduledAt: DateTime(2026, 10, 18, 20).toUtc()),
        c.copyWith(scheduledAt: DateTime(2026, 10, 17, 8).toUtc()),
      ]);
      expect(groups.length, 2);
      expect(groups.first.day, DateTime(2026, 10, 18));
      expect(groups.first.posts.length, 2);
      expect(groups.last.day, DateTime(2026, 10, 17));
    });
  });
}
