/// The database schema, as ordered migrations. The database keeps its version
/// in `PRAGMA user_version`.
class StorageMigrations {
  const StorageMigrations._();

  static const int currentVersion = 1;

  static const Map<int, List<String>> _steps = <int, List<String>>{
    1: <String>[
      '''
CREATE TABLE posts(
  id TEXT PRIMARY KEY,
  hook TEXT NOT NULL DEFAULT '', body TEXT NOT NULL DEFAULT '',
  cta TEXT NOT NULL DEFAULT '', link TEXT NOT NULL DEFAULT '',
  hashtags TEXT NOT NULL DEFAULT '[]',
  media_kind TEXT NOT NULL DEFAULT 'auto', media_path TEXT, media_duration_ms INTEGER,
  card_theme_id TEXT NOT NULL, scheduled_at INTEGER, status TEXT NOT NULL,
  created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL)''',
      'CREATE INDEX idx_posts_scheduled ON posts(scheduled_at)',
      'CREATE INDEX idx_posts_status ON posts(status)',
      '''
CREATE TABLE platform_profiles(
  id TEXT PRIMARY KEY, sort_order INTEGER NOT NULL,
  enabled INTEGER NOT NULL, is_custom INTEGER NOT NULL, json TEXT NOT NULL)''',
      '''
CREATE TABLE send_records(
  post_id TEXT NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  platform_id TEXT NOT NULL, status TEXT NOT NULL, done_at INTEGER,
  PRIMARY KEY(post_id, platform_id))''',
    ],
  };

  /// The SQL statements that take a database from version [from] to version
  /// [to], in order. Empty when there is nothing to do.
  static List<String> stepsBetween(int from, int to) {
    if (from < 0 || to > currentVersion) {
      throw ArgumentError('No migration path from $from to $to.');
    }
    return <String>[
      for (int version = from + 1; version <= to; version++)
        ..._steps[version]!,
    ];
  }
}
