import 'package:postzera/core/models/json_read.dart';
import 'package:postzera/core/models/send_record.dart';
import 'package:postzera/core/ports/send_record_repository.dart';
import 'package:sqlite3/sqlite3.dart';

/// Send records in SQLite. Deleting a post removes its records (cascade).
class SqliteSendRecordRepository implements SendRecordRepository {
  SqliteSendRecordRepository(this._db);

  final Database _db;

  static const String _columns = 'post_id, platform_id, status, done_at';

  /// SQLite limits the number of `?` in one statement.
  static const int _chunk = 400;

  @override
  Future<List<SendRecord>> forPost(String postId) async => _db
      .select('SELECT $_columns FROM send_records WHERE post_id = ?', <Object?>[postId])
      .map(_fromRow)
      .toList();

  @override
  Future<Map<String, List<SendRecord>>> forPosts(List<String> postIds) async {
    final Map<String, List<SendRecord>> result = <String, List<SendRecord>>{};
    for (int start = 0; start < postIds.length; start += _chunk) {
      final List<String> ids = postIds.sublist(
        start,
        start + _chunk > postIds.length ? postIds.length : start + _chunk,
      );
      final String marks = List<String>.filled(ids.length, '?').join(',');
      final ResultSet rows = _db.select(
        'SELECT $_columns FROM send_records WHERE post_id IN ($marks)',
        ids,
      );
      for (final Row row in rows) {
        final SendRecord record = _fromRow(row);
        result.putIfAbsent(record.postId, () => <SendRecord>[]).add(record);
      }
    }
    return result;
  }

  @override
  Future<void> upsert(SendRecord record) async {
    _db.execute(
      'INSERT INTO send_records($_columns) VALUES(?,?,?,?) '
      'ON CONFLICT(post_id, platform_id) DO UPDATE SET '
      'status=excluded.status, done_at=excluded.done_at',
      <Object?>[
        record.postId,
        record.platformId,
        record.status.name,
        record.doneAt?.toUtc().millisecondsSinceEpoch,
      ],
    );
  }

  @override
  Future<void> deleteForPost(String postId) async {
    _db.execute('DELETE FROM send_records WHERE post_id = ?', <Object?>[postId]);
  }

  static SendRecord _fromRow(Row row) => SendRecord(
        postId: readString(row['post_id']),
        platformId: readString(row['platform_id']),
        status: readEnum(SendStatus.values, row['status'], SendStatus.pending),
        doneAt: readDateOrNull(row['done_at']),
      );
}

/// The fallback used when SQLite cannot be used.
class InMemorySendRecordRepository implements SendRecordRepository {
  final Map<String, Map<String, SendRecord>> _byPost =
      <String, Map<String, SendRecord>>{};

  @override
  Future<List<SendRecord>> forPost(String postId) async =>
      (_byPost[postId]?.values ?? const Iterable<SendRecord>.empty()).toList();

  @override
  Future<Map<String, List<SendRecord>>> forPosts(List<String> postIds) async =>
      <String, List<SendRecord>>{
        for (final String id in postIds)
          if (_byPost[id] != null) id: _byPost[id]!.values.toList(),
      };

  @override
  Future<void> upsert(SendRecord record) async {
    _byPost.putIfAbsent(record.postId, () => <String, SendRecord>{})[
        record.platformId] = record;
  }

  @override
  Future<void> deleteForPost(String postId) async {
    _byPost.remove(postId);
  }
}
