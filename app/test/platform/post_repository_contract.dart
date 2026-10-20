import 'package:flutter_test/flutter_test.dart';
import 'package:postzera/core/models/media_source.dart';
import 'package:postzera/core/models/post.dart';
import 'package:postzera/core/ports/post_repository.dart';

import '../core/test_helpers.dart';

/// Behavior every [PostRepository] must have, run against each implementation.
void postRepositoryContract(String name, PostRepository Function() make) {
  group(name, () {
    late PostRepository repo;
    setUp(() => repo = make());

    Post post(
      String id, {
      String hook = 'Hook',
      String body = '',
      PostStatus status = PostStatus.draft,
      DateTime? updated,
      DateTime? scheduled,
    }) => testPost(hook: hook, body: body).copyWith(
      id: id,
      status: status,
      updatedAt: updated ?? DateTime.utc(2026, 10, 18),
      scheduledAt: scheduled,
    );

    test('starts empty', () async {
      expect(await repo.all(), isEmpty);
      expect(await repo.byId('nope'), isNull);
    });

    test('keeps every field of a post', () async {
      final Post full =
          testPost(
            hook: 'H',
            body: 'B',
            cta: 'C',
            link: 'https://example.com',
            tags: const <String>['#a', '#b'],
            media: const MediaSource(
              kind: MediaSourceKind.video,
              path: '/v/a.mp4',
              durationMs: 8000,
            ),
            theme: 'ink',
          ).copyWith(
            id: 'full',
            status: PostStatus.scheduled,
            scheduledAt: DateTime.utc(2026, 11, 1, 9, 30),
          );
      await repo.upsert(full);
      expect(await repo.byId('full'), full);
    });

    test('upsert replaces a post with the same id', () async {
      await repo.upsert(post('a', hook: 'First'));
      await repo.upsert(post('a', hook: 'Second'));
      final List<Post> all = await repo.all();
      expect(all.length, 1);
      expect(all.single.hook, 'Second');
    });

    test('all returns the most recently updated first', () async {
      await repo.upsert(post('old', updated: DateTime.utc(2026, 10, 1)));
      await repo.upsert(post('new', updated: DateTime.utc(2026, 10, 9)));
      await repo.upsert(post('mid', updated: DateTime.utc(2026, 10, 5)));
      expect((await repo.all()).map((Post p) => p.id).toList(), <String>[
        'new',
        'mid',
        'old',
      ]);
    });

    test('search matches hook or body, ignoring case', () async {
      await repo.upsert(post('a', hook: 'Apple pie'));
      await repo.upsert(post('b', hook: 'Banana', body: 'an apple a day'));
      await repo.upsert(post('c', hook: 'Cherry'));
      final List<Post> found = await repo.search(query: 'APPLE');
      expect(found.map((Post p) => p.id).toSet(), <String>{'a', 'b'});
    });

    test('search treats % and _ as plain text', () async {
      await repo.upsert(post('a', hook: '100% sure'));
      await repo.upsert(post('b', hook: 'plain'));
      await repo.upsert(post('c', hook: 'snake_case'));
      expect(
        (await repo.search(query: '100%')).map((Post p) => p.id).toList(),
        <String>['a'],
      );
      expect(
        (await repo.search(query: '%')).map((Post p) => p.id).toList(),
        <String>['a'],
      );
      expect(
        (await repo.search(query: 'e_c')).map((Post p) => p.id).toList(),
        <String>['c'],
      );
    });

    test('search filters by status', () async {
      await repo.upsert(post('a'));
      await repo.upsert(post('b', status: PostStatus.sent));
      final List<Post> sent = await repo.search(status: PostStatus.sent);
      expect(sent.single.id, 'b');
    });

    test('search sorts newest, oldest and soonest scheduled', () async {
      await repo.upsert(post('a', updated: DateTime.utc(2026, 10, 1)));
      await repo.upsert(
        post(
          'b',
          updated: DateTime.utc(2026, 10, 5),
          scheduled: DateTime.utc(2026, 10, 30),
        ),
      );
      await repo.upsert(
        post(
          'c',
          updated: DateTime.utc(2026, 10, 3),
          scheduled: DateTime.utc(2026, 10, 20),
        ),
      );
      Future<List<String>> ids(PostSort sort) async =>
          (await repo.search(sort: sort)).map((Post p) => p.id).toList();
      expect(await ids(PostSort.newest), <String>['b', 'c', 'a']);
      expect(await ids(PostSort.oldest), <String>['a', 'c', 'b']);
      expect(await ids(PostSort.scheduledSoonest), <String>['c', 'b', 'a']);
    });

    test('delete removes one post and deleteAll removes everything', () async {
      await repo.upsert(post('a'));
      await repo.upsert(post('b'));
      await repo.delete('a');
      expect((await repo.all()).map((Post p) => p.id).toList(), <String>['b']);
      await repo.deleteAll();
      expect(await repo.all(), isEmpty);
    });
  });
}
