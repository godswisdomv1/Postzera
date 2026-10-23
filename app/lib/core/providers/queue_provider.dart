import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:postzera/core/data/builtin_card_themes.dart';
import 'package:postzera/core/models/app_error.dart';
import 'package:postzera/core/models/platform_profile.dart';
import 'package:postzera/core/models/post.dart';
import 'package:postzera/core/models/send_record.dart';
import 'package:postzera/core/models/variant.dart';
import 'package:postzera/core/ports/clock.dart';
import 'package:postzera/core/ports/file_store_port.dart';
import 'package:postzera/core/ports/post_repository.dart';
import 'package:postzera/core/ports/send_record_repository.dart';
import 'package:postzera/core/ports/share_port.dart';
import 'package:postzera/core/providers/banner_provider.dart';
import 'package:postzera/core/providers/media_jobs_provider.dart';
import 'package:postzera/core/providers/profiles_provider.dart';
import 'package:postzera/core/providers/undo_provider.dart';
import 'package:postzera/core/services/error_classifier.dart';
import 'package:postzera/core/services/media_pipeline.dart';
import 'package:postzera/core/services/queue_service.dart';
import 'package:postzera/core/services/variant_builder.dart';

/// The send just finished: ask "Mark as posted?".
@immutable
class SendConfirmation {
  const SendConfirmation(this.postId, this.platformId);

  final String postId;
  final String platformId;

  @override
  bool operator ==(Object other) =>
      other is SendConfirmation &&
      other.postId == postId &&
      other.platformId == platformId;

  @override
  int get hashCode => Object.hash(postId, platformId);
}

@immutable
class QueueState {
  const QueueState({
    this.sections = const QueueSections(),
    this.records = const <String, List<SendRecord>>{},
    this.loading = true,
    this.error,
    this.confirmation,
    this.sending = false,
  });

  final QueueSections sections;
  final Map<String, List<SendRecord>> records;
  final bool loading;
  final AppError? error;

  /// Set after the share sheet closes. The screen shows the sheet and calls
  /// [QueueProvider.markPosted] or [QueueProvider.dismissConfirmation].
  final SendConfirmation? confirmation;
  final bool sending;

  QueueState copyWith({
    QueueSections? sections,
    Map<String, List<SendRecord>>? records,
    bool? loading,
    AppError? error,
    bool clearError = false,
    SendConfirmation? confirmation,
    bool clearConfirmation = false,
    bool? sending,
  }) =>
      QueueState(
        sections: sections ?? this.sections,
        records: records ?? this.records,
        loading: loading ?? this.loading,
        error: clearError ? null : (error ?? this.error),
        confirmation:
            clearConfirmation ? null : (confirmation ?? this.confirmation),
        sending: sending ?? this.sending,
      );

  /// The send status of one platform for one post.
  SendStatus statusOf(String postId, String platformId) {
    for (final SendRecord r in records[postId] ?? const <SendRecord>[]) {
      if (r.platformId == platformId) {
        return r.status;
      }
    }
    return SendStatus.pending;
  }
}

/// Today's queue and the send flow: make the media, put the caption on the
/// clipboard, open the share sheet, then ask whether it was posted. The app
/// never marks a post by itself, because the share result cannot say whether
/// the post was completed in the other app.
class QueueProvider extends ValueNotifier<QueueState> {
  QueueProvider({
    required PostRepository posts,
    required SendRecordRepository records,
    required ProfilesProvider profiles,
    required MediaJobsProvider jobs,
    required FileStorePort files,
    required ClipboardPort clipboard,
    required SharePort share,
    required Clock clock,
    required UndoProvider undo,
    required BannerProvider banners,
    this.onChanged,
    VariantBuilder builder = const VariantBuilder(),
    QueueService service = const QueueService(),
    ErrorClassifier classifier = const ErrorClassifier(),
  })  : _posts = posts,
        _records = records,
        _profiles = profiles,
        _jobs = jobs,
        _files = files,
        _clipboard = clipboard,
        _share = share,
        _clock = clock,
        _undo = undo,
        _banners = banners,
        _builder = builder,
        _service = service,
        _classifier = classifier,
        super(const QueueState());

  final PostRepository _posts;
  final SendRecordRepository _records;
  final ProfilesProvider _profiles;
  final MediaJobsProvider _jobs;
  final FileStorePort _files;
  final ClipboardPort _clipboard;
  final SharePort _share;
  final Clock _clock;
  final UndoProvider _undo;
  final BannerProvider _banners;
  final VariantBuilder _builder;
  final QueueService _service;
  final ErrorClassifier _classifier;

  /// Called after a post is marked sent, so reminders can be replanned.
  final VoidCallback? onChanged;

  Future<void> load() async {
    try {
      final List<Post> scheduled =
          await _posts.search(status: PostStatus.scheduled);
      final Map<String, List<SendRecord>> records = await _records.forPosts(
        scheduled.map((Post p) => p.id).toList(),
      );
      value = value.copyWith(
        sections: _service.sections(
          scheduled,
          records,
          _clock,
          platformCount: _profiles.value.enabled.length,
        ),
        records: records,
        loading: false,
        clearError: true,
      );
    } catch (error) {
      value = value.copyWith(
        loading: false,
        error: _classifier.classify(error, fallback: AppErrorKind.dbUnavailable),
      );
    }
  }

