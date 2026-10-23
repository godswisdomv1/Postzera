import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:postzera/core/models/app_error.dart';
import 'package:postzera/core/models/media_source.dart';
import 'package:postzera/core/models/post.dart';
import 'package:postzera/core/models/send_record.dart';
import 'package:postzera/core/ports/clock.dart';
import 'package:postzera/core/ports/file_store_port.dart';
import 'package:postzera/core/ports/post_repository.dart';
import 'package:postzera/core/ports/send_record_repository.dart';
import 'package:postzera/core/ports/share_port.dart';
import 'package:postzera/core/providers/banner_provider.dart';
import 'package:postzera/core/providers/undo_provider.dart';
import 'package:postzera/core/services/csv_exporter.dart';
import 'package:postzera/core/services/error_classifier.dart';
import 'package:postzera/utils/id_generator.dart';
import 'package:postzera/utils/log.dart';

@immutable
class PostsState {
  const PostsState({
    this.posts = const <Post>[],
    this.loading = true,
    this.error,
    this.query = '',
    this.status,
    this.sort = PostSort.newest,
  });

  final List<Post> posts;
  final bool loading;
  final AppError? error;
  final String query;
  final PostStatus? status;
  final PostSort sort;

  PostsState copyWith({
    List<Post>? posts,
    bool? loading,
    AppError? error,
    bool clearError = false,
    String? query,
    PostStatus? status,
    bool clearStatus = false,
    PostSort? sort,
  }) =>
      PostsState(
        posts: posts ?? this.posts,
        loading: loading ?? this.loading,
        error: clearError ? null : (error ?? this.error),
        query: query ?? this.query,
        status: clearStatus ? null : (status ?? this.status),
        sort: sort ?? this.sort,
      );
}

/// The library: every post, with search, filter and sort, plus save,
/// duplicate, delete (with undo) and CSV export.
class PostsProvider extends ValueNotifier<PostsState> {
  PostsProvider({
    required PostRepository posts,
    required SendRecordRepository records,
    required FileStorePort files,
    required SharePort share,
    required Clock clock,
    required UndoProvider undo,
    required BannerProvider banners,
    this.onChanged,
    ErrorClassifier classifier = const ErrorClassifier(),
  })  : _posts = posts,
        _records = records,
        _files = files,
        _share = share,
        _clock = clock,
        _undo = undo,
        _banners = banners,
        _classifier = classifier,
        super(const PostsState());

  final PostRepository _posts;
  final SendRecordRepository _records;
  final FileStorePort _files;
  final SharePort _share;
  final Clock _clock;
  final UndoProvider _undo;
  final BannerProvider _banners;
  final ErrorClassifier _classifier;

  /// Called after posts change, so reminders can be replanned.
  final VoidCallback? onChanged;

  int _reloadSequence = 0;

  Future<void> load() => _reload();

  Future<void> setQuery(String query) {
    value = value.copyWith(query: query);
    return _reload();
  }

  Future<void> setStatus(PostStatus? status) {
    value = status == null
        ? value.copyWith(clearStatus: true)
        : value.copyWith(status: status);
    return _reload();
  }

  Future<void> setSort(PostSort sort) {
    value = value.copyWith(sort: sort);
    return _reload();
  }

  /// Saves a post, stamping the update time.
  Future<void> save(Post post, {BannerMessage? announce}) async {
    try {
      await _posts.upsert(post.copyWith(updatedAt: _clock.now().toUtc()));
      await _reload();
      onChanged?.call();
      if (announce != null) {
        _banners.success(announce);
      }
    } catch (error) {
      _banners.failure(_classifier.classify(error, fallback: AppErrorKind.dbUnavailable));
    }
  }

  /// Makes a draft copy, including its photo or video.
  Future<void> duplicate(String id) async {
    try {
      final Post? source = await _posts.byId(id);
      if (source == null) {
        return;
      }
      final String copyId = newId();
      MediaSource media = source.mediaSource;
      final String? path = media.path;
      if (path != null) {
        try {
          media = media.copyWith(
            path: await _files.copyIntoSources(postId: copyId, fromPath: path),
          );
        } catch (error) {
          Log.w('posts', 'media copy failed: ${error.runtimeType}');
          media = const MediaSource.auto();
        }
      }
      final DateTime now = _clock.now().toUtc();
      await _posts.upsert(
        source.copyWith(
          id: copyId,
          status: PostStatus.draft,
          clearScheduledAt: true,
          mediaSource: media,
          createdAt: now,
          updatedAt: now,
        ),
      );
      await _reload();
      _banners.success(BannerMessage.postDuplicated);
    } catch (error) {
      _banners.failure(_classifier.classify(error, fallback: AppErrorKind.dbUnavailable));
    }
  }

  /// Deletes a post. For five seconds it can be undone; after that its media
  /// files are removed too.
  Future<void> delete(String id) async {
    try {
      final Post? post = await _posts.byId(id);
      if (post == null) {
        return;
      }
      final List<SendRecord> records = await _records.forPost(id);
      await _records.deleteForPost(id);
      await _posts.delete(id);
      await _reload();
      onChanged?.call();
      await _undo.register(
        UndoAction(
          label: UndoLabel.postDeleted,
          revert: () async {
            await _posts.upsert(post);
            for (final SendRecord r in records) {
              await _records.upsert(r);
            }
            await _reload();
            onChanged?.call();
          },
          onExpire: () => _files.deletePostFiles(id),
        ),
      );
    } catch (error) {
      _banners.failure(_classifier.classify(error, fallback: AppErrorKind.dbUnavailable));
    }
  }

  /// Writes every post to a CSV file and opens the share sheet for it.
  Future<ShareOutcome?> exportCsv() async {
    try {
      final List<Post> all = await _posts.all();
      final String path = await _files.writeExportFile(
        name: 'postzera-posts.csv',
        content: const CsvExporter().encode(all),
      );
      final ShareOutcome outcome = await _share.share(filePath: path, text: '');
      if (outcome != ShareOutcome.unavailable) {
        _banners.success(BannerMessage.exported);
      }
      return outcome;
    } catch (error) {
      _banners.failure(_classifier.classify(error, fallback: AppErrorKind.shareFailed));
      return null;
    }
  }

  Future<void> _reload() async {
    final int ticket = ++_reloadSequence;
    final PostsState snapshot = value;
    try {
      final List<Post> found = await _posts.search(
        query: snapshot.query,
        status: snapshot.status,
        sort: snapshot.sort,
      );
      if (ticket != _reloadSequence) {
        return;
      }
      value = value.copyWith(posts: found, loading: false, clearError: true);
    } catch (error) {
      if (ticket != _reloadSequence) {
        return;
      }
      value = value.copyWith(
        loading: false,
        error: _classifier.classify(error, fallback: AppErrorKind.dbUnavailable),
      );
    }
  }
}
