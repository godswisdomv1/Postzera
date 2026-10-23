import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:postzera/core/models/app_error.dart';
import 'package:postzera/core/models/variant.dart';
import 'package:postzera/core/services/error_classifier.dart';
import 'package:postzera/core/services/media_pipeline.dart';

enum MediaJobStatus { idle, queued, rendering, ready, failed }

/// The state of the media file for one post on one platform.
@immutable
class MediaJob {
  const MediaJob({
    required this.cacheKey,
    this.status = MediaJobStatus.queued,
    this.progress = 0,
    this.result,
    this.error,
  });

  /// Which variant this job renders. A changed variant starts a new job.
  final String cacheKey;
  final MediaJobStatus status;

  /// 0 to 1 while rendering.
  final double progress;
  final MediaResult? result;
  final AppError? error;

  MediaJob copyWith({
    MediaJobStatus? status,
    double? progress,
    MediaResult? result,
    AppError? error,
  }) =>
      MediaJob(
        cacheKey: cacheKey,
        status: status ?? this.status,
        progress: progress ?? this.progress,
        result: result ?? this.result,
        error: error ?? this.error,
      );
}

@immutable
class MediaJobsState {
  const MediaJobsState({this.jobs = const <String, MediaJob>{}});

  /// Jobs keyed by [MediaJobsProvider.keyFor].
  final Map<String, MediaJob> jobs;
}

class _Entry {
  _Entry(this.postId, this.variant);

  final String postId;
  final Variant variant;
  final Completer<MediaResult> completer = Completer<MediaResult>();
  bool cancelled = false;
}

/// Renders media one file at a time, so the cheapest phone is never
/// overloaded. Each job reports idle, queued, rendering with progress, ready
/// with its file, or failed with an error.
class MediaJobsProvider extends ValueNotifier<MediaJobsState> {
  MediaJobsProvider({
    required MediaPipeline pipeline,
    ErrorClassifier classifier = const ErrorClassifier(),
  })  : _pipeline = pipeline,
        _classifier = classifier,
        super(const MediaJobsState());

  final MediaPipeline _pipeline;
  final ErrorClassifier _classifier;

  final List<_Entry> _queue = <_Entry>[];
  final Map<String, _Entry> _byKey = <String, _Entry>{};
  _Entry? _current;
  bool _pumping = false;

  static String keyFor(String postId, String platformId) =>
      '$postId/$platformId';

  MediaJob? jobFor(String postId, String platformId) =>
      value.jobs[keyFor(postId, platformId)];

  /// Renders [variant] and returns its file. A variant already rendering or
  /// ready is not rendered again. Throws the `AppError` if it fails, or
  /// [MediaCancelled] if it was cancelled.
  Future<MediaResult> produce(String postId, Variant variant) {
    final String key = keyFor(postId, variant.platformId);
    final MediaJob? existing = value.jobs[key];
    if (existing != null && existing.cacheKey == variant.mediaPlan.cacheKey) {
      if (existing.status == MediaJobStatus.ready && existing.result != null) {
        return Future<MediaResult>.value(existing.result);
      }
      final _Entry? running = _byKey[key];
      if (running != null &&
          (existing.status == MediaJobStatus.queued ||
              existing.status == MediaJobStatus.rendering)) {
        return running.completer.future;
      }
    }
    // A different variant of the same platform replaces the old job.
    final _Entry? stale = _byKey[key];
    if (stale != null) {
      unawaited(_cancelEntry(stale));
    }
    final _Entry entry = _Entry(postId, variant);
    _byKey[key] = entry;
    _queue.add(entry);
    _set(key, MediaJob(cacheKey: variant.mediaPlan.cacheKey));
    unawaited(_pump());
    return entry.completer.future;
  }

  /// Starts rendering for every variant without waiting. Failures show up in
  /// the job states.
  void requestAll(String postId, List<Variant> variants) {
    for (final Variant v in variants) {
      unawaited(
        produce(postId, v).then<void>((MediaResult _) {}, onError: (Object _) {}),
      );
    }
  }

  /// Tries a failed job again.
  void retry(String postId, Variant variant) {
    final String key = keyFor(postId, variant.platformId);
    final MediaJob? job = value.jobs[key];
    if (job != null && job.status == MediaJobStatus.failed) {
      _remove(key);
    }
    requestAll(postId, <Variant>[variant]);
  }

  Future<void> cancel(String postId, String platformId) async {
    final _Entry? entry = _byKey[keyFor(postId, platformId)];
    if (entry != null) {
      await _cancelEntry(entry);
    }
  }

  Future<void> cancelAll() async {
    for (final _Entry entry in List<_Entry>.of(_byKey.values)) {
      await _cancelEntry(entry);
    }
  }

  Future<void> _cancelEntry(_Entry entry) async {
    final String key = keyFor(entry.postId, entry.variant.platformId);
    entry.cancelled = true;
    if (identical(_current, entry)) {
      await _pipeline.cancel();
      return;
    }
    if (_queue.remove(entry)) {
      if (identical(_byKey[key], entry)) {
        _byKey.remove(key);
        _remove(key);
      }
      if (!entry.completer.isCompleted) {
        entry.completer.completeError(const MediaCancelled());
      }
    }
  }

  Future<void> _pump() async {
    if (_pumping) {
      return;
    }
    _pumping = true;
    try {
      while (_queue.isNotEmpty) {
        final _Entry entry = _queue.removeAt(0);
        _current = entry;
        await _run(entry);
        _current = null;
      }
    } finally {
      _pumping = false;
    }
  }

  Future<void> _run(_Entry entry) async {
    final String key = keyFor(entry.postId, entry.variant.platformId);
    _set(key, MediaJob(
      cacheKey: entry.variant.mediaPlan.cacheKey,
      status: MediaJobStatus.rendering,
    ));
    try {
      final MediaResult result = await _pipeline.produce(
        entry.variant,
        postId: entry.postId,
        onProgress: (double p) {
          final MediaJob? job = value.jobs[key];
          if (job != null &&
              job.status == MediaJobStatus.rendering &&
              identical(_byKey[key], entry)) {
            _set(key, job.copyWith(progress: p));
          }
        },
      );
      if (identical(_byKey[key], entry)) {
        _set(key, MediaJob(
          cacheKey: entry.variant.mediaPlan.cacheKey,
          status: MediaJobStatus.ready,
          progress: 1,
          result: result,
        ));
      }
      entry.completer.complete(result);
    } on MediaCancelled {
      if (identical(_byKey[key], entry)) {
        _byKey.remove(key);
        _remove(key);
      }
      entry.completer.completeError(const MediaCancelled());
    } catch (error) {
      final AppError app =
          _classifier.classify(error, fallback: AppErrorKind.renderFailed);
      if (identical(_byKey[key], entry)) {
        _set(key, MediaJob(
          cacheKey: entry.variant.mediaPlan.cacheKey,
          status: MediaJobStatus.failed,
          error: app,
        ));
      }
      entry.completer.completeError(app);
    }
  }

  void _set(String key, MediaJob job) {
    value = MediaJobsState(jobs: <String, MediaJob>{...value.jobs, key: job});
  }

  void _remove(String key) {
    final Map<String, MediaJob> next = <String, MediaJob>{...value.jobs}
      ..remove(key);
    value = MediaJobsState(jobs: next);
  }
}
