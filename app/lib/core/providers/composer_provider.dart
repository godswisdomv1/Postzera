import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:postzera/core/data/builtin_card_themes.dart';
import 'package:postzera/core/models/app_error.dart';
import 'package:postzera/core/models/media_source.dart';
import 'package:postzera/core/models/platform_profile.dart';
import 'package:postzera/core/models/post.dart';
import 'package:postzera/core/models/variant.dart';
import 'package:postzera/core/ports/clock.dart';
import 'package:postzera/core/ports/file_store_port.dart';
import 'package:postzera/core/ports/media_picker_port.dart';
import 'package:postzera/core/providers/banner_provider.dart';
import 'package:postzera/core/providers/posts_provider.dart';
import 'package:postzera/core/providers/profiles_provider.dart';
import 'package:postzera/core/providers/settings_sync.dart';
import 'package:postzera/core/services/error_classifier.dart';
import 'package:postzera/core/services/hashtag_service.dart';
import 'package:postzera/core/services/variant_builder.dart';
import 'package:postzera/utils/id_generator.dart';
import 'package:postzera/utils/log.dart';

@immutable
class ComposerState {
  const ComposerState({
    this.postId = '',
    this.isNew = true,
    this.hook = '',
    this.body = '',
    this.cta = '',
    this.link = '',
    this.hashtagsText = '',
    this.media = const MediaSource.auto(),
    this.cardThemeId = defaultCardThemeId,
    this.scheduledAt,
    this.status = PostStatus.draft,
    this.createdAt,
    this.hookError,
    this.error,
    this.pickingMedia = false,
    this.variants = const <Variant>[],
  });

  final String postId;

  /// False once the post has been saved at least once.
  final bool isNew;
  final String hook;
  final String body;
  final String cta;
  final String link;

  /// The hashtags as typed, separated by spaces or commas.
  final String hashtagsText;
  final MediaSource media;
  final String cardThemeId;

  /// UTC. Null for a draft.
  final DateTime? scheduledAt;
  final PostStatus status;
  final DateTime? createdAt;

  /// Shown under the hook field.
  final AppError? hookError;

  /// A problem with the photo or video, with its fixed treatment.
  final AppError? error;
  final bool pickingMedia;

  /// The platform variants, built by [ComposerProvider.buildVariants].
  final List<Variant> variants;

  bool get hasContent =>
      hook.trim().isNotEmpty ||
      body.trim().isNotEmpty ||
      cta.trim().isNotEmpty ||
      link.trim().isNotEmpty ||
      hashtagsText.trim().isNotEmpty ||
      !media.isAuto;

  ComposerState copyWith({
    String? postId,
    bool? isNew,
    String? hook,
    String? body,
    String? cta,
    String? link,
    String? hashtagsText,
    MediaSource? media,
    String? cardThemeId,
    DateTime? scheduledAt,
    bool clearScheduledAt = false,
    PostStatus? status,
    DateTime? createdAt,
    AppError? hookError,
    bool clearHookError = false,
    AppError? error,
    bool clearError = false,
    bool? pickingMedia,
    List<Variant>? variants,
  }) =>
      ComposerState(
        postId: postId ?? this.postId,
        isNew: isNew ?? this.isNew,
        hook: hook ?? this.hook,
        body: body ?? this.body,
        cta: cta ?? this.cta,
        link: link ?? this.link,
        hashtagsText: hashtagsText ?? this.hashtagsText,
        media: media ?? this.media,
        cardThemeId: cardThemeId ?? this.cardThemeId,
        scheduledAt: clearScheduledAt ? null : (scheduledAt ?? this.scheduledAt),
        status: status ?? this.status,
        createdAt: createdAt ?? this.createdAt,
        hookError: clearHookError ? null : (hookError ?? this.hookError),
        error: clearError ? null : (error ?? this.error),
        pickingMedia: pickingMedia ?? this.pickingMedia,
        variants: variants ?? this.variants,
      );
}

/// The master post being written. Autosaves a draft after 800 ms without
/// typing, builds the variants, and schedules or sends.
class ComposerProvider extends ValueNotifier<ComposerState> {
  ComposerProvider({
    required PostsProvider posts,
    required ProfilesProvider profiles,
    required SettingsSync settings,
    required MediaPickerPort picker,
    required FileStorePort files,
    required Clock clock,
    required BannerProvider banners,
    this.autosaveDelay = const Duration(milliseconds: 800),
    VariantBuilder builder = const VariantBuilder(),
    HashtagService hashtags = const HashtagService(),
    ErrorClassifier classifier = const ErrorClassifier(),
  })  : _posts = posts,
        _profiles = profiles,
        _settings = settings,
        _picker = picker,
        _files = files,
        _clock = clock,
        _banners = banners,
        _builder = builder,
        _hashtags = hashtags,
        _classifier = classifier,
        super(const ComposerState());

