import 'package:postzera/core/models/send_record.dart';

/// Storage of per-platform send status.
abstract class SendRecordRepository {
  Future<List<SendRecord>> forPost(String postId);

  /// Records of several posts at once, keyed by post id.
  Future<Map<String, List<SendRecord>>> forPosts(List<String> postIds);

  Future<void> upsert(SendRecord record);

  Future<void> deleteForPost(String postId);
}
