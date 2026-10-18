import 'package:postzera/core/models/post.dart';

/// Order of a post list.
enum PostSort {
  /// Most recently updated first.
  newest,

  /// Least recently updated first.
  oldest,

  /// Soonest scheduled time first. Drafts come last.
  scheduledSoonest,
}

/// Storage of master posts. Implemented over SQLite, with an in-memory
/// fallback.
abstract class PostRepository {
  Future<List<Post>> all();

  Future<Post?> byId(String id);

  /// Posts whose hook or body contains [query] (case-insensitive), optionally
  /// of one [status].
  Future<List<Post>> search({
    String query = '',
    PostStatus? status,
    PostSort sort = PostSort.newest,
  });

  /// Inserts or replaces a post.
  Future<void> upsert(Post post);

  /// Deletes a post. Its send records go with it.
  Future<void> delete(String id);

  Future<void> deleteAll();
}