  final PostsProvider _posts;
  final ProfilesProvider _profiles;
  final SettingsSync _settings;
  final MediaPickerPort _picker;
  final FileStorePort _files;
  final Clock _clock;
  final BannerProvider _banners;
  final VariantBuilder _builder;
  final HashtagService _hashtags;
  final ErrorClassifier _classifier;

  /// How long typing must pause before the draft is saved.
  final Duration autosaveDelay;

  Timer? _autosave;

  /// The shortest caption limit among enabled platforms, for the hint.
  int? get strictestCaptionLimit => _profiles.value.strictestCaptionLimit;

  /// The time a new post is suggested for: the daily reminder time today if it
  /// is still ahead, otherwise tomorrow. Local time.
  DateTime suggestedSchedule() {
    final DateTime now = _clock.now().toLocal();
    final int minutes = _settings.current.reminderMinutes;
    final DateTime today =
        DateTime(now.year, now.month, now.day, minutes ~/ 60, minutes % 60);
    return today.isAfter(now)
        ? today
        : DateTime(now.year, now.month, now.day + 1, minutes ~/ 60, minutes % 60);
  }

  /// Starts an empty post.
  void startNew() {
    _autosave?.cancel();
    value = ComposerState(
      postId: newId(),
      cardThemeId: _settings.current.defaultCardThemeId,
    );
  }

  /// Loads a saved post for editing.
  void edit(Post post) {
    _autosave?.cancel();
    value = ComposerState(
      postId: post.id,
      isNew: false,
      hook: post.hook,
      body: post.body,
      cta: post.cta,
      link: post.link,
      hashtagsText: post.hashtags.join(' '),
      media: post.mediaSource,
      cardThemeId: post.cardThemeId,
      scheduledAt: post.scheduledAt,
      status: post.status,
      createdAt: post.createdAt,
    );
  }

  void setHook(String text) =>
      _edited(value.copyWith(hook: text, clearHookError: text.trim().isNotEmpty));
  void setBody(String text) => _edited(value.copyWith(body: text));
  void setCta(String text) => _edited(value.copyWith(cta: text));
  void setLink(String text) => _edited(value.copyWith(link: text));
  void setHashtagsText(String text) =>
      _edited(value.copyWith(hashtagsText: text));
  void setTheme(String id) => _edited(value.copyWith(cardThemeId: id));

  /// Sets or clears the planned time (local or UTC; stored as UTC).
  void setSchedule(DateTime? when) => _edited(
        when == null
            ? value.copyWith(clearScheduledAt: true)
            : value.copyWith(scheduledAt: when.toUtc()),
      );

  Future<void> pickPhoto() => _pick(_picker.pickPhoto, MediaSourceKind.photo);

  Future<void> pickVideo() => _pick(_picker.pickVideo, MediaSourceKind.video);

  /// Goes back to a text card with no photo or video.
  Future<void> useAutoCard() async {
    final String? old = value.media.path;
    _edited(value.copyWith(media: const MediaSource.auto(), clearError: true));
    if (old != null) {
      await _files.delete(old);
    }
  }

  /// Checks the form. The hook is required.
  bool validate() {
    if (value.hook.trim().isEmpty) {
      value = value.copyWith(
        hookError: AppError.of(AppErrorKind.validation, details: 'hook'),
      );
      return false;
    }
    return true;
  }

  /// Builds the variant of every enabled platform. Returns false and shows the
  /// hook error when the hook is empty.
  Future<bool> buildVariants() async {
    if (!validate()) {
      return false;
    }
    try {
      final Post post = _toPost();
      DateTime? modified;
      final String? path = post.mediaSource.path;
      if (path != null) {
        modified = (await _files.stat(path))?.modified;
      }
      final List<Variant> variants = _builder.buildAll(
        post,
        _profiles.value.enabled,
        cardThemeById(post.cardThemeId),
        sourceModified: modified,
      );
      value = value.copyWith(variants: variants);
      return true;
    } catch (error) {
      _banners.failure(_classifier.classify(error, fallback: AppErrorKind.unexpected));
      return false;
    }
  }