  /// The finished caption, title and media plan of one platform for a post.
  Future<Variant?> variantFor(String postId, String platformId) async {
    final Post? post = await _posts.byId(postId);
    final PlatformProfile? profile = _profiles.value.byId(platformId);
    if (post == null || profile == null) {
      return null;
    }
    DateTime? modified;
    final String? path = post.mediaSource.path;
    if (path != null) {
      modified = (await _files.stat(path))?.modified;
    }
    return _builder.build(
      post,
      profile,
      cardThemeById(post.cardThemeId),
      sourceModified: modified,
    );
  }

  /// Makes sure the media exists, copies the caption, and opens the share
  /// sheet. Returns what the share sheet reported, or null if it failed.
  Future<ShareOutcome?> send(
    String postId,
    String platformId, {
    ShareOrigin? origin,
  }) async {
    value = value.copyWith(sending: true, clearError: true);
    try {
      final Variant? variant = await variantFor(postId, platformId);
      if (variant == null) {
        throw AppError.of(AppErrorKind.unexpected, details: 'post or platform missing');
      }
      final MediaResult media = await _jobs.produce(postId, variant);
      await _clipboard.copy(variant.caption);
      final ShareOutcome outcome = await _share.share(
        filePath: media.path,
        text: variant.caption,
        origin: origin,
      );
      value = value.copyWith(
        sending: false,
        confirmation: outcome == ShareOutcome.unavailable
            ? null
            : SendConfirmation(postId, platformId),
        error: outcome == ShareOutcome.unavailable
            ? AppError.of(AppErrorKind.shareUnavailable)
            : null,
      );
      return outcome;
    } on MediaCancelled {
      value = value.copyWith(sending: false);
      return null;
    } catch (error) {
      value = value.copyWith(
        sending: false,
        error: _classifier.classify(error, fallback: AppErrorKind.shareFailed),
      );
      return null;
    }
  }

  /// Puts the platform's title on the clipboard.
  Future<void> copyTitle(String postId, String platformId) async {
    try {
      final Variant? variant = await variantFor(postId, platformId);
      final String? title = variant?.title;
      if (title == null || title.isEmpty) {
        return;
      }
      await _clipboard.copy(title);
      _banners.success(BannerMessage.titleCopied);
    } catch (error) {
      _banners.failure(_classifier.classify(error, fallback: AppErrorKind.unexpected));
    }
  }

  /// Puts the caption on the clipboard.
  Future<void> copyCaption(String postId, String platformId) async {
    try {
      final Variant? variant = await variantFor(postId, platformId);
      if (variant == null) {
        return;
      }
      await _clipboard.copy(variant.caption);
      _banners.success(BannerMessage.captionCopied);
    } catch (error) {
      _banners.failure(_classifier.classify(error, fallback: AppErrorKind.unexpected));
    }
  }

  Future<void> markPosted(String postId, String platformId) =>
      _record(postId, platformId, SendStatus.done, BannerMessage.markedPosted, UndoLabel.markedPosted);

  Future<void> skip(String postId, String platformId) =>
      _record(postId, platformId, SendStatus.skipped, BannerMessage.skipped, UndoLabel.skipped);

  void dismissConfirmation() =>
      value = value.copyWith(clearConfirmation: true);

  void clearError() => value = value.copyWith(clearError: true);

  Future<void> _record(
    String postId,
    String platformId,
    SendStatus status,
    BannerMessage message,
    UndoLabel label,
  ) async {
    try {
      final Post? post = await _posts.byId(postId);
      if (post == null) {
        return;
      }
      final List<SendRecord> before = await _records.forPost(postId);
      final SendRecord? previous = before
          .where((SendRecord r) => r.platformId == platformId)
          .firstOrNull;
      await _records.upsert(
        SendRecord(
          postId: postId,
          platformId: platformId,
          status: status,
          doneAt: status == SendStatus.done ? _clock.now().toUtc() : null,
        ),
      );
      final PostStatus statusBefore = post.status;
      await _finishPostIfComplete(post);
      value = value.copyWith(clearConfirmation: true);
      await load();
      onChanged?.call();
      await _undo.register(
        UndoAction(
          label: label,
          revert: () async {
            await _records.upsert(
              previous ??
                  SendRecord(
                    postId: postId,
                    platformId: platformId,
                    status: SendStatus.pending,
                  ),
            );
            final Post? current = await _posts.byId(postId);
            if (current != null && current.status != statusBefore) {
              await _posts.upsert(
                current.copyWith(
                  status: statusBefore,
                  updatedAt: _clock.now().toUtc(),
                ),
              );
            }
            await load();
            onChanged?.call();
          },
        ),
      );
    } catch (error) {
      _banners.failure(_classifier.classify(error, fallback: AppErrorKind.dbUnavailable));
    }
  }

  /// When every enabled platform is done or skipped, the post becomes sent and
  /// leaves the queue.
  Future<void> _finishPostIfComplete(Post post) async {
    final List<String> enabled =
        _profiles.value.enabled.map((PlatformProfile p) => p.id).toList();
    if (enabled.isEmpty) {
      return;
    }
    final List<SendRecord> records = await _records.forPost(post.id);
    final bool all = enabled.every(
      (String id) => records.any(
        (SendRecord r) =>
            r.platformId == id &&
            (r.status == SendStatus.done || r.status == SendStatus.skipped),
      ),
    );
    if (all && post.status != PostStatus.sent) {
      await _posts.upsert(
        post.copyWith(status: PostStatus.sent, updatedAt: _clock.now().toUtc()),
      );
    }
  }
}
