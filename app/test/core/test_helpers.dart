import 'package:postzera/core/data/default_profiles.dart';
import 'package:postzera/core/models/media_source.dart';
import 'package:postzera/core/models/platform_profile.dart';
import 'package:postzera/core/models/post.dart';
import 'package:postzera/core/ports/clock.dart';

/// A draft post for tests.
Post testPost({
  String hook = 'Hook',
  String body = '',
  String cta = '',
  String link = '',
  List<String> tags = const <String>[],
  MediaSource? media,
  String theme = 'paper',
}) =>
    Post(
      id: 'p1',
      hook: hook,
      body: body,
      cta: cta,
      link: link,
      hashtags: tags,
      mediaSource: media ?? const MediaSource.auto(),
      cardThemeId: theme,
      status: PostStatus.draft,
      createdAt: DateTime.utc(2026, 10, 18),
      updatedAt: DateTime.utc(2026, 10, 18),
    );

/// One of the nine default profiles by id.
PlatformProfile profileById(String id) =>
    defaultProfiles().firstWhere((PlatformProfile p) => p.id == id);

/// `n` copies of "word" separated by spaces (5n - 1 characters).
String words(int n) => List<String>.filled(n, 'word').join(' ');

/// A clock that always says the same time.
class FixedClock implements Clock {
  const FixedClock(this.value);

  final DateTime value;

  @override
  DateTime now() => value;
}
