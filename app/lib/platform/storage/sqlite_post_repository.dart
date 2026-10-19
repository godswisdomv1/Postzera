import 'dart:convert';

import 'package:postzera/core/models/json_read.dart';
import 'package:postzera/core/models/media_source.dart';
import 'package:postzera/core/models/post.dart';
import 'package:postzera/core/ports/post_repository.dart';
import 'package:postzera/core/services/queue_service.dart';
import 'package:sqlite3/sqlite3.dart';

/// Posts in SQLite.
class SqlitePostRepository implements PostRepository {
  SqlitePostRepository(this._db);

  final Database _db;

  static const String _columns =
      'id, hook, body, cta, link, hashtags, media_kind, media_path, '
      'media_duration_ms, card_theme_id, scheduled_at, status, created_at, '
      'updated_at';

  @override
  Future<List<Post>> all() async => _query(
        'SELECT $_columns FROM posts ORDER BY updated_at DESC, id ASC',
        const <Object?>[],
      );

  @override
  Future<Post?> byId(String id) async {
    final List<Post> found =
        _query('SELECT $_columns FROM posts WHERE id = ?', <Object?>[id]);
    return found.isEmpty ? null : found.first;
  }

  @override
  Future<List<Post>> search({
    String query = '',
    PostStatus? status,
    PostSort sort = PostSort.newest,
  }) async {
    final List<String> where = <String>[];
    final List<Object?> params = <Object?>[];
    if (status != null) {
      where.add('status = ?');
      params.add(status.name);
    }
    final String q = query.trim();
    if (q.isNotEmpty) {
      final String pattern = '%${_escapeLike(q)}%';
      where.add("(hook LIKE ? ESCAPE '\\' OR body LIKE ? ESCAPE '\\')");
      params
        ..add(pattern)
        ..add(pattern);
    }
    final String order = switch (sort) {
      PostSort.newest => 'updated_at DESC, id ASC',
      PostSort.oldest => 'updated_at ASC, id ASC',
      PostSort.scheduledSoonest =>
        'scheduled_at IS NULL, scheduled_at ASC, updated_at DESC, id ASC',
    };
    return _query(
      'SELECT $_columns FROM posts'
      '${where.isEmpty ? '' : ' WHERE ${where.join(' AND ')}'}'
      ' ORDER BY $order',
      params,
    );
  }

  @override
  Future<void> upsert(Post post) async {
    // An upsert, not INSERT OR REPLACE: replacing would delete the row first
    // and cascade away its send records.
    _db.execute(
      'INSERT INTO posts($_columns) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?) '
      'ON CONFLICT(id) DO UPDATE SET '
      'hook=excluded.hook, body=excluded.body, cta=excluded.cta, '
      'link=excluded.link, hashtags=excluded.hashtags, '
      'media_kind=excluded.media_kind, media_path=excluded.media_path, '
      'media_duration_ms=excluded.media_duration_ms, '
      'card_theme_id=excluded.card_theme_id, '
      'scheduled_at=excluded.scheduled_at, status=excluded.status, '
      'created_at=excluded.created_at, updated_at=excluded.updated_at',
      <Object?>[
        post.id,
        post.hook,
        post.body,
        post.cta,
        post.link,
        jsonEncode(post.hashtags),
        post.mediaSource.kind.name,
        post.mediaSource.path,
        post.mediaSource.durationMs,
        post.cardThemeId,
        post.scheduledAt?.toUtc().millisecondsSinceEpoch,
        post.status.name,
        post.createdAt.toUtc().millisecondsSinceEpoch,
        post.updatedAt.toUtc().millisecondsSinceEpoch,
      ],
    );
  }

  @override
  Future<void> delete(String id) async {
    _db.execute('DELETE FROM posts WHERE id = ?', <Object?>[id]);
  }

  @override
  Future<void> deleteAll() async {
    _db.execute('DELETE FROM posts');
  }

  List<Post> _query(String sql, List<Object?> params) =>
      _db.select(sql, params).map(_fromRow).toList();

  static Post _fromRow(Row row) {
    final DateTime epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    return Post(
      id: readString(row['id']),
      hook: readString(row['hook']),
      body: readString(row['body']),
      cta: readString(row['cta']),
      link: readString(row['link']),
      hashtags: _decodeTags(row['hashtags']),
      mediaSource: MediaSource(
        kind: readEnum(
          MediaSourceKind.values,
          row['media_kind'],
          MediaSourceKind.auto,
        ),
        path: readStringOrNull(row['media_path']),
        durationMs: readIntOrNull(row['media_duration_ms']),
      ),
      cardThemeId: readString(row['card_theme_id'], 'paper'),
      scheduledAt: readDateOrNull(row['scheduled_at']),
      status: readEnum(PostStatus.values, row['status'], PostStatus.draft),
      createdAt: readDateOrNull(row['created_at']) ?? epoch,
      updatedAt: readDateOrNull(row['updated_at']) ?? epoch,
    );
  }

  static List<String> _decodeTags(Object? raw) {
    if (raw is! String) {
      return const <String>[];
    }
    try {
      return readStringList(jsonDecode(raw));
    } on FormatException {
      return const <String>[];
    }
  }

  static String _escapeLike(String text) => text
      .replaceAll(r'\', r'\\')
      .replaceAll('%', r'\%')
      .replaceAll('_', r'\_');
}

/// The fallback used when SQLite cannot be used. Nothing is saved to disk.
class InMemoryPostRepository implements PostRepository {
  final Map<String, Post> _posts = <String, Post>{};

  static const QueueService _service = QueueService();

  @override
  Future<List<Post>> all() async => _service.filterAndSort(_posts.values.toList());

  @override
  Future<Post?> byId(String id) async => _posts[id];

  @override
  Future<List<Post>> search({
    String query = '',
    PostStatus? status,
    PostSort sort = PostSort.newest,
  }) async =>
      _service.filterAndSort(
        _posts.values.toList(),
        query: query,
        status: status,
        sort: sort,
      );

  @override
  Future<void> upsert(Post post) async {
    _posts[post.id] = post;
  }

  @override
  Future<void> delete(String id) async {
    _posts.remove(id);
  }

  @override
  Future<void> deleteAll() async {
    _posts.clear();
  }
}
