import 'package:flutter/foundation.dart';
import 'package:postzera/core/models/post.dart';
import 'package:postzera/core/models/send_record.dart';
import 'package:postzera/core/ports/clock.dart';
import 'package:postzera/core/ports/post_repository.dart';

/// One post in the queue with its "n of m sent" progress.
@immutable
class QueueEntry {
  const QueueEntry({
    required this.post,
    required this.doneCount,
    required this.skippedCount,
    required this.platformCount,
  });

  final Post post;

  /// Platforms marked as posted.
  final int doneCount;
  final int skippedCount;

  /// Enabled platforms, the "m" of "n of m".
  final int platformCount;
}

@immutable
class QueueSections {
  const QueueSections({
    this.overdue = const <QueueEntry>[],
    this.today = const <QueueEntry>[],
    this.upcoming = const <QueueEntry>[],
  });

  final List<QueueEntry> overdue;
  final List<QueueEntry> today;
  final List<QueueEntry> upcoming;

  int get total => overdue.length + today.length + upcoming.length;
  bool get isEmpty => total == 0;
}

/// Posts that share a calendar day, for the date-grouped library.
@immutable
class LibraryGroup {
  const LibraryGroup(this.day, this.posts);

  /// Local midnight of the day.
  final DateTime day;
  final List<Post> posts;
}

/// Sorting, filtering and grouping of posts.
class QueueService {
  const QueueService();

  /// The queue shows today and the next seven days.
  static const int upcomingDays = 7;

  /// Splits scheduled posts into Overdue (already past due), Today (later
  /// today) and Upcoming (the next seven days). Other posts never appear.
  /// [platformCount] is the number of enabled platforms.
  QueueSections sections(
    List<Post> posts,
    Map<String, List<SendRecord>> records,
    Clock clock, {
    required int platformCount,
  }) {
    final DateTime now = clock.now().toLocal();
    final DateTime startTomorrow = DateTime(now.year, now.month, now.day + 1);
    final DateTime end = DateTime(
      now.year,
      now.month,
      now.day + 1 + upcomingDays,
    );

    final List<QueueEntry> overdue = <QueueEntry>[];
    final List<QueueEntry> today = <QueueEntry>[];
    final List<QueueEntry> upcoming = <QueueEntry>[];

    for (final Post post in posts) {
      final DateTime? scheduled = post.scheduledAt;
      if (post.status != PostStatus.scheduled || scheduled == null) {
        continue;
      }
      final DateTime at = scheduled.toLocal();
      final List<SendRecord> own = records[post.id] ?? const <SendRecord>[];
      final QueueEntry entry = QueueEntry(
        post: post,
        doneCount:
            own.where((SendRecord r) => r.status == SendStatus.done).length,
        skippedCount:
            own.where((SendRecord r) => r.status == SendStatus.skipped).length,
        platformCount: platformCount,
      );
      if (!at.isAfter(now)) {
        overdue.add(entry);
      } else if (at.isBefore(startTomorrow)) {
        today.add(entry);
      } else if (at.isBefore(end)) {
        upcoming.add(entry);
      }
    }

    int bySchedule(QueueEntry a, QueueEntry b) {
      final int byTime = a.post.scheduledAt!.compareTo(b.post.scheduledAt!);
      return byTime != 0 ? byTime : a.post.id.compareTo(b.post.id);
    }

    return QueueSections(
      overdue: overdue..sort(bySchedule),
      today: today..sort(bySchedule),
      upcoming: upcoming..sort(bySchedule),
    );
  }

  /// Library search and ordering. The query matches the hook or the body,
  /// ignoring case.
  List<Post> filterAndSort(
    List<Post> posts, {
    String query = '',
    PostStatus? status,
    PostSort sort = PostSort.newest,
  }) {
    final String q = query.trim().toLowerCase();
    final List<Post> result = posts.where((Post p) {
      if (status != null && p.status != status) {
        return false;
      }
      if (q.isEmpty) {
        return true;
      }
      return p.hook.toLowerCase().contains(q) ||
          p.body.toLowerCase().contains(q);
    }).toList();

    int newestFirst(Post a, Post b) {
      final int byTime = b.updatedAt.compareTo(a.updatedAt);
      return byTime != 0 ? byTime : a.id.compareTo(b.id);
    }

    switch (sort) {
      case PostSort.newest:
        result.sort(newestFirst);
      case PostSort.oldest:
        result.sort((Post a, Post b) => newestFirst(b, a));
      case PostSort.scheduledSoonest:
        result.sort((Post a, Post b) {
          final DateTime? sa = a.scheduledAt;
          final DateTime? sb = b.scheduledAt;
          if (sa == null && sb == null) {
            return newestFirst(a, b);
          }
          if (sa == null) {
            return 1;
          }
          if (sb == null) {
            return -1;
          }
          final int byTime = sa.compareTo(sb);
          return byTime != 0 ? byTime : a.id.compareTo(b.id);
        });
    }
    return result;
  }

  /// Groups posts by local calendar day (scheduled time, or last update for
  /// drafts), keeping the order of [posts].
  List<LibraryGroup> groupByDay(List<Post> posts) {
    final List<LibraryGroup> groups = <LibraryGroup>[];
    for (final Post post in posts) {
      final DateTime local = (post.scheduledAt ?? post.updatedAt).toLocal();
      final DateTime day = DateTime(local.year, local.month, local.day);
      if (groups.isNotEmpty && groups.last.day == day) {
        groups.last.posts.add(post);
      } else {
        groups.add(LibraryGroup(day, <Post>[post]));
      }
    }
    return groups;
  }
}
