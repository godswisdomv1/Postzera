import 'package:characters/characters.dart';
import 'package:flutter/foundation.dart';
import 'package:postzera/core/models/app_error.dart';
import 'package:postzera/core/models/media_spec.dart';
import 'package:postzera/core/models/platform_profile.dart';
import 'package:postzera/core/models/platform_template.dart';
import 'package:postzera/core/ports/profile_repository.dart';
import 'package:postzera/core/providers/banner_provider.dart';
import 'package:postzera/core/services/error_classifier.dart';
import 'package:postzera/utils/id_generator.dart';

@immutable
class ProfilesState {
  const ProfilesState({
    this.profiles = const <PlatformProfile>[],
    this.loading = true,
    this.error,
  });

  /// Every profile in display order, enabled or not.
  final List<PlatformProfile> profiles;
  final bool loading;
  final AppError? error;

  List<PlatformProfile> get enabled =>
      profiles.where((PlatformProfile p) => p.enabled).toList();

  /// The shortest caption limit among enabled platforms, or null when none is
  /// enabled. Shown as a hint in the composer.
  int? get strictestCaptionLimit {
    final List<PlatformProfile> on = enabled;
    if (on.isEmpty) {
      return null;
    }
    return on
        .map((PlatformProfile p) => p.captionLimit)
        .reduce((int a, int b) => a < b ? a : b);
  }

  PlatformProfile? byId(String id) {
    for (final PlatformProfile p in profiles) {
      if (p.id == id) {
        return p;
      }
    }
    return null;
  }
}

/// The platforms: which are on, their order, their templates, and custom ones.
class ProfilesProvider extends ValueNotifier<ProfilesState> {
  ProfilesProvider({
    required ProfileRepository profiles,
    required BannerProvider banners,
    ErrorClassifier classifier = const ErrorClassifier(),
  })  : _profiles = profiles,
        _banners = banners,
        _classifier = classifier,
        super(const ProfilesState());

  final ProfileRepository _profiles;
  final BannerProvider _banners;
  final ErrorClassifier _classifier;

  /// Fills the built-in profiles on first run, then loads them.
  Future<void> load() async {
    try {
      await _profiles.ensureDefaults();
      await _reload();
    } catch (error) {
      value = ProfilesState(
        profiles: value.profiles,
        loading: false,
        error: _classifier.classify(error, fallback: AppErrorKind.dbUnavailable),
      );
    }
  }

  Future<void> setEnabled(String id, {required bool enabled}) async {
    final PlatformProfile? p = value.byId(id);
    if (p == null) {
      return;
    }
    await _run(() => _profiles.upsert(p.copyWith(enabled: enabled)));
  }

  /// Moves a platform up (negative [delta]) or down in the order.
  Future<void> move(String id, int delta) async {
    final List<String> ids =
        value.profiles.map((PlatformProfile p) => p.id).toList();
    final int from = ids.indexOf(id);
    final int to = from + delta;
    if (from < 0 || to < 0 || to >= ids.length) {
      return;
    }
    ids.insert(to, ids.removeAt(from));
    await _run(() => _profiles.reorder(ids));
  }

  /// Saves an edited profile (the template editor).
  Future<void> save(PlatformProfile profile) =>
      _run(() => _profiles.upsert(profile));

  Future<void> resetToDefault(String id) =>
      _run(() => _profiles.resetToDefault(id));

  Future<void> deleteCustom(String id) => _run(() => _profiles.delete(id));

  /// Adds a custom platform with the default blocks. Returns a `validation`
  /// error when the input is not usable, or null on success.
  Future<AppError?> addCustom({
    required String name,
    required String monogram,
    required int captionLimit,
    required MediaAspect aspect,
    required int maxHashtags,
  }) async {
    final String cleanName = name.trim();
    final String cleanMonogram = monogram.trim();
    if (cleanName.isEmpty ||
        cleanMonogram.isEmpty ||
        cleanMonogram.characters.length > 2 ||
        captionLimit <= 0 ||
        maxHashtags < 0) {
      return AppError.of(AppErrorKind.validation, details: 'custom platform');
    }
    final int order = value.profiles.isEmpty
        ? 0
        : value.profiles
                .map((PlatformProfile p) => p.sortOrder)
                .reduce((int a, int b) => a > b ? a : b) +
            1;
    final PlatformProfile profile = PlatformProfile(
      id: 'custom-${newId()}',
      name: cleanName,
      monogram: cleanMonogram,
      isCustom: true,
      sortOrder: order,
      captionLimit: captionLimit,
      maxHashtags: maxHashtags,
      template: const PlatformTemplate(
        blocks: <TemplateBlock>[
          TemplateBlock(slot: TemplateSlot.hook, required: true),
          TemplateBlock(slot: TemplateSlot.body),
          TemplateBlock(slot: TemplateSlot.cta),
          TemplateBlock(slot: TemplateSlot.link),
          TemplateBlock(slot: TemplateSlot.hashtags),
        ],
        mediaTextSlots: <TemplateSlot>[TemplateSlot.hook, TemplateSlot.body],
        mediaBodyMaxChars: 220,
      ),
      media: MediaSpec.forAspect(aspect),
    );
    await _run(() => _profiles.upsert(profile));
    return null;
  }

  Future<void> _run(Future<void> Function() change) async {
    try {
      await change();
      await _reload();
    } catch (error) {
      _banners.failure(
        _classifier.classify(error, fallback: AppErrorKind.dbUnavailable),
      );
    }
  }

  Future<void> _reload() async {
    final List<PlatformProfile> all = await _profiles.all();
    value = ProfilesState(profiles: all, loading: false);
  }
}