  /// Rebuilds one platform's variant with a plain text card instead of the
  /// photo or video, after its render failed. Returns the new variant.
  Variant? variantWithAutoCard(String platformId) {
    final PlatformProfile? profile = _profiles.value.byId(platformId);
    if (profile == null || !validate()) {
      return null;
    }
    final Post plain = _toPost().copyWith(mediaSource: const MediaSource.auto());
    final Variant variant = _builder.build(
      plain,
      profile,
      cardThemeById(plain.cardThemeId),
    );
    value = value.copyWith(
      variants: <Variant>[
        for (final Variant v in value.variants)
          if (v.platformId == platformId) variant else v,
      ],
    );
    return variant;
  }

  /// Saves the post as it is (a draft, or its current status).
  Future<Post?> saveDraft() async {
    _autosave?.cancel();
    if (!value.hasContent) {
      return null;
    }
    final Post post = _toPost();
    await _posts.save(post);
    value = value.copyWith(isNew: false, createdAt: post.createdAt);
    return post;
  }

  /// Schedules the post for its planned time (or the suggested time when none
  /// was chosen). Only reachable after the variants were previewed.
  Future<Post?> schedule() async {
    if (!validate()) {
      return null;
    }
    _autosave?.cancel();
    final DateTime when = (value.scheduledAt ?? suggestedSchedule()).toUtc();
    final Post post = _toPost().copyWith(
      status: PostStatus.scheduled,
      scheduledAt: when,
    );
    await _posts.save(post, announce: BannerMessage.postScheduled);
    value = value.copyWith(
      isNew: false,
      status: PostStatus.scheduled,
      scheduledAt: when,
      createdAt: post.createdAt,
    );
    return post;
  }

  /// Puts the post in today's queue right now, to send straight away.
  Future<Post?> sendNow() async {
    if (!validate()) {
      return null;
    }
    _autosave?.cancel();
    final Post post = _toPost().copyWith(
      status: PostStatus.scheduled,
      scheduledAt: _clock.now().toUtc(),
    );
    await _posts.save(post);
    value = value.copyWith(
      isNew: false,
      status: PostStatus.scheduled,
      scheduledAt: post.scheduledAt,
      createdAt: post.createdAt,
    );
    return post;
  }

  /// Leaves a post that was never saved: its photo or video copy is removed.
  Future<void> discardIfUnsaved() async {
    _autosave?.cancel();
    if (value.isNew) {
      await _files.deletePostFiles(value.postId);
    }
  }

  Post _toPost() {
    final DateTime now = _clock.now().toUtc();
    return Post(
      id: value.postId,
      hook: value.hook.trim(),
      body: value.body.trim(),
      cta: value.cta.trim(),
      link: value.link.trim(),
      hashtags: _hashtags.parse(value.hashtagsText),
      mediaSource: value.media,
      cardThemeId: value.cardThemeId,
      scheduledAt: value.scheduledAt,
      status: value.status,
      createdAt: value.createdAt ?? now,
      updatedAt: now,
    );
  }

  void _edited(ComposerState next) {
    value = next.copyWith(variants: const <Variant>[]);
    _autosave?.cancel();
    if (!value.hasContent) {
      return;
    }
    _autosave = Timer(autosaveDelay, () => unawaited(_autosaveNow()));
  }

  Future<void> _autosaveNow() async {
    try {
      final Post post = _toPost();
      await _posts.save(post);
      value = value.copyWith(isNew: false, createdAt: post.createdAt);
    } catch (error) {
      Log.w('composer', 'autosave failed: ${error.runtimeType}');
    }
  }

  Future<void> _pick(
    Future<PickedMedia?> Function() pick,
    MediaSourceKind kind,
  ) async {
    value = value.copyWith(pickingMedia: true, clearError: true);
    try {
      final PickedMedia? picked = await pick();
      if (picked == null) {
        value = value.copyWith(pickingMedia: false);
        return;
      }
      final String? old = value.media.path;
      final String copy = await _files.copyIntoSources(
        postId: value.postId,
        fromPath: picked.path,
      );
      if (old != null && old != copy) {
        await _files.delete(old);
      }
      _edited(
        value.copyWith(
          pickingMedia: false,
          media: MediaSource(kind: kind, path: copy, durationMs: picked.durationMs),
        ),
      );
    } catch (error) {
      value = value.copyWith(
        pickingMedia: false,
        error: _classifier.classify(error, fallback: AppErrorKind.sourceUnreadable),
      );
    }
  }

  @override
  void dispose() {
    _autosave?.cancel();
    super.dispose();
  }
}
